import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { corsHeaders } from '../_shared/cors.ts';
import { createAdminClient } from '../_shared/supabase_client.ts';
import { verifyMonimeWebhookSignature } from '../_shared/payment/monime_signature.ts';

/**
 * Hardened Monime Webhook Handler
 * SaloneMarket Phase 2 — Milestone 4.5
 *
 * Security Controls:
 * 1. Cryptographic HMAC-SHA256 signature verification over `timestamp_rawBody`.
 * 2. Replay protection: Enforces timestamp tolerance (max 300s old, 60s future).
 * 3. Event Idempotency: Checks for duplicate event IDs (`event.id`) before execution.
 * 4. Content Validation: Validates customer order ownership, attempt existence,
 *    exact amount match in SLE, and currency consistency.
 * 5. Atomic Settlement: Invokes PostgreSQL `settle_order_payment` with row-level locks,
 *    immutable ledger insertion, and duplicate payment reconciliation.
 */
serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  // 1. Webhooks must be HTTP POST
  if (req.method !== 'POST') {
    return new Response(JSON.stringify({ error: 'Method not allowed' }), {
      status: 405,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  const rawBody = await req.text();
  const signatureHeader = req.headers.get('monime-signature');
  const webhookSecret = Deno.env.get('MONIME_WEBHOOK_SECRET');

  // 2. Cryptographic Signature Verification
  const verification = await verifyMonimeWebhookSignature({
    signatureHeader,
    rawBody,
    secret: webhookSecret,
  });

  if (!verification.isValid) {
    console.warn(`[Monime Webhook] Unauthorized request rejected: ${verification.reason}`);
    return new Response(
      JSON.stringify({
        error: 'Unauthorized',
        message: 'Webhook signature verification failed',
      }),
      {
        status: verification.statusCode,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    );
  }

  try {
    const supabase = createAdminClient();
    let payload: Record<string, any>;

    try {
      payload = JSON.parse(rawBody);
    } catch {
      return new Response(JSON.stringify({ error: 'Invalid JSON payload' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const eventId = payload.event?.id as string | undefined;
    const eventName = payload.event?.name as string | undefined;
    const objectType = payload.object?.type as string | undefined;
    const data = payload.data || {};

    if (!eventId || !eventName) {
      return new Response(JSON.stringify({ error: 'Malformed event envelope: missing event.id or event.name' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    console.log(`[Monime Webhook] Verified event ${eventName} (${eventId}) for ${objectType}`);

    // 3. Durable Database Idempotency & Lease Acquisition (claim_payment_webhook_event)
    // Atomically manages processing leases, crash recovery, and prevents concurrent duplicate execution.
    const { data: claim, error: claimErr } = await supabase.rpc(
      'claim_payment_webhook_event',
      {
        p_provider: 'monime',
        p_event_id: eventId,
        p_event_name: eventName,
        p_payload: payload,
        p_lease_seconds: 60,
      }
    );

    if (claimErr) {
      console.error('[Monime Webhook] Error acquiring event lease:', claimErr);
      return new Response(JSON.stringify({ error: 'Internal database error claiming event lease' }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    if (!claim.acquired) {
      if (claim.status === 'completed') {
        console.log(`[Monime Webhook] Idempotent duplicate: Event ${eventId} was already settled`);
        return new Response(
          JSON.stringify({
            success: true,
            duplicate_event: true,
            event_id: eventId,
            status: 'completed',
            message: 'Event was previously processed and settled',
          }),
          { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }

      if (claim.status === 'processing') {
        // Event is actively in-flight with an active, unexpired lease!
        // DO NOT return HTTP 200: doing so would tell Monime to stop retrying.
        // Return HTTP 429 with Retry-After so Monime will retry if this handler crashes.
        console.warn(`[Monime Webhook] Concurrent delivery: Event ${eventId} actively processing under lease`);
        const retryAfter = claim.retry_after_seconds || 5;
        return new Response(
          JSON.stringify({
            error: 'Conflict: event currently processing',
            in_flight: true,
            event_id: eventId,
            retry_after_seconds: retryAfter,
          }),
          {
            status: 429,
            headers: {
              ...corsHeaders,
              'Content-Type': 'application/json',
              'Retry-After': String(retryAfter),
            },
          }
        );
      }
    }

    console.log(`[Monime Webhook] Acquired processing lease for event ${eventId} (${claim.reason})`);

    // 4. Branch by Domain: Payout Events vs Inbound Collection Events
    if (eventName.startsWith('payout.')) {
      // In accordance with Caph release specification:
      // Only handle terminal payout events: payout.completed and payout.failed.
      // Do not depend on payout.processing unless confirmed.
      // All other/unknown payout events are safely acknowledged without database mutation.
      if (eventName !== 'payout.completed' && eventName !== 'payout.failed') {
        console.log(`[Monime Webhook] Safely acknowledging unconfirmed payout event without mutation: ${eventName}`);
        await supabase
          .from('payment_webhook_events')
          .update({ status: 'ignored', updated_at: new Date().toISOString() })
          .eq('provider', 'monime')
          .eq('event_id', eventId);

        return new Response(
          JSON.stringify({ received: true, ignored: true, event: eventName }),
          { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }

      const payoutRef = data.reference || data.metadata?.payout_reference;
      const payoutId = data.metadata?.payout_id;
      const providerPayoutId = data.id || payload.object?.id;

      let payoutQuery = supabase
        .from('vendor_payouts')
        .select('*');

      if (payoutId) {
        payoutQuery = payoutQuery.eq('id', payoutId);
      } else if (payoutRef) {
        payoutQuery = payoutQuery.eq('payout_reference', payoutRef);
      } else if (providerPayoutId) {
        payoutQuery = payoutQuery.eq('provider_payout_id', providerPayoutId);
      } else {
        await supabase
          .from('payment_webhook_events')
          .update({ status: 'failed', error_message: 'Missing payout identifier in payload', updated_at: new Date().toISOString() })
          .eq('provider', 'monime')
          .eq('event_id', eventId);

        return new Response(JSON.stringify({ error: 'Missing payout reference in payload' }), {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        });
      }

      const { data: payout, error: payoutErr } = await payoutQuery.maybeSingle();

      if (payoutErr || !payout) {
        console.error(`[Monime Webhook] Payout not found for event ${eventId}:`, payoutErr);
        await supabase
          .from('payment_webhook_events')
          .update({ status: 'failed', error_message: 'Payout record not found', updated_at: new Date().toISOString() })
          .eq('provider', 'monime')
          .eq('event_id', eventId);

        return new Response(JSON.stringify({ error: 'Payout record not found' }), {
          status: 404,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        });
      }

      const rawCents = data.amount?.value;
      const webhookAmountSLE = rawCents !== undefined && rawCents !== null ? rawCents / 100.0 : null;
      const webhookCurrency = data.amount?.currency || 'SLE';

      // Validate currency
      if (webhookCurrency !== 'SLE') {
        await supabase
          .from('payment_webhook_events')
          .update({ status: 'failed', error_message: `Currency mismatch: ${webhookCurrency}`, updated_at: new Date().toISOString() })
          .eq('provider', 'monime')
          .eq('event_id', eventId);

        return new Response(JSON.stringify({ error: `Currency mismatch: expected SLE, got ${webhookCurrency}` }), {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        });
      }

      if (eventName === 'payout.completed') {
        if (payout.status === 'completed') {
          // Idempotent duplicate: acknowledge without re-mutating
          await supabase
            .from('payment_webhook_events')
            .update({ status: 'completed', updated_at: new Date().toISOString() })
            .eq('provider', 'monime')
            .eq('event_id', eventId);

          return new Response(JSON.stringify({ success: true, message: 'Payout already completed' }), {
            status: 200,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          });
        }

        // Call dedicated finalize_completed_payout database function.
        // This function ONLY finalizes the existing in-flight payout record, validates
        // Monime payout ID, amount, and currency, and records the ledger debit exactly once.
        // It NEVER initiates an outbound Monime transfer.
        const { data: finalizeResult, error: finalizeErr } = await supabase.rpc(
          'finalize_completed_payout',
          {
            p_payout_id: payout.id,
            p_provider_payout_id: providerPayoutId || payout.payout_reference,
            p_amount: webhookAmountSLE,
            p_currency: webhookCurrency,
            p_metadata: {
              monime_event_id: eventId,
              monime_event_name: eventName,
              webhook_received_at: new Date().toISOString(),
            },
          }
        );

        if (finalizeErr || !finalizeResult?.success) {
          const errDetail = finalizeErr?.message || finalizeResult?.error || 'Failed to finalize payout';
          console.error('[Monime Webhook] Error in finalize_completed_payout:', errDetail);
          await supabase
            .from('payment_webhook_events')
            .update({ status: 'failed', error_message: errDetail, updated_at: new Date().toISOString() })
            .eq('provider', 'monime')
            .eq('event_id', eventId);

          return new Response(JSON.stringify({ error: errDetail }), {
            status: 500,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          });
        }

        await supabase
          .from('payment_webhook_events')
          .update({ status: 'completed', updated_at: new Date().toISOString() })
          .eq('provider', 'monime')
          .eq('event_id', eventId);

        return new Response(JSON.stringify({ success: true, finalization: finalizeResult }), {
          status: 200,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        });
      } else if (eventName === 'payout.failed') {
        const failureReason = data.failureReason || data.message || 'Payout failed at provider';
        await supabase
          .from('vendor_payouts')
          .update({
            status: 'failed',
            failure_reason: failureReason,
            provider_payout_id: providerPayoutId,
            updated_at: new Date().toISOString(),
          })
          .eq('id', payout.id);

        await supabase
          .from('payment_webhook_events')
          .update({ status: 'completed', updated_at: new Date().toISOString() })
          .eq('provider', 'monime')
          .eq('event_id', eventId);

        return new Response(JSON.stringify({ success: true, status: 'failed', reason: failureReason }), {
          status: 200,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        });
      }
    }

    // 5. Inbound Payment Code Collection Events (Customer Checkout)
    // CRITICAL: In Monime Caph architecture:
    // - payment_code.processed: intermediate processing state (e.g. USSD push sent, awaiting PIN).
    //   Must NEVER settle an order or mark it as paid!
    // - payment_code.completed: terminal success state. ONLY event that may settle an order.
    // - payment_code.cancelled / payment_code.expired: terminal failure states.
    const isCompletedEvent = eventName === 'payment_code.completed';
    const isProcessingEvent = eventName === 'payment_code.processed';
    const isFailureEvent =
      eventName === 'payment_code.cancelled' ||
      eventName === 'payment_code.expired';

    if (!isCompletedEvent && !isProcessingEvent && !isFailureEvent) {
      // Safely acknowledge unhandled events without database changes
      await supabase
        .from('payment_webhook_events')
        .update({ status: 'ignored', updated_at: new Date().toISOString() })
        .eq('provider', 'monime')
        .eq('event_id', eventId);

      return new Response(
        JSON.stringify({ received: true, ignored: true, event: eventName }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // 5. Extract and Validate Order & Payment Data
    const customerOrderId =
      data.reference ||
      data.metadata?.customer_order_id ||
      payload.object?.metadata?.customer_order_id;

    const paymentCodeId = data.id || payload.object?.id;

    if (!customerOrderId) {
      console.error('[Monime Webhook] Missing customer order reference in payload:', data);
      await supabase
        .from('payment_webhook_events')
        .update({ status: 'failed', error_message: 'Missing customer order reference', updated_at: new Date().toISOString() })
        .eq('provider', 'monime')
        .eq('event_id', eventId);

      return new Response(
        JSON.stringify({ error: 'Missing customer order reference in payload' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // 6. Find Associated Payment Attempt in Database
    let attemptQuery = supabase
      .from('payment_attempts')
      .select('id, customer_order_id, customer_id, amount, currency, status, provider');

    if (paymentCodeId) {
      attemptQuery = attemptQuery.or(`provider_reference.eq.${paymentCodeId},customer_order_id.eq.${customerOrderId}`);
    } else {
      attemptQuery = attemptQuery.eq('customer_order_id', customerOrderId);
    }

    const { data: attempt, error: attemptErr } = await attemptQuery
      .order('created_at', { ascending: false })
      .limit(1)
      .maybeSingle();

    if (attemptErr || !attempt) {
      console.error(`[Monime Webhook] Unknown payment reference: No attempt found for order ${customerOrderId} or code ${paymentCodeId}`);
      await supabase
        .from('payment_webhook_events')
        .update({ status: 'failed', error_message: 'Unknown payment reference', updated_at: new Date().toISOString() })
        .eq('provider', 'monime')
        .eq('event_id', eventId);

      return new Response(
        JSON.stringify({ error: 'Unknown payment reference: payment attempt not found' }),
        { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Associate event log with order & attempt
    await supabase
      .from('payment_webhook_events')
      .update({
        customer_order_id: attempt.customer_order_id,
        payment_attempt_id: attempt.id,
      })
      .eq('provider', 'monime')
      .eq('event_id', eventId);

    // 7. Currency & Amount Validation
    // Monime amounts are represented in minor units (cents): e.g. 25000 = SLE 250.00
    const rawCents = data.amount?.value;
    const webhookCurrency = data.amount?.currency || 'SLE';

    if (webhookCurrency !== 'SLE') {
      console.error(`[Monime Webhook] Currency mismatch: expected SLE, received ${webhookCurrency}`);
      await supabase
        .from('payment_webhook_events')
        .update({ status: 'failed', error_message: `Unsupported currency: ${webhookCurrency}`, updated_at: new Date().toISOString() })
        .eq('provider', 'monime')
        .eq('event_id', eventId);

      return new Response(
        JSON.stringify({ error: `Unsupported currency: ${webhookCurrency}` }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const attemptAmount = parseFloat(String(attempt.amount));

    if (rawCents !== undefined && rawCents !== null) {
      const webhookAmountLeone = rawCents / 100.0;
      if (Math.abs(attemptAmount - webhookAmountLeone) > 0.01) {
        console.error(`[Monime Webhook] Amount tampering or mismatch: attempt has ${attemptAmount}, webhook reported ${webhookAmountLeone}`);
        await supabase
          .from('payment_webhook_events')
          .update({ status: 'failed', error_message: `Amount mismatch: attempt expected ${attemptAmount}, webhook reported ${webhookAmountLeone}`, updated_at: new Date().toISOString() })
          .eq('provider', 'monime')
          .eq('event_id', eventId);

        return new Response(
          JSON.stringify({
            error: `Amount mismatch: attempt expected ${attemptAmount}, webhook reported ${webhookAmountLeone}`,
          }),
          { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }
    }

    // 8. Processing State Handling: payment_code.processed
    // Acknowledge processing state WITHOUT settling or modifying order status to 'paid'
    if (isProcessingEvent) {
      console.log(`[Monime Webhook] payment_code.processed: payment code ${paymentCodeId} is in processing state`);
      if (attempt.status !== 'processing') {
        await supabase
          .from('payment_attempts')
          .update({
            status: 'processing',
            provider_reference: paymentCodeId,
            updated_at: new Date().toISOString(),
          })
          .eq('id', attempt.id);
      }

      await supabase
        .from('payment_webhook_events')
        .update({ status: 'completed', updated_at: new Date().toISOString() })
        .eq('provider', 'monime')
        .eq('event_id', eventId);

      return new Response(
        JSON.stringify({
          success: true,
          status: 'processing',
          customer_order_id: attempt.customer_order_id,
          payment_code_id: paymentCodeId,
          message: 'Payment code is in processing state; order remains pending awaiting completed confirmation',
        }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // 9. Atomic Database Settlement via RPC (Terminal Events Only)
    // Only payment_code.completed triggers 'succeeded'.
    // Cancelled / expired events trigger 'failed'.
    const targetStatus = isCompletedEvent ? 'succeeded' : 'failed';
    const failureReason = isFailureEvent
      ? `Monime payment code was ${eventName.replace('payment_code.', '')}`
      : null;

    const { data: settlementResult, error: settleErr } = await supabase.rpc(
      'settle_order_payment',
      {
        p_customer_order_id: attempt.customer_order_id,
        p_payment_attempt_id: attempt.id,
        p_customer_id: attempt.customer_id,
        p_payment_status: targetStatus,
        p_amount: attemptAmount,
        p_currency: attempt.currency || 'SLE',
        p_provider_reference: paymentCodeId,
        p_failure_reason: failureReason,
        p_metadata: {
          monime_event_id: eventId,
          monime_event_name: eventName,
          monime_payment_code_id: paymentCodeId,
          verified_signature: true,
          webhook_received_at: new Date().toISOString(),
          channel_data: data.processedPaymentData?.channelData || null,
        },
      }
    );

    if (settleErr) {
      console.error('[Monime Webhook] Error during atomic settlement RPC:', settleErr);
      await supabase
        .from('payment_webhook_events')
        .update({ status: 'failed', error_message: settleErr.message, updated_at: new Date().toISOString() })
        .eq('provider', 'monime')
        .eq('event_id', eventId);

      return new Response(JSON.stringify({ error: settleErr.message }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // Mark event successfully completed
    await supabase
      .from('payment_webhook_events')
      .update({ status: 'completed', updated_at: new Date().toISOString() })
      .eq('provider', 'monime')
      .eq('event_id', eventId);

    console.log(`[Monime Webhook] Order ${attempt.customer_order_id} successfully settled:`, settlementResult);

    return new Response(
      JSON.stringify({
        success: true,
        settlement: settlementResult,
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  } catch (err: unknown) {
    console.error('[Monime Webhook] Unhandled exception:', err);
    const message = err instanceof Error ? err.message : 'Internal server error';
    return new Response(JSON.stringify({ error: message }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});
