import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'dart:async';
import '../data/menu_data.dart';
import '../data/cast_data.dart';
import '../data/cast_drink_data.dart';
import '../state/app_state.dart';
import '../state/cart_state.dart';
import '../state/promo_state.dart';

import 'brand_list_page.dart';
import 'login_page.dart';
import 'cart_side_panel.dart';
import 'guest_order_history_page.dart';
import 'cast_drink_flow_page.dart';
import 'variant_list_page.dart';
import '../utils/price_format.dart';

class GuestCategoryPage extends StatefulWidget {
  const GuestCategoryPage({super.key});

  @override
  State<GuestCategoryPage> createState() => _GuestCategoryPageState();
}

class _GuestCategoryPageState extends State<GuestCategoryPage> {
  @override
  Widget build(BuildContext context) {
    // ← あなたの今の巨大な build
    final promoState = context.watch<PromoState>();
     final menuData = context.watch<MenuData>();
    final cart = context.watch<CartState>();
    final hasCartItems = cart.items.isNotEmpty;
    final cartHighlightColor = Colors.orange.shade300;

    final normalCategories =
        menuData.categories.where((c) => c != 'キャストドリンク').toList();

    final guestCategories = [...normalCategories, 'キャストドリンク'];

    return Stack(
      children: [
        Positioned.fill(
          child: Image.asset(
            'assets/images/Image.png',
            repeat: ImageRepeat.repeat,
            fit: BoxFit.none,
            color: Colors.black.withValues(alpha: 0.32),
            colorBlendMode: BlendMode.darken,
          ),
        ),
        Positioned.fill(
          child: Container(
            color: const Color(0xFF0F0F12).withValues(alpha: 0.78),
          ),
        ),
        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: const Color(0xFF0F0F12),
            elevation: 0,
            /////////////
            title: Row(
  mainAxisSize: MainAxisSize.min,
  children: [
    const Text(
      'MENU',
      style: TextStyle(
        fontWeight: FontWeight.w600,
        letterSpacing: 1.5,
      ),
    ),
    const SizedBox(width: 12),
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '席 ${context.watch<AppState>().guestTable}',
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.5,
        ),
      ),
    ),
  ],
),

