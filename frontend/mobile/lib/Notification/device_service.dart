import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DeviceService {
  DeviceService._();
  static final instance = DeviceService._();

  static const _deviceIdKey = 'ayu_device_id';

  // returns the stable device id, creating one on first run
  Future<String> _getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_deviceIdKey);
    if (id == null) {
      id = DateTime.now().microsecondsSinceEpoch.toString();
      await prefs.setString(_deviceIdKey, id);
    }
    return id;
  }

  // call this right after login
  // requests permission, gets fcm token and saves it to firestore
  Future<void> registerDevice(String uid) async {
    final messaging = FirebaseMessaging.instance;

    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // user denied permission so nothing to register
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      await _saveEnabledState(uid, enabled: false);
      return;
    }

    final token = await messaging.getToken();
    if (token == null) return;

    await _upsertDeviceDoc(uid, token);

    // keep token fresh if firebase rotates it
    messaging.onTokenRefresh.listen((newToken) {
      _upsertDeviceDoc(uid, newToken);
    });
  }

  // call this before signOut
  // removes the device doc and deletes the local token
  Future<void> unregisterDevice(String uid) async {
    final deviceId = await _getDeviceId();
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('devices')
        .doc(deviceId)
        .delete();
    await FirebaseMessaging.instance.deleteToken();
  }

  Future<void> _upsertDeviceDoc(String uid, String token) async {
    final deviceId = await _getDeviceId();
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('devices')
        .doc(deviceId)
        .set({
      'fcmToken': token,
      'platform': Platform.isAndroid ? 'android' : 'ios',
      'lastSeenAt': FieldValue.serverTimestamp(),
      'enabled': true,
    }, SetOptions(merge: true));
  }

  Future<void> _saveEnabledState(String uid, {required bool enabled}) async {
    final deviceId = await _getDeviceId();
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('devices')
        .doc(deviceId)
        .set({'enabled': enabled}, SetOptions(merge: true));
  }
}
