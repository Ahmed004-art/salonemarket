import {
  IPaymentProvider,
  PaymentExecutionOutcome,
  PaymentInitiationRequest,
  PaymentProviderType,
} from './types.ts';

/**
 * Simulated Payment Provider for development and local testing.
 *
 * Security Controls:
 * - Client parameters CANNOT force a successful outcome.
 * - Deterministic testing is supported strictly via designated test phone patterns
 *   or server-side environment flags.
 * - Always sets is_simulated = true.
 */
export class SimulatedPaymentProvider implements IPaymentProvider {
  readonly providerType: PaymentProviderType = 'simulated';

  async processPayment(request: PaymentInitiationRequest): Promise<PaymentExecutionOutcome> {
    const providerReference =
      'SIM-PAY-' +
      crypto.randomUUID().substring(0, 8).toUpperCase() +
      '-' +
      new Date().toISOString().slice(0, 10).replace(/-/g, '');

    const phone = request.phoneNumber?.trim() || '';

    // Deterministic testing via designated test phone numbers (standard payment gateway testing practice):
    // Ends with '0000' -> Deterministic Failure
    if (phone.endsWith('0000')) {
      return {
        status: 'failed',
        providerReference,
        failureReason: 'Simulated decline: insufficient mobile wallet balance or customer rejected prompt',
        isSimulated: true,
        metadata: {
          simulated: true,
          testPattern: 'failure_0000',
          timestamp: new Date().toISOString(),
        },
      };
    }

    // Ends with '9999' -> Deterministic Timeout / Pending
    if (phone.endsWith('9999')) {
      return {
        status: 'timeout',
        providerReference,
        failureReason: 'Simulated timeout: USSD prompt timed out on subscriber handset',
        isSimulated: true,
        metadata: {
          simulated: true,
          testPattern: 'timeout_9999',
          timestamp: new Date().toISOString(),
        },
      };
    }

    // Server-side environment override for automated testing
    const forceSuccessEnv = Deno.env.get('SIMULATED_PAYMENT_FORCE_SUCCESS');
    if (forceSuccessEnv === 'true') {
      return {
        status: 'succeeded',
        providerReference,
        isSimulated: true,
        metadata: {
          simulated: true,
          approved: true,
          timestamp: new Date().toISOString(),
        },
      };
    }

    // Default simulation: 90% success, 10% simulated failure
    const isSuccess = Math.random() < 0.90;

    if (isSuccess) {
      return {
        status: 'succeeded',
        providerReference,
        isSimulated: true,
        metadata: {
          simulated: true,
          approved: true,
          timestamp: new Date().toISOString(),
        },
      };
    } else {
      return {
        status: 'failed',
        providerReference,
        failureReason: 'Simulated network timeout or carrier decline',
        isSimulated: true,
        metadata: {
          simulated: true,
          declined: true,
          timestamp: new Date().toISOString(),
        },
      };
    }
  }
}
