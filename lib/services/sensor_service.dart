import 'dart:async';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:light_sensor/light_sensor.dart';

class SensorService {
  StreamSubscription? _lightSubscription;
  StreamSubscription? _accelerometerSubscription;

  // Study Mode logic for Member 3
  void initStudyMode() {
    // 1. Detect light levels (Lux < 5 means face-down/in pocket)
    _lightSubscription = LightSensor.luxStream().listen((int lux) {
      if (lux < 5) {
        print("Study Mode: Dark environment detected.");
        // Trigger silence logic here
      }
    });

    // 2. Detect if phone is steady
    _accelerometerSubscription = accelerometerEvents.listen((AccelerometerEvent event) {
      if (event.x.abs() < 0.1 && event.y.abs() < 0.1) {
        // Phone is stationary
      }
    });
  }

  void dispose() {
    _lightSubscription?.cancel();
    _accelerometerSubscription?.cancel();
  }
}