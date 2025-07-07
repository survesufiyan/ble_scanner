import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'package:ble_device/connectdevice.dart';

class Home extends StatefulWidget {
  const Home({Key? key}) : super(key: key);

  @override
  State<Home> createState() => HomePage();
}

class HomePage extends State<Home> {
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  List<ScanResult> _scanResults = [];
  bool _isScanning = false;

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

  Future<void> _startScanByServiceUuid() async {
    await _checkPermissions();

    final adapterState = await FlutterBluePlus.adapterState.first;
    if (adapterState != BluetoothAdapterState.on) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Bluetooth is not enabled.')));
      return;
    }

    await _scanSubscription?.cancel();
    _scanResults.clear();
    setState(() {
      _isScanning = true;
    });

    _scanSubscription = FlutterBluePlus.onScanResults.listen(
      (results) {
        setState(() {
          _scanResults = results;
        });
      },
      onError: (e) {
        print("Scan error: $e");
      },
    );

    try {
      await FlutterBluePlus.startScan(
        withServices: [Guid('6e400001-b5a3-f393-e0a9-e50e24dcca9e')],
        timeout: const Duration(seconds: 15),
      );
      await FlutterBluePlus.isScanning.where((val) => val == false).first;
    } catch (e) {
      print("Scan failed: $e");
    }
    setState(() {
      _isScanning = false;
    });
  }

  Future<void> _stopScan() async {
    await FlutterBluePlus.stopScan();
    await _scanSubscription?.cancel();
    setState(() {
      _isScanning = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Filter scan results to only those advertising the service UUID
    final filteredResults = _scanResults.where((result) {
      final advertisedUuids = result.advertisementData.serviceUuids
          .map((uuid) => uuid.toString().toLowerCase())
          .toList();
      return advertisedUuids.contains('6e400001-b5a3-f393-e0a9-e50e24dcca9e');
    }).toList();
    return Scaffold(
      appBar: AppBar(title: Text('Home')),
      body: filteredResults.isEmpty
          ? Center(child: Text('No devices found. Tap scan to search.'))
          : ListView.builder(
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
                    child: Text('Connect'),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              ConnectDevice(scanResult: result),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isScanning ? _stopScan : _startScanByServiceUuid,
        label: Text(_isScanning ? 'Stop Scanning' : 'Start Scanning'),
        icon: Icon(_isScanning ? Icons.stop : Icons.bluetooth_searching),
      ),
    );
  }
}
