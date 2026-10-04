import '../core/models/billing.dart';
import '../core/models/json.dart';
import '../core/network/api_client.dart';

class BillingRepository {
  BillingRepository(this._api);

  final ApiClient _api;

  Future<List<Invoice>> invoices() async =>
      asList((await _api.get('/v1/me/invoices'))['data'], Invoice.fromJson);

  Future<Invoice> invoice(int id) async =>
      Invoice.fromJson((await _api.get('/v1/me/invoices/$id'))['data'] as Json);

  Future<List<PaymentMethod>> paymentMethods() async => asList(
    (await _api.get('/v1/me/payment-methods'))['data'],
    PaymentMethod.fromJson,
  );

  Future<CheckoutResult> checkout(int invoiceId, String gateway) async =>
      CheckoutResult.fromJson(
        (await _api.post(
              '/v1/me/invoices/$invoiceId/checkout',
              data: {'gateway': gateway},
            ))['data']
            as Json,
      );

  Future<Subscription> subscription() async =>
      Subscription.fromJson(await _api.get('/v1/subscription'));
}
