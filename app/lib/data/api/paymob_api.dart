import 'package:lawyer_app/data/api/api_client.dart';

class PaymobCheckoutResult {
  PaymobCheckoutResult({required this.paymentId, required this.checkoutUrl});

  final int paymentId;
  final String checkoutUrl;

  factory PaymobCheckoutResult.fromJson(Map<String, dynamic> json) {
    return PaymobCheckoutResult(
      paymentId: json['payment_id'] as int,
      checkoutUrl: json['checkout_url'] as String,
    );
  }
}

class PaymobReturnResult {
  PaymobReturnResult({required this.status, this.message});

  final String status;
  final String? message;

  factory PaymobReturnResult.fromJson(Map<String, dynamic> json) {
    return PaymobReturnResult(
      status: json['status'] as String,
      message: json['message'] as String?,
    );
  }
}

class SubscriptionPaymobApi {
  SubscriptionPaymobApi({ApiClient? client}) : _client = client ?? ApiClient();
  final ApiClient _client;

  Future<PaymobCheckoutResult> checkout({required int planId}) async {
    return _client.postJson<PaymobCheckoutResult>(
      'subscription/paymob/checkout',
      {'plan_id': planId},
      decode: (json) => PaymobCheckoutResult.fromJson(json as Map<String, dynamic>),
    );
  }

  Future<PaymobReturnResult> confirmReturn(Map<String, dynamic> payload) async {
    return _client.postJson<PaymobReturnResult>(
      'subscription/paymob/return',
      payload,
      decode: (json) => PaymobReturnResult.fromJson(json as Map<String, dynamic>),
    );
  }
}

class PaymobProviderDto {
  PaymobProviderDto({
    required this.provider,
    required this.mode,
    required this.isEnabled,
    this.publicKeyLast8,
    this.cardIntegrationId,
    this.currency = 'EGP',
  });

  final String provider;
  final String mode;
  final bool isEnabled;
  final String? publicKeyLast8;
  final int? cardIntegrationId;
  final String currency;

  factory PaymobProviderDto.fromJson(Map<String, dynamic> json) {
    return PaymobProviderDto(
      provider: json['provider'] as String,
      mode: json['mode'] as String,
      isEnabled: json['is_enabled'] as bool,
      publicKeyLast8: json['public_key_last8'] as String?,
      cardIntegrationId: (json['card_integration_id'] as num?)?.toInt(),
      currency: json['currency'] as String? ?? 'EGP',
    );
  }
}

class AdminPaymobApi {
  AdminPaymobApi({ApiClient? client}) : _client = client ?? ApiClient();
  final ApiClient _client;

  Future<PaymobProviderDto> getProvider() async {
    return _client.getJson<PaymobProviderDto>(
      'admin/payment-providers/paymob',
      decode: (json) => PaymobProviderDto.fromJson(json as Map<String, dynamic>),
    );
  }

  Future<PaymobProviderDto> saveProvider({
    String mode = 'test',
    String? publicKey,
    String? secretKey,
    String? hmacSecret,
    int? cardIntegrationId,
    int? walletIntegrationId,
    String currency = 'EGP',
    bool enabled = false,
  }) async {
    return _client.postJson<PaymobProviderDto>(
      'admin/payment-providers/paymob',
      {
        'mode': mode,
        if (publicKey != null && publicKey.isNotEmpty) 'public_key': publicKey,
        if (secretKey != null && secretKey.isNotEmpty) 'secret_key': secretKey,
        if (hmacSecret != null && hmacSecret.isNotEmpty) 'hmac_secret': hmacSecret,
        if (cardIntegrationId != null) 'card_integration_id': cardIntegrationId,
        if (walletIntegrationId != null) 'wallet_integration_id': walletIntegrationId,
        'currency': currency,
        'enabled': enabled,
      },
      decode: (json) => PaymobProviderDto.fromJson(json as Map<String, dynamic>),
    );
  }

  Future<Map<String, dynamic>> testConnection() async {
    return _client.postJson<Map<String, dynamic>>(
      'admin/payment-providers/paymob/test',
      {},
      decode: (json) => json as Map<String, dynamic>,
    );
  }
}
