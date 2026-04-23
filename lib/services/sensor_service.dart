import 'dart:async';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:light_sensor/light_sensor.dart';

class SensorService {
  StreamSubscription? _lightSub;
  StreamSubscription? _accelSub;
  bool isStudyModeActive = false;

  void initStudyMode() {
    // 1. Light Sensor: Detect face-down or pocket (Lux < 5)
    _lightSub = LightSensor.luxStream().listen((int lux) {
      if (lux < 5 && !isStudyModeActive) {
        _activateHapticFeedback();
        isStudyModeActive = true;
        print("Study Mode: Active (Darkness detected)");
      } else if (lux >= 5) {
        isStudyModeActive = false;
      }
    });

    // 2. Accelerometer: Detect if phone is steady (Stationary)
    _accelSub = accelerometerEvents.listen((AccelerometerEvent event) {
      // Logic: minimal movement on X and Y axes
      if (event.x.abs() < 0.2 && event.y.abs() < 0.2) {
        // Phone is stationary on a surface
      }
    });
  }

  void _activateHapticFeedback() {
    // Member 3 Extra Effort: Haptic Engine pattern
    HapticFeedback.heavyImpact();
  }

  void dispose() {
    _lightSub?.cancel();
    _accelSub?.cancel();
  }
}