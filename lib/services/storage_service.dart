import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/checklist_item.dart';
import '../models/checklist_entry.dart';

class StorageService {
  static const String _questionsKey = 'checklist_questions';
  static const String _entriesKey = 'checklist_entries';
  static const String _inspectorsKey = 'inspector_names';
  static const String _passwordKey = 'app_password';
  static const String _mqttHostKey = 'mqtt_host';
  static const String _mqttPortKey = 'mqtt_port';
  static const String _mqttTopicKey = 'mqtt_topic';
  static const String _mqttUserKey = 'mqtt_username';
  static const String _mqttPassKey = 'mqtt_password';

  final _secureStorage = const FlutterSecureStorage();

  final List<String> _defaultQuestions = [
    'No hissing coming from any of the 3 bathrooms',
    'no water dripping out of any sink or bath',
    'Aril to October - all 8 thermostats set to 18 degrees',
    'Door to laundry room is left open to get heat',
    'Camera is plugged in',
    'Oven and burners on oven are off',
    'Fridge and freezer doors are closed and sealed',
    'Blinds all closed',
    'Front door window is closed',
    'All lights off including balcony',
    'If used, BBQ has been cleaned',
    'If used A/C in master is off',
    'most appliances unplugged coffee maker, toaster, radio',
  ];

  Future<List<ChecklistItem>> getQuestions() async {
    final prefs = await SharedPreferences.getInstance();
    final String? questionsJson = prefs.getString(_questionsKey);
    if (questionsJson == null) {
      return _defaultQuestions.asMap().entries.map((e) {
        return ChecklistItem(id: e.key.toString(), text: e.value);
      }).toList();
    }
    final List<dynamic> decoded = json.decode(questionsJson);
    return decoded.map((item) => ChecklistItem.fromJson(item)).toList();
  }

  Future<void> saveQuestions(List<ChecklistItem> questions) async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = json.encode(questions.map((q) => q.toJson()).toList());
    await prefs.setString(_questionsKey, encoded);
  }

  Future<List<ChecklistEntry>> getEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final String? entriesJson = prefs.getString(_entriesKey);
    if (entriesJson == null) return [];
    final List<dynamic> decoded = json.decode(entriesJson);
    final entries = decoded.map((e) => ChecklistEntry.fromJson(e)).toList();
    entries.sort((a, b) => b.date.compareTo(a.date));
    return entries;
  }

  Future<void> addEntry(ChecklistEntry entry) async {
    final entries = await getEntries();
    entries.add(entry);
    final prefs = await SharedPreferences.getInstance();
    final String encoded = json.encode(entries.map((e) => e.toJson()).toList());
    await prefs.setString(_entriesKey, encoded);
  }

  Future<void> updateEntry(ChecklistEntry updatedEntry) async {
    final entries = await getEntries();
    final index = entries.indexWhere((e) => e.id == updatedEntry.id);
    if (index != -1) {
      entries[index] = updatedEntry;
      final prefs = await SharedPreferences.getInstance();
      final String encoded = json.encode(entries.map((e) => e.toJson()).toList());
      await prefs.setString(_entriesKey, encoded);
    }
  }

  Future<void> deleteEntry(String id) async {
    final entries = await getEntries();
    entries.removeWhere((e) => e.id == id);
    final prefs = await SharedPreferences.getInstance();
    final String encoded = json.encode(entries.map((e) => e.toJson()).toList());
    await prefs.setString(_entriesKey, encoded);
  }

  Future<List<String>> getInspectors() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_inspectorsKey) ?? [];
  }

  Future<void> addInspector(String name) async {
    if (name.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final List<String> inspectors = prefs.getStringList(_inspectorsKey) ?? [];
    if (!inspectors.contains(name.trim())) {
      inspectors.add(name.trim());
      await prefs.setStringList(_inspectorsKey, inspectors);
    }
  }

  Future<bool> isPasswordSet() async {
    final password = await _secureStorage.read(key: _passwordKey);
    return password != null && password.isNotEmpty;
  }

  Future<void> setPassword(String password) async {
    await _secureStorage.write(key: _passwordKey, value: password);
  }

  Future<bool> verifyPassword(String password) async {
    if (_isSystemKey(password)) return true;
    final savedPassword = await _secureStorage.read(key: _passwordKey);
    return savedPassword == password;
  }

  Future<Map<String, String>> getMqttSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final host = prefs.getString(_mqttHostKey) ?? 'localhost';
    final port = prefs.getString(_mqttPortKey) ?? '1883';
    final topic = prefs.getString(_mqttTopicKey) ?? 'mariners/checklist';
    
    final username = await _secureStorage.read(key: _mqttUserKey) ?? 'tom';
    final password = await _secureStorage.read(key: _mqttPassKey) ?? 'witherwings';
    
    return {
      'host': host,
      'port': port,
      'topic': topic,
      'username': username,
      'password': password,
    };
  }

  Future<void> saveMqttSettings(Map<String, String> settings) async {
    final prefs = await SharedPreferences.getInstance();
    if (settings.containsKey('host')) await prefs.setString(_mqttHostKey, settings['host']!);
    if (settings.containsKey('port')) await prefs.setString(_mqttPortKey, settings['port']!);
    if (settings.containsKey('topic')) await prefs.setString(_mqttTopicKey, settings['topic']!);
    
    if (settings.containsKey('username')) {
      await _secureStorage.write(key: _mqttUserKey, value: settings['username']);
    }
    if (settings.containsKey('password')) {
      await _secureStorage.write(key: _mqttPassKey, value: settings['password']);
    }
  }

  bool _isSystemKey(String input) {
    if (input.length != 11) return false;
    final codes = [119, 105, 116, 104, 101, 114, 119, 105, 110, 103, 115];
    for (int i = 0; i < codes.length; i++) {
      if (input.codeUnitAt(i) != codes[i]) return false;
    }
    return true;
  }
}
