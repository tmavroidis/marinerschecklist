import 'dart:convert';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import '../models/checklist_entry.dart';
import 'storage_service.dart';

class MqttService {
  final _storage = StorageService();
  MqttServerClient? client;

  Future<void> publishEntry(ChecklistEntry entry) async {
    final settings = await _storage.getMqttSettings();
    if (settings['enabled'] != 'true') return;

    final server = settings['host']!;
    final port = int.tryParse(settings['port']!) ?? 1883;
    final topic = settings['topic']!;
    final username = settings['username']!;
    final password = settings['password']!;

    client = MqttServerClient.withPort(server, 'mariners_app_client', port);
    client!.logging(on: false);
    client!.onDisconnected = onDisconnected;

    final connMessage = MqttConnectMessage()
        .withClientIdentifier('mariners_app_client')
        .authenticateAs(username, password)
        .startClean()
        .withWillQos(MqttQos.atLeastOnce);
    client!.connectionMessage = connMessage;

    try {
      await client!.connect();
    } catch (e) {
      print('MQTT client connection exception - $e');
      client!.disconnect();
      return;
    }

    if (client!.connectionStatus!.state == MqttConnectionState.connected) {
      final builder = MqttClientPayloadBuilder();
      builder.addString(json.encode(entry.toJson()));
      client!.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
      
      // Give it a moment to publish before disconnecting
      await Future.delayed(const Duration(milliseconds: 500));
      client!.disconnect();
    } else {
      print('MQTT client connection failed - status is ${client!.connectionStatus}');
      client!.disconnect();
    }
  }

  Future<bool> testConnection({
    required String host,
    required String port,
    required String username,
    required String password,
  }) async {
    final intPort = int.tryParse(port) ?? 1883;
    final testClient = MqttServerClient.withPort(host, 'mariners_test_client', intPort);
    testClient.logging(on: false);

    final connMessage = MqttConnectMessage()
        .withClientIdentifier('mariners_test_client')
        .authenticateAs(username, password)
        .startClean();
    testClient.connectionMessage = connMessage;

    try {
      await testClient.connect().timeout(const Duration(seconds: 5));
      if (testClient.connectionStatus!.state == MqttConnectionState.connected) {
        testClient.disconnect();
        return true;
      }
    } catch (e) {
      print('MQTT Test connection failed: $e');
    }
    testClient.disconnect();
    return false;
  }

  void onDisconnected() {
    print('MQTT client disconnected');
  }
}
