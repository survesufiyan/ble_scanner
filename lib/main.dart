import 'package:flutter/material.dart';
import 'package:ble_device/homepage.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Blue Plus Example',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: Home(),
    );
  }
}
