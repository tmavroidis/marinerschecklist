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

  void onDisconnected() {
    print('MQTT client disconnected');
  }
}
