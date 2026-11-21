import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { corsHeaders } from '../_shared/cors.ts'
import { createAdminClient } from '../_shared/supabase_client.ts'
import { getAuthenticatedUser, getUserProfile, requireRole } from '../_shared/auth.ts'

// ---------------------------------------------------------------------------
// UUID v4 validation regex
// ---------------------------------------------------------------------------
const UUID_REGEX =
  /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i

function isValidUUID(value: unknown): value is string {
  return typeof value === 'string' && UUID_REGEX.test(value)
}

// ---------------------------------------------------------------------------
// Generate a UUID v4 using the Web Crypto API (available in Deno)
// ---------------------------------------------------------------------------
function generateUUIDv4(): string {
  return crypto.randomUUID()
}

// ---------------------------------------------------------------------------
// Helper: return a 400 JSON response without touching the database
// ---------------------------------------------------------------------------
function badRequest(message: string): Response {
  return new Response(JSON.stringify({ error: message }), {
    status: 400,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })
}

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

  try {
    const supabase = createAdminClient()
    const user = await getAuthenticatedUser(req, supabase)
    const profile = await getUserProfile(supabase, user.id)
    requireRole(profile, ['customer'])

    // 1. Get cart with items + product + vendor details
    const { data: cart } = await supabase
      .from('carts')
      .select(`id, cart_items(id, quantity, unit_price, product_id, vendor_id,
                products(id, name, status, stock_quantity, track_inventory, price, vendor_id),
                vendors(id, commission_rate, status))`)
      .eq('customer_id', user.id)
      .single()

    if (!cart || !cart.cart_items?.length) {
      return badRequest('Cart is empty')
    }

    // 2. Parse body
    let shippingAddressId: string | null = null
    let notes: string | null = null
    // Client-supplied idempotency key (UUID v4). If absent or invalid, the
    // server generates one so every request is idempotency-safe.
    let clientIdempotencyKey: string | null = null

    try {
      const body = await req.json()
      shippingAddressId = body?.shipping_address_id ?? null
      notes = body?.notes ?? null
      const rawKey = body?.idempotency_key ?? null
      // Accept client key only if it is a valid UUID v4
      if (isValidUUID(rawKey)) {
        clientIdempotencyKey = rawKey
      }
    } catch {
      // body is optional — all fields stay null
    }

    // Resolve final idempotency key: prefer client-supplied; fall back to
    // a server-generated UUID.  Using a server-generated key when the client
    // doesn't send one means a single fresh request won't replay, but a client
    // that retries the SAME request with the SAME key will get the original result.
    const idempotencyKey: string = clientIdempotencyKey ?? generateUUIDv4()

    // -------------------------------------------------------------------------
    // FINDING 1 FIX: Validate shipping_address_id ownership before ANY DB write
    // -------------------------------------------------------------------------
    if (shippingAddressId !== null) {
      // 2a. Reject non-UUID values immediately (no DB round-trip required)
      if (!isValidUUID(shippingAddressId)) {
        return badRequest('Invalid shipping address ID format.')
      }

      // 2b. Confirm address exists AND belongs to the authenticated customer.
      //     Using the admin client but filtering on profile_id enforces ownership
      //     independently of RLS (service role bypasses RLS, so we filter explicitly).
      const { data: ownedAddress, error: addrErr } = await supabase
        .from('addresses')
        .select('id')
        .eq('id', shippingAddressId)
        .eq('profile_id', user.id)
        .maybeSingle()

      if (addrErr) {
        console.error('Address lookup error:', addrErr)
        return new Response(
          JSON.stringify({ error: 'Internal server error while validating address.' }),
          { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }

      // Address doesn't exist OR belongs to a different customer — reject either way.
      // We intentionally do NOT distinguish "not found" from "belongs to someone else"
      // to avoid leaking information about other customers' address UUIDs.
      if (!ownedAddress) {
        return badRequest('Shipping address not found or does not belong to your account.')
      }
    }
    // -------------------------------------------------------------------------

    // 3. Validate all items (product active, vendor active, stock sufficient)
    for (const item of cart.cart_items) {
      if (item.products.status !== 'active') {
        return badRequest(`Product "${item.products.name}" is no longer available`)
      }
      if (item.vendors.status !== 'active') {
        return badRequest('Vendor is no longer active')
      }
      if (item.products.track_inventory && item.products.stock_quantity < item.quantity) {
        return badRequest(`Insufficient stock for "${item.products.name}"`)
      }
    }

    // 4. Build the payload required by the atomic RPC (Finding 2 fix)
    //    Pass cart items as a JSON array; the RPC owns all DB writes inside a transaction.
    const cartItemsPayload = cart.cart_items.map((item: any) => ({
      product_id: item.product_id,
      vendor_id: item.vendor_id,
      product_name: item.products.name,
      quantity: item.quantity,
      // Server-authoritative price: use the live product price, NOT the client-submitted price
      unit_price: parseFloat(item.products.price),
      commission_rate: parseFloat(item.vendors.commission_rate),
      track_inventory: item.products.track_inventory,
    }))

    // 5. Call the atomic checkout RPC — all order creation, stock decrement, cart
    //    clearing, and idempotency-key recording happen inside a single PostgreSQL
    //    transaction.  The 6-argument overload (migration 9) is used so that the
    //    idempotency key is passed to the database.
    const { data: rpcResult, error: rpcErr } = await supabase.rpc(
      'create_checkout_order',
      {
        p_customer_id: user.id,
        p_cart_id: cart.id,
        p_shipping_address_id: shippingAddressId,
        p_notes: notes,
        p_items: cartItemsPayload,
        p_idempotency_key: idempotencyKey,
      }
    )

    if (rpcErr) {
      console.error('create_checkout_order RPC error:', rpcErr)
      // Surface user-friendly messages from RAISE EXCEPTION in the RPC
      const msg: string = rpcErr.message ?? ''
      if (
        msg.includes('Insufficient stock') ||
        msg.includes('no longer available') ||
        msg.includes('no longer active')
      ) {
        return badRequest(msg)
      }
      return new Response(
        JSON.stringify({ error: 'Internal server error' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // rpcResult is the JSON object returned by the function
    return new Response(
      JSON.stringify({
        success: true,
        customer_order_id: rpcResult.customer_order_id,
        vendor_order_ids: rpcResult.vendor_order_ids,
        total: rpcResult.total,
        // Expose the key so the Flutter client can store it for retries
        idempotency_key: idempotencyKey,
        // Present only on a replay — Flutter can use this to surface a friendly message
        ...(rpcResult.idempotent_replay ? { idempotent_replay: true } : {}),
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (err) {
    if (err instanceof Response) return err
    console.error('initiate-checkout error:', err)
    return new Response(
      JSON.stringify({ error: 'Internal server error' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
