/**
 * Monime Outbound Payout / Disbursement Adapter
 * Handles server-side automated payouts via Monime's `/v1/payouts` API
 * Supporting Orange Money (m17) and AfriMoney (m18) mobile wallets & bank accounts in Sierra Leone.
 */

export interface PayoutDestination {
  type: 'mobile_money' | 'bank_account';
  provider: string; // 'orange_money', 'afrimoney', 'slcb', 'rokel', etc.
  accountNumber: string;
  accountName: string;
}

export interface PayoutInitiationRequest {
  payoutId: string;
  payoutReference: string;
  vendorId: string;
  amount: number; // in SLE
  destination: PayoutDestination;
  idempotencyKey?: string;
  notes?: string;
}

export interface PayoutExecutionOutcome {
  status: 'processing' | 'completed' | 'failed';
  providerPayoutId?: string;
  providerReference?: string;
  failureReason?: string;
  isSimulated: boolean;
}

export class MonimePayoutAdapter {
  private readonly token: string;
  private readonly spaceId: string;
  private readonly sourceAccountId?: string;
  private readonly apiVersion = 'caph.2025-08-23';

  constructor() {
    this.token = Deno.env.get('MONIME_ACCESS_TOKEN') || '';
    this.spaceId = Deno.env.get('MONIME_SPACE_ID') || '';
    this.sourceAccountId = Deno.env.get('MONIME_SOURCE_ACCOUNT_ID') || undefined;
  }

  /**
   * Normalizes Sierra Leone phone numbers to E.164 (+232...)
   */
  private formatPhoneNumber(phone: string): string {
    const clean = phone.replace(/[^0-9+]/g, '').trim();
    if (clean.startsWith('+232')) return clean;
    if (clean.startsWith('232')) return `+${clean}`;
    if (clean.startsWith('0')) return `+232${clean.substring(1)}`;
    if (clean.length === 8) return `+232${clean}`;
    return clean;
  }

  /**
   * Disburses funds to vendor via Monime Payouts API
   * Note: In accordance with Caph specification, outbound transfers are asynchronous.
   * Payout initiation NEVER treats newly created pending payouts as completed synchronously.
   */
  async disbursePayout(request: PayoutInitiationRequest): Promise<PayoutExecutionOutcome> {
    if (!this.token || !this.spaceId) {
      return {
        status: 'failed',
        failureReason: 'Monime credentials are not configured on the server',
        isSimulated: false,
      };
    }

    const idempotencyKey = request.idempotencyKey || `payout-${request.payoutReference}`;
    const amountInCents = Math.round(request.amount * 100);

    // Map provider to Monime destination format
    let destinationPayload: Record<string, unknown>;
    if (request.destination.type === 'mobile_money') {
      const providerId = request.destination.provider === 'orange_money' ? 'm17' : 'm18';
      destinationPayload = {
        type: 'mobile_money',
        providerId,
        accountNumber: this.formatPhoneNumber(request.destination.accountNumber),
        accountName: request.destination.accountName,
      };
    } else {
      destinationPayload = {
        type: 'bank',
        providerId: request.destination.provider,
        accountNumber: request.destination.accountNumber,
        accountName: request.destination.accountName,
      };
    }

    const payload: Record<string, unknown> = {
      amount: {
        currency: 'SLE',
        value: amountInCents,
      },
      destination: destinationPayload,
      reference: request.payoutReference,
      metadata: {
        payout_id: request.payoutId,
        payout_reference: request.payoutReference,
        vendor_id: request.vendorId,
        source: 'salonemarket_vendor_disbursement',
      },
    };

    if (this.sourceAccountId) {
      payload.source = {
        type: 'wallet',
        id: this.sourceAccountId,
      };
    }

    try {
      const response = await fetch('https://api.monime.io/v1/payouts', {
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

      const responseBody = await response.json();

      if (!response.ok) {
        return {
          status: 'failed',
          failureReason: responseBody?.message || responseBody?.error || `HTTP ${response.status}`,
          isSimulated: false,
        };
      }

      // CRITICAL: Newly created payouts are ALWAYS initiated in 'processing' state.
      // Outbound disbursement across Orange Money / Afrimoney / Bank rails is asynchronous.
      // Settlement to completed state occurs ONLY upon verified reconciliation or webhook event.
      return {
        status: 'processing',
        providerPayoutId: responseBody.id,
        providerReference: responseBody.reference || responseBody.id,
        isSimulated: false,
      };
    } catch (err) {
      return {
        status: 'failed',
        failureReason: err instanceof Error ? err.message : String(err),
        isSimulated: false,
      };
    }
  }

  /**
   * Reconciles payout status via Monime GET endpoint (GET /v1/payouts/{id})
   */
  async getPayout(payoutId: string): Promise<PayoutExecutionOutcome> {
    if (!this.token || !this.spaceId) {
      return {
        status: 'failed',
        failureReason: 'Monime credentials are not configured on the server',
        isSimulated: false,
      };
    }

    try {
      const response = await fetch(`https://api.monime.io/v1/payouts/${encodeURIComponent(payoutId)}`, {
        method: 'GET',
        headers: {
          'Authorization': `Bearer ${this.token}`,
          'Monime-Space-Id': this.spaceId,
          'Monime-Version': this.apiVersion,
        },
      });

      const responseBody = await response.json();

      if (!response.ok) {
        return {
          status: 'failed',
          failureReason: responseBody?.message || responseBody?.error || `HTTP ${response.status}`,
          isSimulated: false,
        };
      }

      const monimeStatus = responseBody.status;
      if (monimeStatus === 'completed') {
        return {
          status: 'completed',
          providerPayoutId: responseBody.id,
          providerReference: responseBody.reference || responseBody.id,
          isSimulated: false,
        };
      } else if (monimeStatus === 'failed' || monimeStatus === 'cancelled') {
        return {
          status: 'failed',
          providerPayoutId: responseBody.id,
          providerReference: responseBody.reference || responseBody.id,
          failureReason: responseBody.failureReason || responseBody.message || `Payout ${monimeStatus}`,
          isSimulated: false,
        };
      } else {
        return {
          status: 'processing',
          providerPayoutId: responseBody.id,
          providerReference: responseBody.reference || responseBody.id,
          isSimulated: false,
        };
      }
    } catch (err) {
      return {
        status: 'failed',
        failureReason: err instanceof Error ? err.message : String(err),
        isSimulated: false,
      };
    }
  }
}
