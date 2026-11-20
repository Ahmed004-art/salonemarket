import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { corsHeaders } from '../_shared/cors.ts'
import { createAdminClient } from '../_shared/supabase_client.ts'
import { getAuthenticatedUser, getUserProfile, requireRole } from '../_shared/auth.ts'

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
      return new Response(JSON.stringify({ error: 'Cart is empty' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    // 2. Parse body for optional fields
    let shippingAddressId: string | null = null
    let notes: string | null = null
    try {
      const body = await req.json()
      shippingAddressId = body?.shipping_address_id ?? null
      notes = body?.notes ?? null
    } catch {
      // body is optional
    }

    // 3. Validate all items
    for (const item of cart.cart_items) {
      if (item.products.status !== 'active') {
        return new Response(
          JSON.stringify({ error: `Product "${item.products.name}" is no longer available` }),
          { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }
      if (item.vendors.status !== 'active') {
        return new Response(
          JSON.stringify({ error: 'Vendor is no longer active' }),
          { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }
      if (item.products.track_inventory && item.products.stock_quantity < item.quantity) {
        return new Response(
          JSON.stringify({ error: `Insufficient stock for "${item.products.name}"` }),
          { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }
    }

    // 4. Group items by vendor
    const vendorGroups: Record<string, { vendorId: string; commissionRate: number; items: any[] }> = {}
    for (const item of cart.cart_items) {
      if (!vendorGroups[item.vendor_id]) {
        vendorGroups[item.vendor_id] = {
          vendorId: item.vendor_id,
          commissionRate: parseFloat(item.vendors.commission_rate),
          items: [],
        }
      }
      vendorGroups[item.vendor_id].items.push(item)
    }

    // 5. Calculate totals
    let orderSubtotal = 0
    const vendorTotals: Array<{
      vendorId: string
      subtotal: number
      commission: number
      payout: number
      items: any[]
    }> = []

    for (const [vendorId, group] of Object.entries(vendorGroups)) {
      const subtotal = group.items.reduce(
        (sum, i) => sum + parseFloat(i.unit_price) * i.quantity,
        0
      )
      const commission = Math.round(subtotal * group.commissionRate * 100) / 100
      const payout = Math.round((subtotal - commission) * 100) / 100
      orderSubtotal += subtotal
      vendorTotals.push({
        vendorId,
        subtotal: Math.round(subtotal * 100) / 100,
        commission,
        payout,
        items: group.items,
      })
    }

    const deliveryFee = 0
    const platformFee = 0
    const orderTotal = Math.round((orderSubtotal + deliveryFee + platformFee) * 100) / 100

    // 6. Create customer_order
    const { data: customerOrder, error: orderErr } = await supabase
      .from('customer_orders')
      .insert({
        customer_id: user.id,
        status: 'pending_payment',
        subtotal: Math.round(orderSubtotal * 100) / 100,
        delivery_fee: deliveryFee,
        platform_fee: platformFee,
        total: orderTotal,
        payment_method: 'simulated',
        payment_status: 'pending',
        shipping_address_id: shippingAddressId,
        notes,
      })
      .select()
      .single()

    if (orderErr) throw orderErr

    // 7. Create vendor_orders and order_items
    const vendorOrderIds: string[] = []
    for (const vt of vendorTotals) {
      const { data: vendorOrder, error: voErr } = await supabase
        .from('vendor_orders')
        .insert({
          customer_order_id: customerOrder.id,
          vendor_id: vt.vendorId,
          customer_id: user.id,
          status: 'awaiting_payment',
          subtotal: vt.subtotal,
          delivery_fee: 0,
          commission_amount: vt.commission,
          vendor_payout: vt.payout,
        })
        .select()
        .single()
      if (voErr) throw voErr
      vendorOrderIds.push(vendorOrder.id)

      const itemsToInsert = vt.items.map((item) => ({
        vendor_order_id: vendorOrder.id,
        customer_order_id: customerOrder.id,
        product_id: item.product_id,
        vendor_id: vt.vendorId,
        product_name: item.products.name,
        product_image_url: null,
        sku: null,
        quantity: item.quantity,
        unit_price: parseFloat(item.unit_price),
        line_total: Math.round(parseFloat(item.unit_price) * item.quantity * 100) / 100,
      }))

      const { error: itemsErr } = await supabase.from('order_items').insert(itemsToInsert)
      if (itemsErr) throw itemsErr

      // Decrement stock where tracked
      for (const item of vt.items) {
        if (item.products.track_inventory) {
          await supabase.rpc('decrement_stock', {
            p_product_id: item.product_id,
            p_quantity: item.quantity,
          })
        }
      }
    }

    // 8. Clear cart items
    await supabase.from('cart_items').delete().eq('cart_id', cart.id)

    return new Response(
      JSON.stringify({
        success: true,
        customer_order_id: customerOrder.id,
        vendor_order_ids: vendorOrderIds,
        total: orderTotal,
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