           ///////////////
           actions: [
              IconButton(
                 tooltip: 'メニュー更新',
                icon: const Icon(Icons.refresh),
               onPressed: () async {
                  await Future.wait([
                    context.read<MenuData>().load(),
                    context.read<PromoState>().load(),
                    context.read<CastData>().load(),
                    context.read<CastDrinkData>().load(),
                  ]);
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('メニュー・プロモ・キャスト情報を更新しました')),
                  );
                },
              ),
               IconButton(
                tooltip: 'カート',
                icon: Icon(
                  Icons.shopping_cart,
                  color: hasCartItems ? cartHighlightColor : null,
                ),
                onPressed: () => openCartSidePanel(context),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Center(
                  child: Text(
                    formatYen(cart.total),
                    style: TextStyle(
                      color: hasCartItems ? cartHighlightColor : null,
                      fontWeight: hasCartItems ? FontWeight.w600 : null,
                    ),
                  ),
                ),
              ),
             ////////////////////////////////////////
              IconButton(
              
                icon: const Icon(Icons.receipt_long),
                tooltip: '注文履歴',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const GuestOrderHistoryPage(),
                    ),
                  );
                },
              ),
                 ////////////////////////////////////////
              IconButton(
                tooltip: 'ログアウト',
                icon: const Icon(Icons.logout),
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('ログアウト'),
                      content: const Text('ログアウトしますか？'),
                      actions: [
                       
                       /////////////////////////////////////
                      TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('キャンセル'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('OK'),
                        ),
                      ],
                    ),
                  );
                  if (ok == true && context.mounted) {
                    context.read<AppState>().logout();
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginPage()),
                      (_) => false,
                    );
                  }
                },
              ),
            ],//ボタン
         
          ),
          body: LayoutBuilder(
            builder: (context, c) {
              final isWide = c.maxWidth >= 900;

              final left = ListView(
                children: guestCategories.map((category) {
                  return Container(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A1F),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.4),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ListTile(
                      title: Text(
                        category,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_right,
                          color: Colors.white54),
                     
                     onTap: () async {
  if (category == 'キャストドリンク') {
    final result = await Navigator.push<CastDrinkResult>(
      context,
      MaterialPageRoute(
        builder: (_) => const CastDrinkFlowPage(
        ),
      ),
    );

    if (result != null && context.mounted) {
      context.read<CartState>().add(
        category: 'キャストドリンク',
        brand: result.castName, // キャスト名
        label: '${result.drinkName}（${result.strength}）',
        price: result.price,
      );
    }
    return;
  }


                        Navigator.push(
                          context,
                          PageRouteBuilder(
                            transitionDuration:
                                const Duration(milliseconds: 300),
                            pageBuilder:
                                (context, animation, secondaryAnimation) =>
                                    BrandListPage(category: category),
                            transitionsBuilder:
                                (context, animation, secondaryAnimation, child) =>
                                    FadeTransition(opacity: animation, child: child),
                          ),
                        );
                      },
                    ),
                  );
                }).toList(),
              );

              final right = _PromoSplitPanel(
                top: promoState.top,
                bottom: promoState.bottom,
              );

              if (!isWide) {
                return Column(
                  children: [
                    Expanded(child: left),
                    SizedBox(height: 240, child: right),
                  ],
                );
              }

              return Row(
                children: [
                  SizedBox(width: 360, child: left),
                  const VerticalDivider(width: 1),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: right,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

/* ================= プロモ一覧 ================= */

class _PromoSplitPanel extends StatelessWidget {
  final List<Promo> top;
  final List<Promo> bottom;

  const _PromoSplitPanel({
    required this.top,
    required this.bottom,
  });

  @override
  Widget build(BuildContext context) {
    final mergedPromos = [...top, ...bottom];
    return _PromoPanel(promos: mergedPromos);
  }
}

class _PromoPanel extends StatefulWidget {
  final List<Promo> promos;
  const _PromoPanel({required this.promos});

  @override
  State<_PromoPanel> createState() => _PromoPanelState();
}

class _PromoPanelState extends State<_PromoPanel> {
  static const Duration _autoSlideInterval = Duration(seconds: 6);

  late final PageController _pc;
  int _index = 0;
  Timer? _autoSlideTimer;

  VideoPlayerController? _activeListController;

  String _normalizeKey(String s) {
    return s.trim().replaceAll('　', ' ').replaceAll(RegExp(r'\s+'), ' ');
  }

  Map<String, dynamic>? _findBrandItem({
    required MenuData menuData,
    required String category,
    required String brand,
  }) {
    final targetCategory = _normalizeKey(category);
    final targetBrand = _normalizeKey(brand);

    for (final item in menuData.items) {
      final itemCategory = _normalizeKey((item['category'] ?? '').toString());
      final itemBrand = _normalizeKey((item['name'] ?? '').toString());
      if (itemCategory == targetCategory && itemBrand == targetBrand) {
        return item;
      }
    }

    return null;
  }

  void _openPromoDestination(Promo p) {
    final category = p.category?.trim();
    if (category == null || category.isEmpty) return;

    if (p.linkType == 'brand') {
      final brand = p.brand?.trim();
      if (brand == null || brand.isEmpty) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BrandListPage(category: category),
          ),
        );
        return;
      }

      final menuData = context.read<MenuData>();
      final brandItem = _findBrandItem(
        menuData: menuData,
        category: category,
        brand: brand,
      );

      if (brandItem != null) {
        final variants = (brandItem['variants'] as List?) ?? const [];
        Navigator.push(
          context,
          MaterialPageRoute(
           builder: (_) => VariantListPage(
              category: category,
              brandName: brand,
              variants: variants,
            ),
          ),
        );
        return;
      }
      
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BrandListPage(
            category: category,
            initialBrand: brand,
          ),
        ),
      );
      return;
    }

    if (p.linkType == 'category') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BrandListPage(category: category),
        ),
      );
    }
  }

  void _setActiveList(VideoPlayerController? c) {
    if (_activeListController == c) return;
    _activeListController?.pause();
    _activeListController = c;
  }

 @override
  void initState() {
    super.initState();
    _pc = PageController();
    _startAutoSlide();
  }

  @override
 void dispose() {
    _autoSlideTimer?.cancel();
    _pc.dispose();
    _activeListController?.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _PromoPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.promos.length != widget.promos.length) {
      if (_index >= widget.promos.length) {
        _index = widget.promos.isEmpty ? 0 : widget.promos.length - 1;
      }
      _startAutoSlide();
    }
  }

  void _startAutoSlide() {
    _autoSlideTimer?.cancel();
    if (widget.promos.length <= 1) return;

    _autoSlideTimer = Timer.periodic(_autoSlideInterval, (_) {
      if (!mounted || !_pc.hasClients || widget.promos.length <= 1) return;

      final next = (_index + 1) % widget.promos.length;
      _pc.animateToPage(
        next,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.promos.isEmpty) {
      return const Center(child: Text('宣伝コンテンツがありません'));
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            controller: _pc,
            itemCount: widget.promos.length,
             onPageChanged: (i) {
              _setActiveList(null);
              setState(() => _index = i);
              _startAutoSlide();
            },
            itemBuilder: (context, i) {
              final p = widget.promos[i];
              return _PromoTile(
                promo: p,
                onTap: () => _openPromoDestination(p),
                onLongPress: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PromoFullScreenPage(
                        urls: widget.promos.map((e) => e.imageUrl).toList(),
                        initialIndex: i,
                      ),
                    ),
                  );
                },
                onControllerReady: _setActiveList,
              );
            },
          ),
          Positioned(
            bottom: 8,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                widget.promos.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: i == _index ? 18 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: i == _index ? Colors.white : Colors.white24,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PromoTile extends StatelessWidget {
  final Promo promo;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final void Function(VideoPlayerController) onControllerReady;

  const _PromoTile({
    required this.promo,
    required this.onTap,
    required this.onLongPress,
    required this.onControllerReady,
  });

  @override
  Widget build(BuildContext context) {
    final isVideo = promo.imageUrl.endsWith('.mp4');

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Stack(
        fit: StackFit.expand,
        children: [
          isVideo
    ? _MutedAutoVideo(
        url: promo.imageUrl,
        onControllerReady: onControllerReady,
      )
    : Positioned.fill(
         child: Image.network(
          promo.imageUrl,
          fit: BoxFit.cover,
          alignment: Alignment(promo.focalX, promo.focalY),
          errorBuilder: (context, error, stackTrace) =>
              const Center(child: Text('画像を読み込めません')),
        ),
      ),

          if (isVideo)
            const Positioned(
              right: 12,
              bottom: 12,
              child: Icon(
                Icons.play_circle_fill,
                color: Colors.white70,
                size: 36,
              ),
            ),
        ],
      ),
    );
  }
}

