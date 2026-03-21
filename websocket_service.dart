import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../data/server_config.dart';

class WebSocketService {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;

  void connect(
    void Function(Map<String, dynamic>) onSnapshot, {
    void Function()? onConnected,
    void Function()? onDisconnected,
  }) {
    dispose();

    _channel = WebSocketChannel.connect(
      Uri.parse(ServerConfig.wsBaseUrl()),
    );

    onConnected?.call();

    _subscription = _channel!.stream.listen(
      (data) {
        final decoded = jsonDecode(data);
        if (decoded is Map && decoded['type'] == 'snapshot') {
          onSnapshot(Map<String, dynamic>.from(decoded['payload'] ?? {}));
        }
      },
      onDone: () => onDisconnected?.call(),
      onError: (_) => onDisconnected?.call(),
      cancelOnError: true,
    );
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    _channel?.sink.close();
    _channel = null;
  }
}