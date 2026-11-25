import { IPaymentProvider, PaymentProviderType } from './types.ts';
import { SimulatedPaymentProvider } from './simulated_provider.ts';
import { MonimePaymentProvider } from './monime_provider.ts';

export class PaymentProviderFactory {
  static getProvider(providerType: PaymentProviderType = 'simulated'): IPaymentProvider {
    switch (providerType) {
      case 'simulated':
        return new SimulatedPaymentProvider();
      case 'monime':
      case 'orange_money':
      case 'afrimoney':
        return new MonimePaymentProvider(providerType);
      default:
        throw new Error(`Unknown payment provider: ${providerType}`);
    }
  }
}