class _MutedAutoVideo extends StatefulWidget {
  final String url;
  final void Function(VideoPlayerController) onControllerReady;

  const _MutedAutoVideo({
    required this.url,
    required this.onControllerReady,
  });

  @override
  State<_MutedAutoVideo> createState() => _MutedAutoVideoState();
}

class _MutedAutoVideoState extends State<_MutedAutoVideo> {
  late VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        _controller
          ..setLooping(true)
          ..setVolume(0)
          ..play();
        widget.onControllerReady(_controller);
        setState(() {});
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
      return const ColoredBox(color: Colors.black);
    }
    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: _controller.value.size.width,
        height: _controller.value.size.height,
        child: VideoPlayer(_controller),
      ),
    );
  }
}

/* ================= 全画面 ================= */

class PromoFullScreenPage extends StatefulWidget {
  final List<String> urls;
  final int initialIndex;

  const PromoFullScreenPage({
    super.key,
    required this.urls,
    required this.initialIndex,
  });

  @override
  State<PromoFullScreenPage> createState() => _PromoFullScreenPageState();
}

class _PromoFullScreenPageState extends State<PromoFullScreenPage> {
  VideoPlayerController? _activeController;

  void _setActive(VideoPlayerController? c) {
    if (_activeController == c) return;
    _activeController?.pause();
    _activeController = c;
  }

  @override
  void dispose() {
    _activeController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: PageController(initialPage: widget.initialIndex),
            itemCount: widget.urls.length,
            onPageChanged: (_) => _setActive(null),
            itemBuilder: (context, i) {
              final url = widget.urls[i];
              final isVideo = url.endsWith('.mp4');
              return isVideo
                  ? _VideoPlayerItem(
                      url: url,
                      onControllerReady: _setActive,
                    )
                  : Image.network(url, fit: BoxFit.cover);
            },
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 8,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _VideoPlayerItem extends StatefulWidget {
  final String url;
  final void Function(VideoPlayerController) onControllerReady;

  const _VideoPlayerItem({
    required this.url,
    required this.onControllerReady,
  });

  @override
  State<_VideoPlayerItem> createState() => _VideoPlayerItemState();
}

class _VideoPlayerItemState extends State<_VideoPlayerItem> {
  late VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        _controller
          ..setLooping(true)
          ..play();
        widget.onControllerReady(_controller);
        setState(() {});
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
    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: _controller.value.size.width,
        height: _controller.value.size.height,
        child: VideoPlayer(_controller),
      ),
    );
  }
}