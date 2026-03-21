import 'dart:async';

import 'package:flutter/material.dart';
import '../services/websocket_service.dart';
import 'order_state.dart';

class RealtimeState extends ChangeNotifier with WidgetsBindingObserver {
  final OrderState orderState;
  final WebSocketService _ws = WebSocketService();

  bool _connected = false;
  bool _connecting = false;
  Timer? _reconnectTimer;

  RealtimeState(this.orderState) {
    WidgetsBinding.instance.addObserver(this);
  }

  Map<String, dynamic> _snapshot = {};
  DateTime? _lastSnapshotAt;

  Map<String, dynamic> get snapshot => _snapshot;
  DateTime? get lastSnapshotAt => _lastSnapshotAt;
  bool get connected => _connected;

  Map<String, dynamic> tables = {};
  Map<String, dynamic> ordersByTable = {};
  Map<String, dynamic> orderItems = {};

  void applySnapshot(Map<String, dynamic> payload) {
    debugPrint('SNAPSHOT RECEIVED');
    _snapshot = payload;
    _lastSnapshotAt = DateTime.now();

    tables = Map<String, dynamic>.from(payload['tables'] ?? {});
    ordersByTable = Map<String, dynamic>.from(payload['ordersByTable'] ?? {});
    orderItems = Map<String, dynamic>.from(payload['orderItems'] ?? {});

    orderState.applyRealtimeSnapshot(payload);
    notifyListeners();
  }

  void connect() {
    if (_connecting) return;
    _connecting = true;

    _ws.connect(
      (payload) {
        _connected = true;
        applySnapshot(payload);
      },
      onConnected: () {
        _connected = true;
        _connecting = false;
        notifyListeners();
      },
      onDisconnected: () {
        _connected = false;
        _connecting = false;
        orderState.markNeedsResync();
        _scheduleReconnect();
        notifyListeners();
      },
    );
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 2), connect);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      orderState.markNeedsResync();
      connect();
      return;
    }

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      orderState.markNeedsResync();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _reconnectTimer?.cancel();
    _ws.dispose();
    super.dispose();
  }
}