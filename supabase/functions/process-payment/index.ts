import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { corsHeaders } from '../_shared/cors.ts'
import { createAdminClient } from '../_shared/supabase_client.ts'
import { getAuthenticatedUser } from '../_shared/auth.ts'

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

  try {
    const supabase = createAdminClient()
    const user = await getAuthenticatedUser(req, supabase)

    // Parse body
    let customer_order_id: string
    let expected_amount: number | undefined
    try {
      const body = await req.json()
      customer_order_id = body?.customer_order_id
      expected_amount = body?.expected_amount
    } catch {
      return new Response(
        JSON.stringify({ error: 'Invalid request body' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    if (!customer_order_id) {
      return new Response(
        JSON.stringify({ error: 'customer_order_id is required' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // 1. Fetch the customer order and verify ownership
    const { data: order, error: orderFetchErr } = await supabase
      .from('customer_orders')
      .select('id, customer_id, status, payment_status, total')
      .eq('id', customer_order_id)
      .single()

    if (orderFetchErr || !order) {
      return new Response(
        JSON.stringify({ error: 'Order not found' }),
        { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    if (order.customer_id !== user.id) {
      return new Response(
        JSON.stringify({ error: 'Forbidden: you do not own this order' }),
        { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // 2. Validate order state
    if (order.status !== 'pending_payment') {
      return new Response(
        JSON.stringify({ error: `Order is not in pending_payment state (current: ${order.status})` }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    if (!['pending', 'failed'].includes(order.payment_status)) {
      return new Response(
        JSON.stringify({ error: `Payment cannot be retried (current payment_status: ${order.payment_status})` }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // 3. Idempotency check: if a 'processing' attempt already exists, return it
    const { data: existingAttempt } = await supabase
      .from('payment_attempts')
      .select('id, reference, status')
      .eq('customer_order_id', customer_order_id)
      .eq('status', 'processing')
      .maybeSingle()

    if (existingAttempt) {
      return new Response(
        JSON.stringify({
          success: true,
          idempotent: true,
          reference: existingAttempt.reference,
          payment_attempt_id: existingAttempt.id,
          status: 'processing',
          is_simulated: true,
          message: 'Payment already processing',
        }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // 4. Server-side amount verification
    const orderTotal = parseFloat(String(order.total))
    if (expected_amount !== undefined) {
      const clientAmount = parseFloat(String(expected_amount))
      if (Math.abs(clientAmount - orderTotal) > 0.01) {
        return new Response(
          JSON.stringify({
            error: `Amount mismatch: expected ${orderTotal}, client sent ${clientAmount}`,
          }),
          { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }
    }

    // 5. Generate payment reference
    const reference =
      'SM-' +
      crypto.randomUUID().substring(0, 8).toUpperCase() +
      '-' +
      new Date().toISOString().slice(0, 10).replace(/-/g, '')

    // 6. Create payment_attempt (status = 'processing')
    const { data: attempt, error: attemptErr } = await supabase
      .from('payment_attempts')
      .insert({
        customer_order_id,
        amount: orderTotal,
        currency: 'SLL',
        method: 'simulated',
        status: 'processing',
        reference,
        is_simulated: true,
        raw_response: { initiated_at: new Date().toISOString() },
      })
      .select()
      .single()

    if (attemptErr) throw attemptErr

    // 7. Update order payment_status to 'processing'
    await supabase
      .from('customer_orders')
      .update({ payment_status: 'processing', updated_at: new Date().toISOString() })
      .eq('id', customer_order_id)

    // 8. Simulate payment: 90% success rate
    const isSuccess = Math.random() < 0.90

    if (isSuccess) {
      // 9a. SUCCESS PATH

      // Update payment_attempt to succeeded
      await supabase
        .from('payment_attempts')
        .update({
          status: 'succeeded',
          raw_response: {
            initiated_at: attempt.created_at,
            completed_at: new Date().toISOString(),
            simulated: true,
            outcome: 'approved',
          },
          updated_at: new Date().toISOString(),
        })
        .eq('id', attempt.id)

      // Create transaction record
      const { data: transaction, error: txErr } = await supabase
        .from('transactions')
        .insert({
          customer_order_id,
          payment_attempt_id: attempt.id,
          type: 'payment',
          amount: orderTotal,
          currency: 'SLL',
          status: 'succeeded',
          reference,
          is_simulated: true,
          notes: 'Simulated payment — no real money transferred',
          metadata: { simulated: true, outcome: 'approved', timestamp: new Date().toISOString() },
        })
        .select()
        .single()

      if (txErr) throw txErr

      // Update customer_order to confirmed + paid
      await supabase
        .from('customer_orders')
        .update({
          status: 'confirmed',
          payment_status: 'paid',
          updated_at: new Date().toISOString(),
        })
        .eq('id', customer_order_id)

      // Update all vendor_orders to confirmed
      const { data: vendorOrders } = await supabase
        .from('vendor_orders')
        .select('id, vendor_id')
        .eq('customer_order_id', customer_order_id)

      if (vendorOrders?.length) {
        await supabase
          .from('vendor_orders')
          .update({ status: 'confirmed', updated_at: new Date().toISOString() })
          .eq('customer_order_id', customer_order_id)

        // Insert notifications for each vendor
        const vendorNotifications = vendorOrders.map((vo) => ({
          profile_id: vo.vendor_id,
          type: 'new_order',
          title: 'New Order Received',
          body: `Order #${customer_order_id.substring(0, 8).toUpperCase()} has been confirmed and payment received.`,
          data: { customer_order_id, vendor_order_id: vo.id },
          is_read: false,
        }))
        await supabase.from('notifications').insert(vendorNotifications)
      }

      // Insert notification for customer
      await supabase.from('notifications').insert({
        profile_id: user.id,
        type: 'payment_success',
        title: 'Payment Successful',
        body: `Your payment of SLL ${orderTotal.toFixed(2)} was successful. Order confirmed!`,
        data: { customer_order_id, reference, transaction_id: transaction.id },
        is_read: false,
      })

      return new Response(
        JSON.stringify({
          success: true,
          payment_status: 'succeeded',
          reference,
          customer_order_id,
          transaction_id: transaction.id,
          amount: orderTotal,
          currency: 'SLL',
          is_simulated: true,
          disclaimer: 'This is a simulated payment. No real money has been transferred.',
        }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    } else {
      // 9b. FAILURE PATH

      // Update payment_attempt to failed
      await supabase
        .from('payment_attempts')
        .update({
          status: 'failed',
          raw_response: {
            initiated_at: attempt.created_at,
            completed_at: new Date().toISOString(),
            simulated: true,
            outcome: 'declined',
            reason: 'Simulated decline',
          },
          updated_at: new Date().toISOString(),
        })
        .eq('id', attempt.id)

      // Create failed transaction record
      await supabase.from('transactions').insert({
        customer_order_id,
        payment_attempt_id: attempt.id,
        type: 'payment',
        amount: orderTotal,
        currency: 'SLL',
        status: 'failed',
        reference,
        is_simulated: true,
        notes: 'Simulated payment decline',
        metadata: {
          simulated: true,
          outcome: 'declined',
          reason: 'Simulated decline',
          timestamp: new Date().toISOString(),
        },
      })

      // Update customer_order payment_status to failed
      await supabase
        .from('customer_orders')
        .update({
          payment_status: 'failed',
          updated_at: new Date().toISOString(),
        })
        .eq('id', customer_order_id)

      // Insert failure notification for customer
      await supabase.from('notifications').insert({
        profile_id: user.id,
        type: 'payment_failed',
        title: 'Payment Failed',
        body: 'Your payment could not be processed. Please try again.',
        data: { customer_order_id, reference },
        is_read: false,
      })

      return new Response(
        JSON.stringify({
          success: false,
          payment_status: 'failed',
          reference,
          customer_order_id,
          amount: orderTotal,
          currency: 'SLL',
          is_simulated: true,
          error: 'Payment was declined (simulated)',
          disclaimer: 'This is a simulated payment. No real money has been transferred.',
        }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }
  } catch (err) {
    if (err instanceof Response) return err
    console.error('process-payment error:', err)
    return new Response(
      JSON.stringify({ error: 'Internal server error' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
