import 'json.dart';

/// Money as the API sends it: exact piasters + a display string.
class Money {
  const Money({required this.piasters, required this.formatted});

  factory Money.fromJson(Object? json) {
    final map = json is Json ? json : const <String, dynamic>{};
    return Money(
      piasters: asInt(map['piasters']) ?? 0,
      formatted: map['formatted'] as String? ?? '',
    );
  }

  final int piasters;
  final String formatted;
}

class InvoiceItem {
  const InvoiceItem({
    required this.description,
    required this.kind,
    required this.amount,
  });

  factory InvoiceItem.fromJson(Json json) => InvoiceItem(
    description: json['description'] as String? ?? '',
    kind: json['kind'] as String? ?? 'fee',
    amount: Money.fromJson(json['amount']),
  );

  final String description;
  final String kind;
  final Money amount;
}

class Invoice {
  const Invoice({
    required this.id,
    required this.number,
    required this.period,
    this.dueOn,
    required this.status,
    required this.statusLabel,
    this.isOverdue = false,
    this.daysOverdue = 0,
    required this.total,
    required this.paid,
    required this.balance,
    this.discount,
    this.items = const [],
  });

  factory Invoice.fromJson(Json json) => Invoice(
    id: asInt(json['id'])!,
    number: json['number'] as String? ?? '',
    period: json['period'] as String? ?? '',
    dueOn: json['due_on'] as String?,
    status: json['status'] as String? ?? 'open',
    statusLabel: json['status_label'] as String? ?? '',
    isOverdue: asBool(json['is_overdue']),
    daysOverdue: asInt(json['days_overdue']) ?? 0,
    total: Money.fromJson(json['total']),
    paid: Money.fromJson(json['paid']),
    balance: Money.fromJson(json['balance']),
    discount: json['discount'] == null
        ? null
        : Money.fromJson(json['discount']),
    items: asList(json['items'], InvoiceItem.fromJson),
  );

  final int id;
  final String number;
  final String period;
  final String? dueOn;
  final String status;
  final String statusLabel;
  final bool isOverdue;
  final int daysOverdue;
  final Money total;
  final Money paid;
  final Money balance;
  final Money? discount;
  final List<InvoiceItem> items;

  bool get payable => balance.piasters > 0 && status != 'void';
}

class PaymentMethod {
  const PaymentMethod({
    required this.gateway,
    required this.label,
    required this.kind,
  });

  factory PaymentMethod.fromJson(Json json) => PaymentMethod(
    gateway: json['gateway'] as String,
    label: json['label'] as String? ?? '',
    kind: json['kind'] as String? ?? 'redirect',
  );

  final String gateway;
  final String label;

  /// redirect (open checkout_url) / payment_code (show the code)
  final String kind;
}

class CheckoutResult {
  const CheckoutResult({
    required this.gateway,
    required this.amount,
    this.checkoutUrl,
    this.paymentCode,
    this.expiresAt,
  });

  factory CheckoutResult.fromJson(Json json) => CheckoutResult(
    gateway: json['gateway'] as String? ?? '',
    amount: Money.fromJson(json['amount']),
    checkoutUrl: json['checkout_url'] as String?,
    paymentCode: json['payment_code'] as String?,
    expiresAt: parseDate(json['expires_at']),
  );

  final String gateway;
  final Money amount;
  final String? checkoutUrl;
  final String? paymentCode;
  final DateTime? expiresAt;
}

class Subscription {
  const Subscription({
    required this.status,
    required this.planName,
    this.priceEgp,
    this.periodEnd,
    this.childrenUsed,
    this.childrenLimit,
    this.features = const [],
  });

  factory Subscription.fromJson(Json json) {
    final data = json['data'] as Json? ?? const {};
    final plan = data['plan'] as Json? ?? const {};
    final entitlements = json['entitlements'] as Json? ?? const {};
    final children = (entitlements['limits'] as Json?)?['children'] as Json?;
    return Subscription(
      status: data['status'] as String? ?? '',
      planName:
          plan['name'] as String? ?? entitlements['plan_name'] as String? ?? '',
      priceEgp: asInt(plan['price_egp']),
      periodEnd: parseDate(data['current_period_end']),
      childrenUsed: asInt(children?['used']),
      childrenLimit: asInt(children?['limit']),
      features: (entitlements['features'] as List<dynamic>? ?? const [])
          .cast<String>(),
    );
  }

  final String status;
  final String planName;
  final int? priceEgp;
  final DateTime? periodEnd;
  final int? childrenUsed;
  final int? childrenLimit;
  final List<String> features;
}
