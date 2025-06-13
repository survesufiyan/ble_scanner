import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';

class BleController extends GetxController {
  FlutterBluePlus ble = FlutterBluePlus();

  Future<void> initPermissions() async {
    await [
      Permission.locationWhenInUse,
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
    ].request();
  }

  Future<void> scanDevices() async {
    bool scanGranted = await Permission.bluetoothScan.isGranted;
    bool connectGranted = await Permission.bluetoothConnect.isGranted;

    if (scanGranted && connectGranted) {
      FlutterBluePlus.startScan(timeout: const Duration(seconds: 15));
    } else {
      Get.snackbar("Permission Denied", "Bluetooth permissions not granted.");
    }
  }

  Future<void> connectToDevice(BluetoothDevice device) async {
    try {
      await device.connect(timeout: const Duration(seconds: 10));
      device.state.listen((state) {
        if (state == BluetoothDeviceState.connected) {
          Get.snackbar("Connected", "Connected to ${device.name}");
        } else if (state == BluetoothDeviceState.disconnected) {
          Get.snackbar("Disconnected", "${device.name} disconnected");
        }
      });
    } catch (e) {
      Get.snackbar("Connection Error", e.toString());
    }
  }

  Stream<List<ScanResult>> get scanResults => FlutterBluePlus.scanResults;

  @override
  void onClose() {
    FlutterBluePlus.stopScan();
    super.onClose();
  }
}
