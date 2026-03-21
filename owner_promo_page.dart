import 'dart:io';
import 'package:video_player/video_player.dart';
import '../data/server_config.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../data/menu_data.dart';

import '../state/app_state.dart';
import '../state/promo_state.dart';
import 'login_page.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class OwnerPromoPage extends StatefulWidget {
  const OwnerPromoPage({super.key});

  @override
  State<OwnerPromoPage> createState() => _OwnerPromoPageState();
}

class _OwnerPromoPageState extends State<OwnerPromoPage>
    with SingleTickerProviderStateMixin {

  late TabController _tabController;
  bool _busy = false;
  @override
void initState() {
  super.initState();
  _tabController = TabController(length: 2, vsync: this);
}

@override
void dispose() {
  _tabController.dispose();
  super.dispose();
}

  @override
  Widget build(BuildContext context) {
    final isOwner = context.watch<AppState>().mode == UserMode.owner;

    // 🔒 侵入防止
    if (!isOwner) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginPage()),
          (route) => false,
        );
      });
      return const Scaffold(body: Center(child: Text('権限がありません')));
    }

    return Stack(

        children: [
          Scaffold(
            appBar: AppBar(
              title: const Text('宣伝画像の編集'),
              bottom: TabBar(
            controller: _tabController,
             tabs: const [
                     Tab(text: '上段'),
                      Tab(text: '下段'),
                    ],
                  ),

              actions: [
                IconButton(
                  tooltip: '追加',
                  icon: const Icon(Icons.add),
                  onPressed: _busy ? null : () => _addPromo(context),
                ),
              ],
            ),
            body: TabBarView(
  controller: _tabController,
  children: const [
    _PromoList(which: PromoWhich.top),
    _PromoList(which: PromoWhich.bottom),
  ],
),

          ),

          // ✅ 追加中の固まり対策（連打防止＋視覚的に待機）
          if (_busy) ...[
            const ModalBarrier(dismissible: false, color: Colors.black45),
            const Center(child: CircularProgressIndicator()),
          ],
        ],
    );
  }

  Future<void> _addPromo(BuildContext context) async {
    // ✅ タブ取得が取れない端末/状況でも落ちないように
    final which =
    _tabController.index == 0 ? PromoWhich.top : PromoWhich.bottom;


    setState(() => _busy = true);
    try {
      final p = await _promoDialog(context, initial: null);
      if (p == null) return;
      if (!mounted) return;

      final state = context.read<PromoState>();

      // ここが重いと固まる。まずは「画像データを保存しない」方針でOK。
      if (which == PromoWhich.top) {
        await state.addTop(p);
      } else {
        await state.addBottom(p);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('追加でエラー: $e')),
      );
    } finally {
      if (!mounted) return;
      setState(() => _busy = false);
    }
  }
}

enum PromoWhich { top, bottom }

class _PromoList extends StatelessWidget {
  final PromoWhich which;
  const _PromoList({required this.which});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<PromoState>();
    final list = which == PromoWhich.top ? state.top : state.bottom;

