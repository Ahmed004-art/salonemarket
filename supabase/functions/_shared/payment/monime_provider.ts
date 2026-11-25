import {
  IPaymentProvider,
  PaymentExecutionOutcome,
  PaymentInitiationRequest,
  PaymentProviderType,
} from './types.ts';

/**
 * Monime Payment Provider
 * Connects to Monime's Sierra Leone Payment Gateway API
 * Supporting Orange Money (m17) and AfriMoney (m18) with SLE currency.
 */
export class MonimePaymentProvider implements IPaymentProvider {
  readonly providerType: PaymentProviderType;

  private readonly token: string;
  private readonly spaceId: string;
  private readonly apiVersion = 'caph.2025-08-23';

  constructor(providerType: PaymentProviderType = 'monime') {
    this.providerType = providerType;
    this.token = Deno.env.get('MONIME_ACCESS_TOKEN') || '';
    this.spaceId = Deno.env.get('MONIME_SPACE_ID') || '';
  }

  /**
   * Normalizes Sierra Leone phone numbers to international E.164 format (+232...)
   */
  private formatPhoneNumber(phone?: string): string | undefined {
    if (!phone) return undefined;
    const clean = phone.replace(/[^0-9+]/g, '').trim();
    if (!clean) return undefined;

    if (clean.startsWith('+232')) return clean;
    if (clean.startsWith('232')) return `+${clean}`;
    if (clean.startsWith('0')) return `+232${clean.substring(1)}`;
    if (clean.length === 8) return `+232${clean}`;
    return clean;
  }

  async processPayment(request: PaymentInitiationRequest): Promise<PaymentExecutionOutcome> {
    if (!this.token || !this.spaceId) {
      return {
        status: 'failed',
        providerReference: 'MONIME-ERR-NO-CREDS',
        failureReason: 'Monime credentials are not configured on the server',
        isSimulated: false,
      };
    }

    const isTestToken = this.token.startsWith('mon_test_');

    // Map provider to Monime provider IDs:
    // m17 = Orange Money, m18 = AfriMoney
    let authorizedProviders: string[] = ['m17', 'm18'];
    if (this.providerType === 'orange_money') {
      authorizedProviders = ['m17'];
    } else if (this.providerType === 'afrimoney') {
      authorizedProviders = ['m18'];
    }

    const formattedPhone = this.formatPhoneNumber(request.phoneNumber);
    const amountInCents = Math.round(request.amount * 100);

    const idempotencyKey =
      request.idempotencyKey ||
      `monime-${request.customerOrderId}-${crypto.randomUUID().substring(0, 8)}`;

    const payload: Record<string, unknown> = {
      name: `Order #${request.customerOrderId.substring(0, 8).toUpperCase()}`,
      mode: 'one_time',
      amount: {
        currency: 'SLE',
        value: amountInCents,
      },
      duration: '30m',
      authorizedProviders,
      reference: request.customerOrderId,
      metadata: {
        customer_order_id: request.customerOrderId,
        customer_id: request.customerId,
        source: 'salonemarket_app',
      },
    };

    if (formattedPhone) {
      payload.authorizedPhoneNumber = formattedPhone;
    }

    try {
      const response = await fetch('https://api.monime.io/v1/payment-codes', {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${this.token}`,
          'Monime-Space-Id': this.spaceId,
          'Monime-Version': this.apiVersion,
          'Idempotency-Key': idempotencyKey,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(payload),
      });

      const data = await response.json();

      if (!response.ok || !data.success) {
        console.error('Monime API error response:', data);
        const errorMsg =
          data.error?.message ||
          data.messages?.[0] ||
          `Monime request failed with status ${response.status}`;

        return {
          status: 'failed',
          providerReference: `MONIME-FAIL-${crypto.randomUUID().substring(0, 8)}`,
          failureReason: errorMsg,
          isSimulated: isTestToken,
        };
      }

      const result = data.result;
      const ussdCode = result.ussdCode as string;

      return {
        status: 'processing',
        providerReference: result.id,
        ussdCode,
        requiresAction: true,
        actionMessage: `Dial ${ussdCode} on your handset to approve the payment with your PIN.`,
        isSimulated: isTestToken,
        metadata: {
          monime_payment_code_id: result.id,
          ussd_code: ussdCode,
          expire_time: result.expireTime,
          authorized_providers: result.authorizedProviders,
          financial_account_id: result.financialAccountId,
        },
      };
    } catch (err: unknown) {
      console.error('Network error communicating with Monime API:', err);
      const message = err instanceof Error ? err.message : 'Network error with Monime gateway';
      return {
        status: 'failed',
        providerReference: `MONIME-NET-ERR-${crypto.randomUUID().substring(0, 8)}`,
        failureReason: message,
        isSimulated: isTestToken,
      };
    }
  }
}
