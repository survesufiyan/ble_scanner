import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:async';

class ConnectDevice extends StatefulWidget {
  final ScanResult scanResult;

  ConnectDevice({required this.scanResult});

  @override
  _ConnectDeviceState createState() => _ConnectDeviceState();
}

class _ConnectDeviceState extends State<ConnectDevice> {
  bool _connecting = true;
  String _status = 'Connecting...';
  String _gripValue = '';
  BluetoothConnectionState? _deviceState;
  BluetoothAdapterState? _bleState;
  StreamSubscription<BluetoothConnectionState>? _deviceStateSubscription;
  List<BluetoothService> _services = [];
  BluetoothCharacteristic? notifyCharacteristic;

  @override
  void initState() {
    super.initState();
    _connectToDevice();
    _listenToBleState();
    _listenToDeviceState();
  }

  @override
  void dispose() {
    _deviceStateSubscription?.cancel();
    super.dispose();
  }

  Future<void> _connectToDevice() async {
    try {
      await widget.scanResult.device.connect();
      setState(() {
        _status = 'Connected!';
        _connecting = false;
      });

      List<BluetoothService> services = await widget.scanResult.device
          .discoverServices();
      setState(() {
        _services = services;
      });

      _subscribeToNotifications(); // Setup notification listener
    } catch (e) {
      setState(() {
        _status = "Connection failed: $e";
        _connecting = false;
      });
    }
  }

  void _listenToBleState() {
    FlutterBluePlus.adapterState.listen((state) {
      setState(() {
        _bleState = state;
      });
    });
  }

  void _listenToDeviceState() {
    _deviceStateSubscription = widget.scanResult.device.connectionState.listen((
      state,
    ) {
      setState(() {
        _deviceState = state;
      });
    });
  }

  Future<void> _disconnectDevice() async {
    try {
      await widget.scanResult.device.disconnect();
      setState(() {
        _status = 'Disconnected!';
        _services = [];
        notifyCharacteristic = null;
        _gripValue = '';
      });
    } catch (e) {
      setState(() {
        _status = "Disconnection failed: $e";
      });
    }
  }

  Future<void> _refreshServices() async {
    if (_deviceState == BluetoothConnectionState.connected) {
      try {
        setState(() {
          _status = 'Refreshing services...';
        });
        List<BluetoothService> services = await widget.scanResult.device
            .discoverServices();
        setState(() {
          _services = services;
          _status = 'Services refreshed!';
        });
      } catch (e) {
        setState(() {
          _status = "Refresh failed: $e";
        });
      }
    }
  }

  void _subscribeToNotifications() async {
    for (var service in _services) {
      for (var c in service.characteristics) {
        if (c.properties.notify) {
          await c.setNotifyValue(true);
          c.onValueReceived.listen((value) {
            final parsed = _convertToFloat(Uint8List.fromList(value));
            setState(() {
              _gripValue = parsed.toStringAsFixed(2);
            });
          });
          notifyCharacteristic = c;
          return;
        }
      }
    }
  }

  double _convertToFloat(Uint8List value) {
    if (value.length < 4) return 0.0; // Needs 4 bytes to parse float32
    final byteData = ByteData.sublistView(value);
    return byteData.getFloat32(0, Endian.little);
  }

  Widget _infoText(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        '$label: ${value ?? "Unknown"}',
        style: TextStyle(fontSize: 16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final device = widget.scanResult.device;
    final deviceName = device.name.isNotEmpty
        ? device.name
        : device.remoteId.toString();

    return Scaffold(
      appBar: AppBar(title: Text(deviceName)),
      body: Center(
        child: _connecting
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(_status),
                ],
              )
            : SingleChildScrollView(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _infoText(
                      'BLE State',
                      _bleState?.toString().split('.').last,
                    ),
                    _infoText(
                      'Device State',
                      _deviceState?.toString().split('.').last,
                    ),
                    _infoText('Device Name', deviceName),
                    _infoText('Device UUID', device.remoteId.toString()),
                    SizedBox(height: 8),
                    if (_gripValue.isNotEmpty)
                      Text(
                        'Grip Strength: $_gripValue',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    SizedBox(height: 16),
                    ElevatedButton(
                      onPressed:
                          _deviceState == BluetoothConnectionState.connected
                          ? _disconnectDevice
                          : null,
                      child: Text('Disconnect'),
                    ),
                    SizedBox(height: 16),
                    Text(_status, style: TextStyle(fontSize: 16)),
                    SizedBox(height: 24),
                    if (_services.isNotEmpty)
                      SizedBox(
                        height: 400,
                        child: ListView.builder(
                          shrinkWrap: true,
                          physics: NeverScrollableScrollPhysics(),
                          itemCount: _services.length,
                          itemBuilder: (context, index) {
                            final service = _services[index];
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Service UUID: ${service.uuid}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                ListView.builder(
                                  shrinkWrap: true,
                                  physics: NeverScrollableScrollPhysics(),
                                  itemCount: service.characteristics.length,
                                  itemBuilder: (context, cIndex) {
                                    final c = service.characteristics[cIndex];
                                    return Padding(
                                      padding: const EdgeInsets.only(
                                        left: 16.0,
                                        top: 4,
                                        bottom: 4,
                                      ),
                                      child: Text(
                                        'Characteristic: ${c.uuid}',
                                        style: TextStyle(fontSize: 14),
                                      ),
                                    );
                                  },
                                ),
                                SizedBox(height: 12),
                              ],
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
      ),
      floatingActionButton: _connecting
          ? null
          : FloatingActionButton(
              onPressed: _refreshServices,
              tooltip: 'Refresh Services',
              child: Icon(Icons.refresh),
            ),
    );
  }
}
