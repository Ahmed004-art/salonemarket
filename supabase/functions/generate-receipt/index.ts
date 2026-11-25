import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { corsHeaders } from '../_shared/cors.ts'
import { createAdminClient } from '../_shared/supabase_client.ts'
import { getAuthenticatedUser } from '../_shared/auth.ts'

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

  try {
    const supabase = createAdminClient()
    const user = await getAuthenticatedUser(req, supabase)

    // 1. Accept customer_order_id from query param or body
    let customer_order_id: string | null = null
    const url = new URL(req.url)
    customer_order_id = url.searchParams.get('customer_order_id')

    if (!customer_order_id && req.method === 'POST') {
      try {
        const body = await req.json()
        customer_order_id = body?.customer_order_id ?? null
      } catch {
        // body parsing failed
      }
    }

    if (!customer_order_id) {
      return new Response(
        JSON.stringify({ error: 'customer_order_id is required (query param or body)' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // 2. Fetch caller's profile to check role
    const { data: callerProfile } = await supabase
      .from('profiles')
      .select('id, role')
      .eq('id', user.id)
      .single()

    // 3. Fetch full order data
    const { data: order, error: orderErr } = await supabase
      .from('customer_orders')
      .select(`
        id, customer_id, status, payment_status, subtotal, delivery_fee, platform_fee, total,
        payment_method, notes, created_at, updated_at, shipping_address_id,
        addresses(id, label, full_name, phone, address_line_1, address_line_2, city, district)
      `)
      .eq('id', customer_order_id)
      .single()

    if (orderErr || !order) {
      return new Response(
        JSON.stringify({ error: 'Order not found' }),
        { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // 4. Authorization: customer who owns the order OR admin
    const isAdmin = callerProfile?.role === 'admin'
    const isOwner = order.customer_id === user.id
    if (!isAdmin && !isOwner) {
      return new Response(
        JSON.stringify({ error: 'Forbidden: you do not have access to this order' }),
        { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // 5. Verify order is in a state where a receipt is meaningful
    const receiptEligibleStatuses = ['confirmed', 'partially_fulfilled', 'fulfilled', 'cancelled', 'refunded']
    if (!receiptEligibleStatuses.includes(order.status)) {
      return new Response(
        JSON.stringify({ error: `Receipt not available for order status: ${order.status}` }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // 6. Fetch vendor orders + order items
    const { data: vendorOrders } = await supabase
      .from('vendor_orders')
      .select(`
        id, vendor_id, status, subtotal, delivery_fee, commission_amount, vendor_payout, created_at,
        vendors(id, shop_name, slug, phone, email, location),
        order_items(id, product_id, product_name, product_image_url, sku, quantity, unit_price, line_total)
      `)
      .eq('customer_order_id', customer_order_id)

    // 7. Fetch successful transaction
    const { data: transaction } = await supabase
      .from('transactions')
      .select('id, type, amount, currency, status, reference, is_simulated, created_at')
      .eq('customer_order_id', customer_order_id)
      .eq('status', 'succeeded')
      .maybeSingle()

    // 8. Fetch customer profile
    const { data: customerProfile } = await supabase
      .from('profiles')
      .select('id, full_name, phone, avatar_url')
      .eq('id', order.customer_id)
      .single()

    // 9. Build receipt number
    const receiptNumber = 'SM-RCP-' + customer_order_id.substring(0, 8).toUpperCase()
    const isSimulated = transaction
      ? Boolean(transaction.is_simulated)
      : order.payment_method === 'simulated'

    // 10. Build structured receipt JSON
    const receipt = {
      receipt_number: receiptNumber,
      generated_at: new Date().toISOString(),
      is_simulated: isSimulated,
      ...(isSimulated
        ? {
            disclaimer:
              'This is a simulated receipt generated for an academic project. No real financial transaction has occurred.',
          }
        : {}),

      order: {
        id: order.id,
        status: order.status,
        payment_status: order.payment_status,
        payment_method: order.payment_method,
        created_at: order.created_at,
        notes: order.notes ?? null,
      },

      customer: {
        id: order.customer_id,
        full_name: customerProfile?.full_name ?? null,
        phone: customerProfile?.phone ?? null,
      },

      shipping_address: order.addresses ?? null,

      line_items_by_vendor: (vendorOrders ?? []).map((vo) => ({
        vendor_order_id: vo.id,
        vendor: {
          id: vo.vendor_id,
          shop_name: vo.vendors?.shop_name ?? null,
          phone: vo.vendors?.phone ?? null,
          email: vo.vendors?.email ?? null,
          location: vo.vendors?.location ?? null,
        },
        status: vo.status,
        items: (vo.order_items ?? []).map((item: any) => ({
          product_id: item.product_id,
          product_name: item.product_name,
          product_image_url: item.product_image_url ?? null,
          sku: item.sku ?? null,
          quantity: item.quantity,
          unit_price: parseFloat(item.unit_price),
          line_total: parseFloat(item.line_total),
        })),
        subtotal: parseFloat(vo.subtotal),
        delivery_fee: parseFloat(vo.delivery_fee),
        commission_amount: parseFloat(vo.commission_amount),
        vendor_payout: parseFloat(vo.vendor_payout),
      })),

      totals: {
        subtotal: parseFloat(order.subtotal),
        delivery_fee: parseFloat(order.delivery_fee),
        platform_fee: parseFloat(order.platform_fee),
        total: parseFloat(order.total),
        currency: transaction ? transaction.currency : 'SLE',
      },

      transaction: transaction
        ? {
            id: transaction.id,
            reference: transaction.reference,
            type: transaction.type,
            status: transaction.status,
            amount: parseFloat(transaction.amount),
            currency: transaction.currency,
            is_simulated: transaction.is_simulated,
            processed_at: transaction.created_at,
          }
        : null,
    }

    return new Response(JSON.stringify(receipt), {
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  } catch (err) {
    if (err instanceof Response) return err
    console.error('generate-receipt error:', err)
    return new Response(
      JSON.stringify({ error: 'Internal server error' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
