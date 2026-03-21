import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import 'guest_category_page.dart';
import 'owner_home_page.dart';
import '../state/cart_state.dart';
import '../state/realtime_state.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  static const String ownerPasscode = '1';
  static const int _ownerUnlockTapTarget = 5;
  int _ownerUnlockTapCount = 0;
  bool _isOwnerLoginVisible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RealtimeState>().connect();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ロゴ（上部固定）
          Positioned(
            top: 10,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: _onLogoTapped,
                child: SizedBox(
                  width: 500,
                  height: 400,
                  child: Image.asset(
                    'assets/images/login_logo.png',
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Center(
                      child: Text(
                        'LOGIN LOGO',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ログインUI（中央）
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ElevatedButton(
                  child: const Text('ゲストで入る（席番号）'),
                  onPressed: () => _guestLogin(context),
                ),
                const SizedBox(height: 5),
                if (_isOwnerLoginVisible)
                  ElevatedButton(
                    child: const Text('オーナーで入る（パスコード）'),
                    onPressed: () => _ownerLogin(context),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _onLogoTapped() {
    if (_isOwnerLoginVisible) return;

    _ownerUnlockTapCount++;
    if (_ownerUnlockTapCount < _ownerUnlockTapTarget) return;

    setState(() {
      _isOwnerLoginVisible = true;
      _ownerUnlockTapCount = 0;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('オーナーログインを表示しました')),
    );
  }

  Future<void> _guestLogin(BuildContext context) async {
    final ctrl = TextEditingController();

    final table = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('席番号を入力'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(hintText: '例：C1 / V1 / 12'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('OK'),
          ),
        ],
      ),
    );

    if (table == null || table.isEmpty) return;
    if (!mounted) return;

    context.read<AppState>().loginAsGuest(table);
    context.read<CartState>().clear();

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const GuestCategoryPage()),
    );
  }

  Future<void> _ownerLogin(BuildContext context) async {
    final ctrl = TextEditingController();

    final code = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('パスコード入力'),
        content: TextField(
          controller: ctrl,
          obscureText: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: '****'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('OK'),
          ),
        ],
      ),
    );

    if (code == null) return;
    if (!mounted) return;

    if (code != ownerPasscode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('パスコードが違います')),
      );
      return;
    }

    context.read<AppState>().loginAsOwner();

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const OwnerHomePage()),
    );
  }
}