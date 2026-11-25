/**
 * Payment Provider Abstraction Types
 * SaloneMarket Phase 2 — Milestone 4.3
 */

export type PaymentProviderType = 'simulated' | 'orange_money' | 'afrimoney' | 'monime';

export type PaymentOutcomeStatus = 'succeeded' | 'failed' | 'processing' | 'timeout';

export interface PaymentInitiationRequest {
  customerOrderId: string;
  customerId: string;
  amount: number;
  currency: string;
  paymentMethod: string;
  provider: PaymentProviderType;
  phoneNumber?: string;
  idempotencyKey?: string;
  metadata?: Record<string, unknown>;
}

export interface PaymentExecutionOutcome {
  status: PaymentOutcomeStatus;
  providerReference: string;
  failureReason?: string;
  isSimulated: boolean;
  requiresAction?: boolean;
  actionMessage?: string;
  ussdCode?: string;
  metadata?: Record<string, unknown>;
}

export interface IPaymentProvider {
  readonly providerType: PaymentProviderType;

  /**
   * Executes payment processing with the provider.
   * Note: This does NOT interact with the database; it handles only provider communication.
   */
  processPayment(request: PaymentInitiationRequest): Promise<PaymentExecutionOutcome>;
}
