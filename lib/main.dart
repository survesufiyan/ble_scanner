import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';

void main() {
  runApp(const BleScannerApp());
}

class BleScannerApp extends StatefulWidget {
  const BleScannerApp({Key? key}) : super(key: key);

  @override
  _BleScannerAppState createState() => _BleScannerAppState();
}

Future<void> _checkPermissions() async {
  if (await Permission.bluetoothScan.isDenied ||
      await Permission.bluetoothConnect.isDenied ||
      await Permission.location.isDenied) {
    await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();
  }
}

class _BleScannerAppState extends State<BleScannerApp> {
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  List<ScanResult> _scanResults = [];
  String _deviceDetails = "";
  double? _gripPower;

  Future<void> _startScan() async {
    await _checkPermissions();

    final adapterState = await FlutterBluePlus.adapterState.first;
    if (adapterState != BluetoothAdapterState.on) {
      setState(() {
        _deviceDetails = "Bluetooth is not enabled.";
      });
      return;
    }

    await _scanSubscription?.cancel();
    _scanResults.clear();
    setState(() {});

    _scanSubscription = FlutterBluePlus.onScanResults.listen(
      (results) {
        setState(() {
          _scanResults = results;
        });
      },
      onError: (e) {
        print("Scan error: $e");
        setState(() {
          _deviceDetails = "Scan error: $e";
        });
      },
    );

    try {
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 15));
      await FlutterBluePlus.isScanning.where((val) => val == false).first;
    } catch (e) {
      setState(() {
        _deviceDetails = "Failed to start scan: $e";
      });
    }
  }

  Future<void> _connectToDevice(ScanResult result) async {
    try {
      await result.device.connect(timeout: const Duration(seconds: 5));

      final device = result.device;
      final services = await device.discoverServices();

      for (var service in services) {
        for (var characteristic in service.characteristics) {
          if (characteristic.properties.notify) {
            await characteristic.setNotifyValue(true);
            characteristic.lastValueStream.listen((value) {
              final gripPower = value.isNotEmpty ? value[0].toDouble() : null;
              setState(() {
                _gripPower = gripPower;
              });
            });
          }
        }
      }

      setState(() {
        _deviceDetails = "Connected to: ${device.name} (${device.remoteId})";
      });
    } catch (e) {
      setState(() {
        _deviceDetails = "Connection failed: $e";
        _gripPower = null;
      });
    }
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredResults = _scanResults
        .where(
          (r) =>
              r.device.remoteId.toString().toUpperCase() == "DE:97:8C:D9:BE:7F",
        )
        .toList();

    return MaterialApp(
      title: 'BLE Scanner',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: Scaffold(
        appBar: AppBar(title: const Text('BLE Scanner')),
        body: Column(
          children: [
            if (_gripPower != null)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  'Grip Power: ${_gripPower!.toStringAsFixed(1)}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ),
            if (_deviceDetails.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(_deviceDetails),
              ),
            Expanded(
              child: ListView.builder(
                itemCount: filteredResults.length,
                itemBuilder: (context, index) {
                  final result = filteredResults[index];
                  final name = result.device.name.isNotEmpty
                      ? result.device.name
                      : result.device.remoteId.toString();
                  return ListTile(
                    title: Text(name),
                    subtitle: Text('RSSI: ${result.rssi}'),
                    trailing: ElevatedButton(
                      child: const Text('Connect'),
                      onPressed: () => _connectToDevice(result),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _startScan,
          tooltip: 'Start Scan',
          child: const Icon(Icons.search),
        ),
      ),
    );
  }
}
