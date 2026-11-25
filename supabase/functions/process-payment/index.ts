import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { corsHeaders } from '../_shared/cors.ts'
import { createAdminClient } from '../_shared/supabase_client.ts'
import { getAuthenticatedUser } from '../_shared/auth.ts'
import { PaymentProviderFactory } from '../_shared/payment/provider_factory.ts'
import { PaymentProviderType } from '../_shared/payment/types.ts'

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

  try {
    const supabase = createAdminClient()
    const user = await getAuthenticatedUser(req, supabase)

    // 1. Parse and validate request payload
    let customer_order_id: string
    let expected_amount: number | undefined
    let method: string = 'simulated'
    let provider: PaymentProviderType = 'simulated'
    let phone_number: string | undefined
    let idempotency_key: string | undefined

    try {
      const body = await req.json()
      customer_order_id = body?.customer_order_id
      expected_amount = body?.expected_amount
      method = body?.method || 'simulated'
      provider = (body?.provider as PaymentProviderType) || 'simulated'
      phone_number = body?.phone_number
      idempotency_key =
        req.headers.get('Idempotency-Key') ||
        body?.idempotency_key ||
        crypto.randomUUID()
    } catch {
      return new Response(
        JSON.stringify({ error: 'Invalid JSON request body' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    if (!customer_order_id) {
      return new Response(
        JSON.stringify({ error: 'customer_order_id is required' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // 2. Fetch customer order and verify ownership
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

    // 3. Validate order state
    if (order.status !== 'pending_payment') {
      return new Response(
        JSON.stringify({
          error: `Order is not in pending_payment state (current: ${order.status})`,
          order_status: order.status,
          payment_status: order.payment_status,
        }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    if (!['pending', 'failed'].includes(order.payment_status)) {
      return new Response(
        JSON.stringify({
          error: `Payment cannot be initiated (current payment_status: ${order.payment_status})`,
          payment_status: order.payment_status,
        }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // 4. Server-authoritative amount validation
    const orderTotal = parseFloat(String(order.total))
    if (expected_amount !== undefined) {
      const clientAmount = parseFloat(String(expected_amount))
      if (Math.abs(clientAmount - orderTotal) > 0.01) {
        return new Response(
          JSON.stringify({
            error: `Amount mismatch: server expected ${orderTotal}, client sent ${clientAmount}`,
          }),
          { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }
    }

    // 5. Step 1: Create or retrieve idempotent payment attempt via atomic RPC
    const { data: attemptResult, error: attemptRpcErr } = await supabase.rpc(
      'create_or_get_payment_attempt',
      {
        p_customer_order_id: customer_order_id,
        p_customer_id: user.id,
        p_amount: orderTotal,
        p_currency: 'SLE',
        p_method: method,
        p_provider: provider,
        p_idempotency_key: idempotency_key,
        p_metadata: {
          client_ip: req.headers.get('x-forwarded-for') || 'unknown',
          user_agent: req.headers.get('user-agent') || 'unknown',
          phone_number: phone_number || null,
        },
      }
    )

    if (attemptRpcErr) {
      console.error('Error in create_or_get_payment_attempt RPC:', attemptRpcErr)
      return new Response(
        JSON.stringify({ error: attemptRpcErr.message || 'Failed to create payment attempt' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const attemptId = attemptResult.payment_attempt_id
    const isSimulatedProvider = provider === 'simulated' || method === 'simulated'

    // If this is an idempotent replay of an already completed or in-flight attempt, return it directly
    if (attemptResult.idempotent_replay) {
      if (attemptResult.status === 'succeeded') {
        const wasSimulated = attemptResult.provider === 'simulated'
        return new Response(
          JSON.stringify({
            success: true,
            idempotent: true,
            idempotent_replay: true,
            payment_status: 'succeeded',
            order_status: 'confirmed',
            customer_order_id,
            payment_attempt_id: attemptId,
            reference: attemptResult.reference,
            provider_reference: attemptResult.provider_reference,
            amount: attemptResult.amount,
            currency: attemptResult.currency,
            is_simulated: wasSimulated,
            message: 'Payment was previously settled successfully',
          }),
          { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }

      if (attemptResult.status === 'processing' && attemptResult.provider_reference) {
        const { data: existingAttempt } = await supabase
          .from('payment_attempts')
          .select('metadata, is_simulated')
          .eq('id', attemptId)
          .maybeSingle()
        const existingUssd = existingAttempt?.metadata?.ussd_code ?? null
        return new Response(
          JSON.stringify({
            success: false,
            idempotent: true,
            idempotent_replay: true,
            payment_status: 'processing',
            order_status: 'pending_payment',
            customer_order_id,
            payment_attempt_id: attemptId,
            reference: attemptResult.reference,
            provider_reference: attemptResult.provider_reference,
            ussd_code: existingUssd,
            requires_action: existingUssd != null,
            action_message: existingUssd
              ? `Dial ${existingUssd} on your handset to approve the payment with your PIN.`
              : 'Payment outcome pending subscriber action.',
            message: 'Payment already initiated and awaiting confirmation.',
            amount: attemptResult.amount,
            currency: attemptResult.currency,
            is_simulated: existingAttempt?.is_simulated ?? isSimulatedProvider,
            retryable: false,
          }),
          { status: 202, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }
    }

    // 6. Step 2: Invoke Payment Provider (Simulated)
    // Note: Database transactions are NEVER held open while awaiting provider response
    const paymentProvider = PaymentProviderFactory.getProvider(provider)
    const outcome = await paymentProvider.processPayment({
      customerOrderId: customer_order_id,
      customerId: user.id,
      amount: orderTotal,
      currency: 'SLE',
      paymentMethod: method,
      provider,
      phoneNumber: phone_number,
      idempotencyKey: idempotency_key,
    })

    // 7. Step 3: Atomic Settlement via PostgreSQL RPC
    if (outcome.status === 'succeeded') {
      const { data: settlementResult, error: settleErr } = await supabase.rpc(
        'settle_order_payment',
        {
          p_customer_order_id: customer_order_id,
          p_payment_attempt_id: attemptId,
          p_customer_id: user.id,
          p_payment_status: 'succeeded',
          p_amount: orderTotal,
          p_currency: 'SLE',
          p_provider_reference: outcome.providerReference,
          p_metadata: outcome.metadata || {},
        }
      )

      if (settleErr) {
        console.error('Error in settle_order_payment RPC (success):', settleErr)
        throw settleErr
      }

      return new Response(
        JSON.stringify({
          success: true,
          payment_status: 'succeeded',
          order_status: settlementResult.order_status || 'confirmed',
          customer_order_id,
          payment_attempt_id: attemptId,
          transaction_id: settlementResult.transaction_id,
          reference: settlementResult.transaction_reference,
          provider_reference: outcome.providerReference,
          amount: orderTotal,
          currency: 'SLE',
          is_simulated: outcome.isSimulated,
          reconciliation_needed: settlementResult.reconciliation_needed || false,
          ...(outcome.isSimulated
            ? {
                disclaimer:
                  'This is a simulated transaction. No real payment has been processed. No money has been transferred.',
              }
            : {}),
        }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    } else if (outcome.status === 'failed') {
      const { data: settlementResult, error: settleErr } = await supabase.rpc(
        'settle_order_payment',
        {
          p_customer_order_id: customer_order_id,
          p_payment_attempt_id: attemptId,
          p_customer_id: user.id,
          p_payment_status: 'failed',
          p_amount: orderTotal,
          p_currency: 'SLE',
          p_provider_reference: outcome.providerReference,
          p_failure_reason: outcome.failureReason || 'Payment declined by payment provider',
          p_metadata: outcome.metadata || {},
        }
      )

      if (settleErr) {
        console.error('Error in settle_order_payment RPC (failure):', settleErr)
        throw settleErr
      }

      return new Response(
        JSON.stringify({
          success: false,
          payment_status: 'failed',
          order_status: settlementResult.order_status || 'pending_payment',
          customer_order_id,
          payment_attempt_id: attemptId,
          transaction_id: settlementResult.transaction_id,
          reference: settlementResult.transaction_reference,
          provider_reference: outcome.providerReference,
          failure_reason: outcome.failureReason,
          amount: orderTotal,
          currency: 'SLE',
          is_simulated: outcome.isSimulated,
          retryable: true,
        }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    } else {
      // Pending, USSD Action, or Timeout: Persist provider_reference & metadata so
      // monime-webhook and idempotent replays can match this payment attempt.
      await supabase
        .from('payment_attempts')
        .update({
          provider_reference: outcome.providerReference,
          is_simulated: outcome.isSimulated,
          metadata: {
            ...(outcome.metadata || {}),
            ussd_code: outcome.ussdCode || null,
          },
          updated_at: new Date().toISOString(),
        })
        .eq('id', attemptId)

      return new Response(
        JSON.stringify({
          success: false,
          payment_status: 'processing',
          order_status: 'pending_payment',
          customer_order_id,
          payment_attempt_id: attemptId,
          reference: attemptResult.reference,
          provider_reference: outcome.providerReference,
          ussd_code: outcome.ussdCode,
          requires_action: outcome.requiresAction ?? false,
          action_message: outcome.actionMessage,
          message: outcome.actionMessage || outcome.failureReason || 'Payment outcome pending subscriber action. Please check order status shortly.',
          amount: orderTotal,
          currency: 'SLE',
          is_simulated: outcome.isSimulated,
          retryable: false,
        }),
        { status: 202, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }
  } catch (err: unknown) {
    console.error('Unhandled error in process-payment function:', err)
    const message = err instanceof Error ? err.message : 'Internal server error'
    return new Response(
      JSON.stringify({ error: message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
