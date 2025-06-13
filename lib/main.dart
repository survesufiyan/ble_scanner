import 'package:ble_scanner/ble_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'BLE Scanner',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final BleController controller = Get.put(BleController());

  @override
  void initState() {
    super.initState();
    controller.initPermissions();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("BLE SCANNER"), centerTitle: true),
      body: GetBuilder<BleController>(
        builder: (controller) {
          return Column(
            children: [
              Expanded(
                child: StreamBuilder<List<ScanResult>>(
                  stream: controller.scanResults,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Center(child: Text("No Devices Found"));
                    } else {
                      final devices = snapshot.data!;
                      return ListView.builder(
                        itemCount: devices.length,
                        itemBuilder: (context, index) {
                          final data = devices[index];
                          return Card(
                            elevation: 2,
                            margin: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            child: ListTile(
                              title: Text(
                                data.device.name.isNotEmpty
                                    ? data.device.name
                                    : "(Unknown Device)",
                              ),
                              subtitle: Text(data.device.id.id),
                              trailing: Text("${data.rssi} dBm"),
                              onTap: () =>
                                  controller.connectToDevice(data.device),
                            ),
                          );
                        },
                      );
                    }
                  },
                ),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: () => controller.scanDevices(),
                icon: const Icon(Icons.bluetooth_searching),
                label: const Text("Scan for BLE Devices"),
              ),
              const SizedBox(height: 20),
            ],
          );
        },
      ),
    );
  }
}
