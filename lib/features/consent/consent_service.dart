// lib/features/consent/consent_service.dart
import 'dart:convert';
import 'package:miritalk_app/core/network/api_client.dart';

class ConsentService {
  static final ConsentService instance = ConsentService._();
  ConsentService._();

  Future<bool> isConsentGiven() async {
    try {
      final response = await ApiClient().get('/api/consent');
      if (response.statusCode != 200) return false;
      final json = jsonDecode(response.body);
      return json['consentGiven'] as bool? ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> giveConsent() async {
    try {
      await ApiClient().post('/api/consent');  // body 없이 호출 가능
    } catch (_) {}
  }
}