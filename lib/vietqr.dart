library vietqr;

import 'dart:convert';
import 'dart:math';

import 'package:easy_file_saver/easy_file_saver.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';

/// VietQR instance. This is the main entry point of the library.
/// Make sure you always initialize the VietQR instance before invoking anything else.
/// ```
/// void main() {
///   VietQR.initialize(clientID, secretKey, bankCode, bankName, bankAccount, userBankName, webhook);
///   runApp(myApp());
/// }
/// ```
final class VietQR {

  static VietQR? _instance;

  static VietQR get instance {
    if (_instance == null) {
      throw Exception('VietQR instance has not been initialized. Make sure you call VietQr.initialize(clientID, secretKey, webhook?) in main function before runApp.');
    } else {
      return _instance!;
    }
  }

  VietQR._(this.clientID, this.secretKey, this.bankCode, this.bankName, this.bankAccount, this.userBankName, this.webhook);

  final String clientID;
  final String secretKey;
  final String bankCode;
  final String bankName;
  final String bankAccount;
  final String userBankName;
  final String? webhook;

  static void initialize(String clientID, String secretKey, String bankCode, String bankName, String bankAccount, String userBankName, [String? webhook]) {
    if (_instance == null) {
      _instance = VietQR._(clientID, secretKey, bankCode, bankName, bankAccount, userBankName, webhook);
    } else {
      throw Exception('VietQR instance has already been initialized with a clientID and secretKey.');
    }
  }

  static final Uri _kVietQrUrl = Uri.https('dev.vietqr.org','/vqr/qr-lib/active/request');

  // Fetch QR image for every transaction. This is handy when you only need to fetch the QR. For example, you build your own custom UI.
  Future<VietQRGeneratingResponse> fetchQR({
    required String content,
    required int amount,
    required String orderId,
    String? webhook
  }) async {
    if (webhook == null && this.webhook == null) {
      throw Exception('A webhook must be supplied. Either from VietQR.initialize(clientID, webhook) or fetchQR(content, amount, orderId, webhook?)');
    }
    final response = await http.post(
      _kVietQrUrl,
      headers: {
        'Content-Type': 'application/json',
        'clientId': clientID,
        'secretKey': secretKey,
      },
      body: {
        'bankCode': bankCode,
        'bankAccount': bankAccount,
        'content': content,
        'qrType': 0,
        'amount': amount,
        'orderId': orderId,
        'webhook': webhook ?? this.webhook,
      }
    );
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200) {
      final successBody = VietQRGeneratingSuccessResponseBody._(
        bankCode: json['bankCode'] as String,
        bankName: json['bankName'] as String,
        bankAccount: json['bankAccount'] as String,
        userBankName: json['userBankName'] as String,
        amount: json['amount'] as String,
        content: json['content'] as String,
        orderId: json['orderId'] as String,
        qrCode: json['qrCode'] as String,
      );
      return VietQRGeneratingResponse._(status: VietQRGeneratingResponseStatus.success, successBody: successBody);
    } else {
      final failureBody = VietQRGeneratingFailureResponseBody._(json['message']);
      return VietQRGeneratingResponse._(status: VietQRGeneratingResponseStatus.failure, failureBody: failureBody);
    }
  }

  Future<VietQRGeneratingResponse?> showQRSheet(BuildContext context, String content, int amount, String orderId, [ String? webhook ]) {
    return Navigator.of(context, rootNavigator: false).push<VietQRGeneratingResponse>(
      PageRouteBuilder(
        pageBuilder: (BuildContext context, Animation<double> animation, Animation<double> secondAnimation) {
        final size = MediaQuery.of(context).size;
        return SlideTransition(
          position: Tween(begin: const Offset(0.0, 1.0), end: const Offset(0.0, 0.0)).animate(animation),
          child: Align(
            alignment: size.width < 600 ? Alignment.bottomCenter : Alignment.center,
            child: Material(
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.all(20),
                height: size.width < 600 ? size.height - 120 : 600,
                width: min(size.width, 600),
                child: FutureBuilder(
                  future: fetchQR(
                    content: content,
                    amount: amount,
                    orderId: orderId,
                    webhook: webhook ?? this.webhook
                  ),
                  builder: (BuildContext context, AsyncSnapshot<VietQRGeneratingResponse> snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: SizedBox(height: 200, width: 200, child: CircularProgressIndicator()));
                    } else if (snapshot.hasData && snapshot.data!.successBody != null) {
                      final navigator = Navigator.of(context);
                      return Column(
                        children: [
                          SizedBox(
                            height: 360,
                            width: 360,
                            child: Image.memory(base64Decode(snapshot.data!.successBody!.qrCode))
                          ),
                          Expanded(child: Container(),),
                          Row(
                            children: [
                              Expanded(child: FilledButton(onPressed: () async {
                                final saveResult = await EasyFileSaver().saveImageToGalleryFromBase64(snapshot.data!.successBody!.qrCode, orderId);
                                if (saveResult == 'OK') {
                                  navigator.pop(snapshot.data!.successBody);
                                } else {
                                  print('Cannot save the image to Device ${defaultTargetPlatform == TargetPlatform.android ? 'Gallery' : 'Photos'}');
                                }
                              }, child: const Text('Lưu'),),),
                              const SizedBox(width: 40,),
                              Expanded(child: OutlinedButton(onPressed: () => navigator.pop(), child: const Text('Hủy'),),),
                            ],
                          ),
                        ]
                      );
                    } else {
                      return Text(snapshot.data!.failureBody!.message);
                    }
                  }
                )
              ),
            )
          )
        );
      },
      opaque: false,
      barrierColor: Colors.black.withOpacity(0.25),
      barrierDismissible: false,
    ));
  }
}


