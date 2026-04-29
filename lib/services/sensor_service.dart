import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:sound_mode/sound_mode.dart';
import 'package:sound_mode/utils/ringer_mode_statuses.dart';
import 'package:sound_mode/permission_handler.dart';

class SensorService with ChangeNotifier {
  StreamSubscription? _accelSub;
  bool isStudyModeActive = false;

  void initStudyMode() async {
    // 1. Check for DND access without blocking initialization
    bool? isGranted = await PermissionHandler.permissionsGranted;

    if (isGranted != true) {
      debugPrint("⚠️ SensorService: DND Permission missing. Skipping Hardware Mute.");
      return;
    }

    // 2. Start the Hardware Listener
    _accelSub = accelerometerEventStream().listen((AccelerometerEvent event) async {
      // Detection: Face-down (Z < -8.5) and flat (X/Y near 0)
      bool faceDown = event.z < -8.5;
      bool stationary = event.x.abs() < 1.0 && event.y.abs() < 1.0;
      bool newState = faceDown && stationary;

      if (newState != isStudyModeActive) {
        isStudyModeActive = newState;
        notifyListeners();

        try {
          if (isStudyModeActive) {
            await SoundMode.setSoundMode(RingerModeStatus.silent);
            HapticFeedback.heavyImpact();
            debugPrint("UniPath: Hardware Lock Active");
          } else {
            await SoundMode.setSoundMode(RingerModeStatus.normal);
            debugPrint("UniPath: Hardware Lock Released");
          }
        } catch (e) {
          debugPrint("Hardware Permission Error: $e");
        }
      }
    }, onError: (error) => debugPrint("Sensor Error: $error"));
  }

  @override
  void dispose() {
    _accelSub?.cancel();
    // Try to restore sound mode on dispose if active
    SoundMode.setSoundMode(RingerModeStatus.normal);
    super.dispose();
  }
}