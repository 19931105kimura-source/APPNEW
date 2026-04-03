import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '/data/server_config.dart';

class OwnerPrinterSettingsPage extends StatefulWidget {
  const OwnerPrinterSettingsPage({super.key});

  @override
  State<OwnerPrinterSettingsPage> createState() => _OwnerPrinterSettingsPageState();
}

class _OwnerPrinterSettingsPageState extends State<OwnerPrinterSettingsPage> {
  final _kitchenHostCtrl = TextEditingController();
  final _kitchenPortCtrl = TextEditingController(text: '9100');
  final _registerHostCtrl = TextEditingController();
  final _registerPortCtrl = TextEditingController(text: '9100');
  final _receiptHostCtrl = TextEditingController();
  final _receiptPortCtrl = TextEditingController(text: '9100');

  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _kitchenHostCtrl.dispose();
    _kitchenPortCtrl.dispose();
    _registerHostCtrl.dispose();
    _registerPortCtrl.dispose();
    _receiptHostCtrl.dispose();
    _receiptPortCtrl.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _loadPrinterSettings() async {
    final uri = ServerConfig.api('/api/printer-settings');
    final res = await http.get(uri);
    if (res.statusCode != 200) {
      throw Exception('failed to load printer settings');
    }
    return Map<String, dynamic>.from(jsonDecode(res.body));
  }

   Future<void> _savePrinterSettings(Map<String, dynamic> settings) async {
    final uri = ServerConfig.api('/api/printer-settings');
    try {
      final res = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(settings),
      );
      if (res.statusCode != 200) {
        throw Exception(
          'HTTP ${res.statusCode} /api/printer-settings: ${res.body}',
        );
      }
    } catch (e) {
      throw Exception('POST /api/printer-settings failed: $e');
    }
  }

  Future<void> _load() async {
    try {
      final settings = await _loadPrinterSettings();
      _kitchenHostCtrl.text = settings['kitchen']?['host']?.toString() ?? '';
      _kitchenPortCtrl.text = (settings['kitchen']?['port'] ?? 9100).toString();
      _registerHostCtrl.text = settings['register']?['host']?.toString() ?? '';
      _registerPortCtrl.text = (settings['register']?['port'] ?? 9100).toString();
      _receiptHostCtrl.text = settings['receipt']?['host']?.toString() ?? '';
      _receiptPortCtrl.text = (settings['receipt']?['port'] ?? 9100).toString();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('プリンター設定の読込に失敗しました')),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);

    final payload = {
      'kitchen': {
        'host': _kitchenHostCtrl.text.trim(),
        'port': int.tryParse(_kitchenPortCtrl.text.trim()) ?? 9100,
      },
      'register': {
        'host': _registerHostCtrl.text.trim(),
        'port': int.tryParse(_registerPortCtrl.text.trim()) ?? 9100,
      },
      'receipt': {
        'host': _receiptHostCtrl.text.trim(),
        'port': int.tryParse(_receiptPortCtrl.text.trim()) ?? 9100,
      },
    };

    try {
      await _savePrinterSettings(payload);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('プリンター設定を保存しました')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      final detail = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('プリンター設定の保存に失敗しました: $detail')),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Widget _section(
    String label,
    TextEditingController hostCtrl,
    TextEditingController portCtrl,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: hostCtrl,
              decoration: const InputDecoration(labelText: 'IP / Host'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: portCtrl,
              decoration: const InputDecoration(labelText: 'Port'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('プリンターIP設定')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                _section('厨房', _kitchenHostCtrl, _kitchenPortCtrl),
                _section('レジ', _registerHostCtrl, _registerPortCtrl),
                _section('レシート', _receiptHostCtrl, _receiptPortCtrl),
                const SizedBox(height: 12),
                SizedBox(
                  height: 44,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('保存'),
                  ),
                ),
              ],
            ),
    );
  }
}