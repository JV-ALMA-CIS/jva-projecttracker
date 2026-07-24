import 'dart:convert';

import 'package:http/http.dart' as http;

/// Live foreign-exchange rates via the open.er-api.com free endpoint (no API
/// key required). Frankfurter (ECB-sourced) was considered first but does
/// not cover KES; open.er-api.com covers USD/EUR/KES from a single call.
/// Rates are fetched on demand for display-only conversion — never
/// persisted, so a stale/failed fetch never silently writes a fabricated
/// value.
class CurrencyService {
  CurrencyService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const supportedCurrencies = ['EUR', 'USD', 'KES'];

  /// Fetches current rates from [base] to every other currency in
  /// [supportedCurrencies]. Throws on network/parse failure — callers must
  /// not fall back to a guessed rate.
  Future<Map<String, double>> fetchRates(String base) async {
    final uri = Uri.https('open.er-api.com', '/v6/latest/$base');

    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw Exception(
        'Failed to fetch exchange rates (${response.statusCode})',
      );
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (body['result'] != 'success') {
      throw Exception(
        'Exchange rate provider returned an error: ${body['result']}',
      );
    }
    final rates = body['rates'] as Map<String, dynamic>? ?? const {};
    return {
      for (final c in supportedCurrencies)
        if (c != base && rates[c] != null) c: (rates[c] as num).toDouble(),
    };
  }
}