/// A handy VietQRButton which offers everything you need in a simple widget.
final class VietQRButton extends StatelessWidget {

  const VietQRButton({
    super.key,
    required this.content,
    required this.amount,
    required this.orderId,
    required this.webhook,
    required this.conditionalHook,
    required this.callback
  });

  final int amount;
  final String content;
  final String orderId;
  final String? webhook;

  // The conditionalHook which decides whether the QR sheet/dialog is shown.
  // It's handy for things that need to be done before the QR is fetched and displayed.
  // For example, you'll need to send the [orderId] to your server.
  final Future<bool> Function() conditionalHook;

  // The callback to be fired. If the [condition] above returns false, the QR sheet/dialog won't be shown.
  // And the VietQRGeneratingResponse param in the callback will be null.
  // See [VietQRGeneratingResponse] below for more info.
  final Function(VietQRGeneratingResponse?) callback;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      child: const Text('Thanh toán qua VietQR'),
      onPressed: () {
        conditionalHook().then((bool res) async {
          if (res && context.mounted) {
            final res = await VietQR.instance.showQRSheet(context, content, amount, orderId, webhook);
            callback(res);
          } else {
            callback(null);
          }
        });
      }
    );
  }
}

final class VietQRGeneratingResponse {

  VietQRGeneratingResponse._({required this.status, this.successBody, this.failureBody});

  final VietQRGeneratingResponseStatus status;
  final VietQRGeneratingSuccessResponseBody? successBody;
  final VietQRGeneratingFailureResponseBody? failureBody;

}

enum VietQRGeneratingResponseStatus {
  success, failure, userCancelled, conditionFailed,
}

final class VietQRGeneratingSuccessResponseBody {

  VietQRGeneratingSuccessResponseBody._({
    required this.bankCode,
    required this.bankName,
    required this.bankAccount,
    required this.userBankName,
    required this.amount,
    required this.content,
    required this.orderId,
    required this.qrCode,
  });

  final String bankCode;
  final String bankName;
  final String bankAccount;
  final String userBankName;
  final String amount;
  final String content;
  final String orderId;
  final String qrCode;

}

final class VietQRGeneratingFailureResponseBody {
  VietQRGeneratingFailureResponseBody._(this.errorCode);

  final String errorCode;
  
  String get message => errorMessages[errorCode] ?? 'Lỗi không xác định.';

  static const Map<String,String> errorMessages = {
    'E550':	'clientId không hợp lệ.',
    'E551':	'Giá trị checkSum không hợp lệ.',
    'E552':	'TKNH không khớp với clientId. (TKNH không trực thuộc Tài khoản VietQR của App Developer).',
    'E553':	'bankCode không hợp lệ. Xem https://api.vietqr.vn/vi/danh-sach-ma-ngan-hang',
    'E555':	'secretKey không hợp lệ.',
    'E556':	'Số TKNH, số tiền hoặc nội dung thanh toán không hợp lệ.',
    'E557':	'Request Body không hợp lệ.',
    'E558':	'qrType không hợp lệ.',
    'E05':	'Lỗi không xác định.',
  };
}