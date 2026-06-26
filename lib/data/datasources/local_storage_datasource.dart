import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';

import '../../config/app_constants.dart';
import '../models/contact_model.dart';
import '../models/profile_model.dart';

class LocalStorageDatasource {
  late Box<String> _box;

  Future<void> init() async {
    _box = await Hive.openBox<String>('colow_box');
  }

  // Onboarding
  Future<bool> getOnboarded() async {
    return _box.get(AppConstants.onboardedKey) == '1';
  }

  Future<void> setOnboarded(bool value) async {
    await _box.put(AppConstants.onboardedKey, value ? '1' : '0');
  }

  // Profile
  Future<ProfileModel?> getProfile() async {
    final raw = _box.get(AppConstants.profileKey);
    if (raw == null) return null;
    try {
      return ProfileModel.fromJson(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  Future<void> saveProfile(ProfileModel profile) async {
    await _box.put(AppConstants.profileKey, jsonEncode(profile.toJson()));
  }

  Future<void> clearProfile() async {
    await _box.delete(AppConstants.profileKey);
  }

  // Contacts
  Future<List<ContactModel>> getContacts() async {
    final raw = _box.get(AppConstants.contactsKey);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.map((e) => ContactModel.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveContacts(List<ContactModel> contacts) async {
    await _box.put(
      AppConstants.contactsKey,
      jsonEncode(contacts.map((e) => e.toJson()).toList()),
    );
  }

  // Code word
  Future<String?> getCodeWord() async {
    return _box.get(AppConstants.codeWordKey);
  }

  Future<void> saveCodeWord(String value) async {
    await _box.put(AppConstants.codeWordKey, value);
  }
  // Device ID
  Future<String?> getDeviceId() async {
    return _box.get(AppConstants.deviceKey);
  }

  Future<void> saveDeviceId(String value) async {
    await _box.put(AppConstants.deviceKey, value);
  }
}
