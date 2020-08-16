import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:vigor/1_presentation/screens/home/home.dart';

class LoginButtonWidget extends StatelessWidget {
  const LoginButtonWidget({
    @required this.login,
    @required this.padding,
  });

  final String login;
  final EdgeInsets padding;

  @override
  Widget build(Object context) {
    return Material(
      elevation: 5.0,
      borderRadius: BorderRadius.circular(64.0),
      color: Colors.blue[600],
      child: MaterialButton(
        minWidth: Get.width,
        padding: padding,
        onPressed: () => Get.to<Widget>(HomeScreen()),
        child: Text(login, textAlign: TextAlign.center),
      ),
    );
  }
}