    return ReorderableListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: list.length,
      onReorder: (o, n) async {
        if (which == PromoWhich.top) {
          await state.reorderTop(o, n);
        } else {
          await state.reorderBottom(o, n);
        }
      },
      itemBuilder: (context, i) {
        final p0 = list[i];


        return Card(
          key: ValueKey(p0.id),
          child: ListTile(
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 56,
                height: 56,

            child: _PromoImageThumb(
              src: p0.imageUrl,
              focalX: p0.focalX,
              focalY: p0.focalY,
            ),




              ),
            ),
            title: Text(p0.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(p0.sub, maxLines: 2, overflow: TextOverflow.ellipsis),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
  tooltip: '編集',
  icon: const Icon(Icons.edit),
  onPressed: () async {
    final updated = await _promoDialog(context, initial: p0);
    if (updated == null) return;
    if (!context.mounted) return;

    final s = context.read<PromoState>();
    if (which == PromoWhich.top) {
      await s.updateTop(updated);
    } else {
      await s.updateBottom(updated);
    }
  },
),



                IconButton(
                  tooltip: '削除',
                  icon: const Icon(Icons.delete),
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('削除しますか？'),
                        content: const Text('この宣伝画像を削除します。'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('キャンセル')),
                          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('削除')),
                        ],
                      ),
                    );
                    if (ok != true) return;
                    if (!context.mounted) return;

                    final s = context.read<PromoState>();
                    if (which == PromoWhich.top) {
                      await s.removeTop(p0.id);
                    } else {
                      await s.removeBottom(p0.id);
                    }
                  },
                ),
                const Icon(Icons.drag_handle),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// ✅ URL でも ローカルファイルでも表示
 class _PromoImageThumb extends StatelessWidget {
  final String src;
  final double focalX;
  final double focalY;

  const _PromoImageThumb({
    required this.src,
    this.focalX = 0,
    this.focalY = 0,
  });

  bool get _isVideo => src.toLowerCase().endsWith('.mp4');

  String _normalizeUrl(String s) {
    if (s.startsWith('http://') || s.startsWith('https://')) {
      return s;
    }
    // 相対パス（/uploads/...）対応
    return ServerConfig.assetUrl(s);
  }

  @override
  Widget build(BuildContext context) {
    final url = _normalizeUrl(src);

    // ===== 動画 =====
    if (_isVideo) {
      return Material(
        color: Colors.black12,
        child: InkWell(
          onTap: () => _openVideo(context, url),
          child: const Center(
            child: Icon(
              Icons.play_circle_fill,
              size: 40,
              color: Colors.white70,
            ),
          ),
        ),
      );
    }

    // ===== 画像 =====
    return Image.network(
      url,
      fit: BoxFit.cover,
      alignment: Alignment(focalX, focalY),
      errorBuilder: (_, __, ___) =>
          const Center(child: Icon(Icons.broken_image)),
    );
  }
}







//////////////////////
Future<String?> _pickAndStoreImage() async {
  String? srcPath;

  // ===== PC / Web =====
  if (kIsWeb || Platform.isWindows || Platform.isMacOS) {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    if (result == null || result.files.single.path == null) return null;
    srcPath = result.files.single.path!;
  }
  // ===== iPad / iPhone =====
  else {
    final picker = ImagePicker();
    final x = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (x == null) return null;
    srcPath = x.path;
  }

  // ===== アプリ内にコピー =====
  final dir = await getApplicationDocumentsDirectory();
  final promosDir = Directory(p.join(dir.path, 'promos'));
  if (!await promosDir.exists()) {
    await promosDir.create(recursive: true);
  }

  final ext = p.extension(srcPath).isEmpty ? '.jpg' : p.extension(srcPath);
  final newPath = p.join(
    promosDir.path,
    'promo_${DateTime.now().millisecondsSinceEpoch}$ext',
  );

  final bytes = await File(srcPath).readAsBytes();
await File(newPath).writeAsBytes(bytes);
return newPath;

}


