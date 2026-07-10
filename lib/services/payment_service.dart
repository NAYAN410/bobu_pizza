import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../core/constants.dart';

class PaymentService {
  late Razorpay _razorpay;
  final Function(PaymentSuccessResponse) onPaymentSuccess;
  final Function(PaymentFailureResponse) onPaymentError;
  final Function(ExternalWalletResponse) onExternalWallet;

  PaymentService({
    required this.onPaymentSuccess,
    required this.onPaymentError,
    required this.onExternalWallet,
  }) {
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, onPaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, onPaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, onExternalWallet);
  }

  void openCheckout({
    required double amount,
    required String contact,
    required String email,
    required String description,
  }) {
    var options = {
      'key': dotenv.env['RAZORPAY_KEY_ID'],
      'amount': (amount * 100).toInt(),
      'name': 'Bobu Pizza',
      'description': description,
      'timeout': 300,
      'prefill': {
        'contact': contact,
        'email': email,
        'method': 'upi' // यह UPI को डिफ़ॉल्ट रूप से चुनने की कोशिश करेगा
      },
      'theme': {
        'color': '#C72B1C',
      },
      'retry': {
        'enabled': true,
        'max_count': 1
      },
      'modal': {
        'confirm_close': true,
      }
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      debugPrint('Error in Razorpay open: $e');
    }
  }

  void dispose() {
    _razorpay.clear();
  }
}
