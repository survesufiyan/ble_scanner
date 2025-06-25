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
  StreamSubscription<BluetoothAdapterState>? _adapterStateSubscription;
  List<ScanResult> _scanResults = [];
  String _deviceDetails = "";
  double? _gripPower; // Variable to hold grip power value

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
    setState(() {}); // Refresh UI

    _scanSubscription = FlutterBluePlus.onScanResults.listen(
      (results) async {
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
      await FlutterBluePlus.startScan(timeout: Duration(seconds: 15));
      await FlutterBluePlus.isScanning.where((val) => val == false).first;
    } catch (e) {
      print("Failed to start scan: $e");
      setState(() {
        _deviceDetails = "Failed to start scan: $e";
      });
    }
  }

  Future<void> _connectToDevice(ScanResult result) async {
    try {
      await result.device.connect(timeout: Duration(seconds: 10));
      final adv = result.advertisementData;
      final manufacturerDetails = adv.manufacturerData.entries
          .map((e) {
            String dateString = '';
            if (e.value.length >= 4) {
              final timestamp =
                  (e.value[0] << 24) |
                  (e.value[1] << 16) |
                  (e.value[2] << 8) |
                  (e.value[3]);
              final date = DateTime.fromMillisecondsSinceEpoch(
                timestamp * 1000,
                isUtc: true,
              );
              dateString =
                  ' (Manufacturer Details: ${date.toLocal().toString().split(' ').first})';
            }
            return '${e.key}: ${e.value}$dateString';
          })
          .join(', ');
      String details =
          'Connected to: ${result.device.name.isNotEmpty ? result.device.name : result.device.remoteId}\n'
          'Manufacturer Details: $manufacturerDetails\n'
          'RSSI: ${result.rssi}\n\n'
          'Services discovered:\n';

      final device = result.device;
      List<BluetoothService> services = await device.discoverServices();
      for (var service in services) {
        details += 'Service: ${service.uuid}\n';
        if (service.characteristics.isEmpty) {
          details += '  No characteristics\n';
        } else {
          for (var characteristic in service.characteristics) {
            details += '  Characteristic: ${characteristic.uuid}\n';
            details +=
                '    Properties: '
                '${characteristic.properties.read ? "read " : ""}'
                '${characteristic.properties.write ? "write " : ""}'
                '${characteristic.properties.notify ? "notify " : ""}\n';
          }
        }
        details += '\n';
      }

      setState(() {
        _deviceDetails = details;
        _gripPower = null; // Reset grip power on new connection
      });

      // Listen for grip power notifications, ignore the first value
      for (var service in services) {
        for (var characteristic in service.characteristics) {
          if (characteristic.properties.notify) {
            await characteristic.setNotifyValue(true);
            bool isFirst = true;
            characteristic.lastValueStream.listen((value) {
              if (isFirst) {
                isFirst = false;
                return; // Ignore the first value (likely stale)
              }
              final gripPower = value.isNotEmpty ? value[0] : null;
              // Only update if gripPower is not null and > 0
              if (gripPower != null && gripPower > 0) {
                setState(() {
                  _gripPower = gripPower.toDouble();
                });
              }
            });
          }
        }
      }
    } catch (e) {
      setState(() {
        _deviceDetails = "Connection failed: $e";
        _gripPower = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  'Grip Power: $_gripPower',
                  style: TextStyle(
                    fontSize: 20,
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
                itemCount: _scanResults.length,
                itemBuilder: (context, index) {
                  final result = _scanResults[index];
                  final name = result.device.name.isNotEmpty
                      ? result.device.name
                      : result.device.remoteId.toString();
                  return ListTile(
                    title: Text(name),
                    subtitle: Text('RSSI: ${result.rssi}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (result
                            .advertisementData
                            .manufacturerData
                            .isNotEmpty)
                          Text(
                            'Manufacturer: ${result.advertisementData.manufacturerData.keys.join(", ")}',
                          ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          child: Text('Connect'),
                          onPressed: () => _connectToDevice(result),
                        ),
                      ],
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
