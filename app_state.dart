
import 'package:flutter/material.dart';

enum UserMode { owner, guest }

class AppState extends ChangeNotifier {
  UserMode mode = UserMode.guest;

  /// ゲストが入力した席番号（例：A / VIP1 / T12）
  String? guestTable;

  void loginAsOwner() {
    mode = UserMode.owner;
    guestTable = null; // 念のためクリア
    notifyListeners();
  }

  void loginAsGuest(String table) {
    mode = UserMode.guest;
    guestTable = table.trim();
    guestTable = table; // ←保存
    notifyListeners();
  }

  void logout() {
    mode = UserMode.guest;
    guestTable = null;
    notifyListeners();
  }
}
