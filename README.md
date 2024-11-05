## VietQR library for Flutter. 

The library lets Flutter developer integrate VietQR to their Android, iOS and macOS apps. Developed by Patcell Corp.

## Getting started

To be added later, after this package is published to https://pub.dev

## Usage

**1. Important: You'll need to contact VietQR to obtain the clientID and secretKey, as well as register webhooks.**
**2. Add this library to your pubspec.yaml file.**

**3. Initialize the VietQR object in the *main* function before runApp**
```dart
void main() {
    VietQR.initialize(clientID, bankCode, bankAccount, webhook);
    runApp(MyApp())
}
```
**4. Use the VietQR instance to invoke the capabilities**

***4.1. The convenient VietQRButton***

This is the most convenient way to take advantage of the library.
```dart
class CheckoutScreen extends StatefulWidget {
    @override State<CheckoutScreen> createState => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {

    late TextEditingController _contentController;
    late TextEditingController _amountController;
    late TextEditingController _orderIdController;

    @override
        void initState() {
        super.initState();
        _contentController = TextEditingController(text: 'Transaction note');
        _amountController = TextEditingController(text: '1000');
        _orderIdController = TextEditingController(text: 'Order #30');
    }

    @override
    Widget build(BuildContext context) {
        return Column(
            children: [
                TextField(controller: _contentController),
                TextField(controller: _amountController),
                TextField(controller: _orderIdController),
                VietQRButton(
                    content: _contentController.text,
                    amount: int.parse(_amountController.text),
                    orderId: _orderIdController.text,
                    conditionalHook: () => Future.value(true),
                    callback: (VietQRGeneratingResponse response) => print(response.status)
                ),
            ],
        );
    }
}
```
The **conditionalHook** is handy if you need to execute some code before the VietQR sheet appears. For example, you can send the orderId to your server so it can prepare to listen to order status sent by VietQR server via webhook. It returns a `Future<bool>`. If the `bool` is true,
the VietQR sheet will show up. If the `bool` is false, the VietQR sheet will not be shown.

***4.2. The `showQRSheet` function***

If you want to have more control of how and when the VietQR dialog shows up, you can directly invoke the this function when there are more complex logical conditions required.

```dart
    if (everythingIsReady) {
        VietQR.instance.showQRSheet(context, content, amount, orderId, webhook).then((VietQRGeneratingResponse res) => print(res.status));
    } else {
        print('We are not gonna show the VietQR sheet.');
    }
```

***4.3. The `fetchQR` function***

This is the core function of the library and helpful in case you want to control every piece of code. For example, a custom UI.

```dart
    void _fetchQR(String content, int amount, String orderId) async {
        final VietQRGeneratingResponse response = await VietQR.instance.fetchQR(content: content, amount: amount, orderId: orderId);
        if (response.status == VietQRGeneratingResponseStatus.success) {
            final base64Image = response.successBody!.qrCode;
        } else {
            print('Something went wrong. ${response.failureBody!.message}');
        }
    }
```