Future<Promo?> _promoDialog(BuildContext context, {Promo? initial}) async {
  final titleCtrl = TextEditingController(text: initial?.title ?? '');
  final subCtrl = TextEditingController(text: initial?.sub ?? '');
  final urlCtrl = TextEditingController(text: initial?.imageUrl ?? '');

  // 🔽 追加
  String linkType = initial?.linkType ?? 'none'; // none / category
  String? selectedCategory = initial?.category;
  String? selectedBrand = initial?.brand;   // ← これを追加
  String preview = initial?.imageUrl ?? '';
  double focalX = initial?.focalX ?? 0;
  double focalY = initial?.focalY ?? 0;

      void _resetMedia(String path) {
  preview = path;
  urlCtrl.text = path;
}
////

  
 final menuData = context.read<MenuData>();
  final menuCategories = menuData.categories;

  List<String> _brandsOf(String category) {
    final names = <String>[];
    for (final item in menuData.items) {
      if (item['category'] == category) {
        final name = (item['name'] ?? '').toString();
        if (name.isNotEmpty && !names.contains(name)) {
          names.add(name);
        }
      }
    }
    return names;
  }
  return showDialog<Promo>(
    context: context,
    builder: (_) => StatefulBuilder(
      builder: (context, setLocal) => AlertDialog(
        title: Text(initial == null ? '宣伝を追加' : '宣伝を編集'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ===== プレビュー =====
              if (preview.isNotEmpty) ...[
                SizedBox(
                  height: 140,
                  width: double.infinity,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: _PromoImageThumb(
                      src: preview,
                      focalX: focalX,
                      focalY: focalY,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],

              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: 'タイトル'),
              ),
              TextField(
                controller: subCtrl,
                decoration: const InputDecoration(labelText: 'サブ文'),
              ),
              TextField(
  controller: urlCtrl,
  decoration: const InputDecoration(labelText: '画像URL / ファイルパス'),
  onChanged: (v) => setLocal(() => preview = v.trim()),
),


              const SizedBox(height: 12),

              if (preview.isNotEmpty && !preview.toLowerCase().endsWith('.mp4')) ...[
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('表示位置（左右）'),
                ),
                Slider(
                  value: focalX,
                  min: -1,
                  max: 1,
                  onChanged: (v) => setLocal(() => focalX = v),
                ),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('表示位置（上下）'),
                ),
                Slider(
                  value: focalY,
                  min: -1,
                  max: 1,
                  onChanged: (v) => setLocal(() => focalY = v),
                ),
                const SizedBox(height: 8),
              ],

              // =========================
              // 行き先タイプ
              // =========================
              DropdownButtonFormField<String>(
                value: linkType,
                decoration: const InputDecoration(labelText: '行き先'),
                items: const [
                  DropdownMenuItem(value: 'none', child: Text('なし')),
                  DropdownMenuItem(value: 'category', child: Text('通常カテゴリ')),
                  DropdownMenuItem(value: 'brand', child: Text('ブランド')),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setLocal(() {
                    linkType = v;
                    if (v == 'none') {
                      selectedCategory = null;
                      selectedBrand = null;
                    } else if (v == 'category') {
                      selectedBrand = null;
                    }
                  });
                },
              ),

              // =========================
              // 通常カテゴリ選択（条件付き）
              // =========================
              if (linkType == 'category') ...[
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: selectedCategory,
                  decoration: const InputDecoration(labelText: 'カテゴリ'),
                  items: menuCategories
                      .map(
                        (c) => DropdownMenuItem(
                          value: c,
                          child: Text(c),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    setLocal(() => selectedCategory = v);
                  },
                ),
              ],
          if (linkType == 'brand') ...[
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: selectedCategory,
                  decoration: const InputDecoration(labelText: 'カテゴリ'),
                  items: menuCategories
                      .map(
                        (c) => DropdownMenuItem(
                          value: c,
                          child: Text(c),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    setLocal(() {
                      selectedCategory = v;
                      selectedBrand = null;
                    });
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: selectedBrand,
                  decoration: const InputDecoration(labelText: 'ブランド'),
                  items: (selectedCategory == null
                          ? <String>[]
                          : _brandsOf(selectedCategory!))
                      .map(
                        (b) => DropdownMenuItem(
                          value: b,
                          child: Text(b),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    setLocal(() => selectedBrand = v);
                  },
                ),
              ],
              const SizedBox(height: 10),

              // ===== 画像選択 =====
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.image),
                  label: const Text('画像を選ぶ（端末）'),
                onPressed: () async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.image,
    withData: true,
  );
  if (result == null) return;

  final file = result.files.single;
  if (file.bytes == null) return;

  // ---- サーバーにアップロード ----
  final uri = ServerConfig.api('/api/upload/promo');
  final req = http.MultipartRequest('POST', uri);
  req.files.add(
    http.MultipartFile.fromBytes(
      'file',
      file.bytes as Uint8List,
      filename: file.name,
    ),
  );

  final res = await req.send();
  if (res.statusCode != 200) return;

  final body = await res.stream.bytesToString();
  final url = body.contains('"url"')
      ? body.split('"url":"')[1].split('"')[0]
      : null;
  if (url == null) return;

  // ---- 取得した URL をそのまま使う ----
  setLocal(() => _resetMedia(ServerConfig.assetUrl(url)));
},


                ),
              ),
             Align(
  alignment: Alignment.centerLeft,
  child: OutlinedButton.icon(
    icon: const Icon(Icons.videocam),
    label: const Text('動画を選ぶ（端末）'),
    onPressed: () async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      withData: true,
    );
    if (result == null) return;

    final file = result.files.single;
    if (file.bytes == null) return;

    // ---- サーバーにアップロード ----
    final uri = ServerConfig.api('/api/upload/promo');
    final req = http.MultipartRequest('POST', uri);
    req.files.add(
      http.MultipartFile.fromBytes(
        'file',
        file.bytes!,
        filename: file.name,
      ),
    );

    final res = await req.send();
    if (res.statusCode != 200) return;

    final body = await res.stream.bytesToString();
    final url = body.split('"url":"')[1].split('"')[0];

    // ---- 取得したURLをそのまま使う ----
    setLocal(() {
      preview = ServerConfig.assetUrl(url);
      urlCtrl.text = preview;
    });
  },
),
),


            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
  onPressed: () async {
    final u = preview.trim();
    if (u.isEmpty) return;

    // ★ 差し替え時のみ、古いローカルファイルを削除
    if (initial != null && initial.imageUrl != u) {
      await _deleteIfLocalFile(initial.imageUrl);
    }

    if (!context.mounted) return;

    Navigator.pop(
      context,
      Promo(
        id: initial?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        title: titleCtrl.text.trim().isEmpty
            ? ' '
            : titleCtrl.text.trim(),
        sub: subCtrl.text.trim(),
        imageUrl: u,
        focalX: focalX,
        focalY: focalY,
        linkType: linkType,
        category: (linkType == 'category' || linkType == 'brand') ? selectedCategory : null,
        brand: linkType == 'brand' ? selectedBrand : null,
      ),
    );
  },
  child: const Text('保存'),
),

        ],
      ),
    ),
  );
}
Future<String?> _pickAndStoreVideo() async {
  String? srcPath;

  // ===== PC / Web =====
  if (kIsWeb || Platform.isWindows || Platform.isMacOS) {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      allowMultiple: false,
    );
    if (result == null || result.files.single.path == null) return null;
    srcPath = result.files.single.path!;
  }
  // ===== iPad / iPhone =====
  else {
    final picker = ImagePicker();
    final x = await picker.pickVideo(source: ImageSource.gallery);
    if (x == null) return null;
    srcPath = x.path;
  }

  // ===== アプリ内にコピー =====
  final dir = await getApplicationDocumentsDirectory();
  final promosDir = Directory(p.join(dir.path, 'promos'));
  if (!await promosDir.exists()) {
    await promosDir.create(recursive: true);
  }

  final ext = p.extension(srcPath).isEmpty ? '.mp4' : p.extension(srcPath);
  final newPath = p.join(
    promosDir.path,
    'promo_${DateTime.now().millisecondsSinceEpoch}$ext',
  );

 final bytes = await File(srcPath).readAsBytes();
await File(newPath).writeAsBytes(bytes);
return newPath;

}

Future<void> _deleteIfLocalFile(String? path) async {
  if (path == null || path.isEmpty) return;

  // http/https は削除対象外
  if (path.startsWith('http://') || path.startsWith('https://')) return;

  final f = File(path);
  if (await f.exists()) {
    try {
      await f.delete();
    } catch (_) {
      // 失敗しても致命的ではないので握りつぶす
    }
  }
}
void _openVideo(BuildContext context, String url) {
  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (_) {
      return Dialog(
        insetPadding: const EdgeInsets.all(16),
        backgroundColor: Colors.black,
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: VideoPlayerWidget(url: url),
        ),
      );
    },
  );
}
class VideoPlayerWidget extends StatefulWidget {
  final String url;
  const VideoPlayerWidget({super.key, required this.url});

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  late final VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.url),
    )..initialize().then((_) {
        setState(() {});
        _controller.play();
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_controller.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    return Stack(
      children: [
        Center(child: VideoPlayer(_controller)),
        Positioned(
          top: 8,
          right: 8,
          child: IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ],
    );
  }
}