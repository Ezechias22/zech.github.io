import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:dio/dio.dart';
import '../../config/app_config.dart';

final stripeServiceProvider = Provider<StripeService>((ref) {
  return StripeService();
});

class StripeService {
  final Dio _dio = Dio();

  // Initialiser Stripe
  static Future<void> initialize() async {
    Stripe.publishableKey = AppConfig.stripePublishableKey;
    await Stripe.instance.applySettings();
  }

  // Créer un PaymentIntent
  Future<Map<String, dynamic>?> createPaymentIntent({
    required int amount,
    required String currency,
    String? customerId,
  }) async {
    try {
      final response = await _dio.post(
        '${AppConfig.baseUrl}/payments/create-intent',
        data: {
          'amount': amount,
          'currency': currency,
          'customer_id': customerId,
        },
      );
      
      return response.data;
    } catch (e) {
      print('Erreur création PaymentIntent: $e');
      return null;
    }
  }

  // Confirmer le paiement
  Future<bool> confirmPayment({
    required String clientSecret,
    String? paymentMethodId,
  }) async {
    try {
      await Stripe.instance.confirmPayment(
        paymentIntentClientSecret: clientSecret,
        data: const PaymentMethodParams.card(
          paymentMethodData: PaymentMethodData(),
        ),
      );
      
      return true;
    } catch (e) {
      print('Erreur confirmation paiement: $e');
      return false;
    }
  }

  // Créer une méthode de paiement
  Future<PaymentMethod?> createPaymentMethod() async {
    try {
      return await Stripe.instance.createPaymentMethod(
        params: const PaymentMethodParams.card(
          paymentMethodData: PaymentMethodData(),
        ),
      );
    } catch (e) {
      print('Erreur création méthode paiement: $e');
      return null;
    }
  }

  // Afficher la feuille de paiement
  Future<bool> presentPaymentSheet({
    required String clientSecret,
    String? merchantDisplayName,
  }) async {
    try {
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: merchantDisplayName ?? 'Lovingo',
          style: ThemeMode.system,
        ),
      );
      
      await Stripe.instance.presentPaymentSheet();
      return true;
    } catch (e) {
      print('Erreur présentation PaymentSheet: $e');
      return false;
    }
  }
}
