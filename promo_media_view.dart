import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class PromoMediaView extends StatelessWidget {
  final String src;
  const PromoMediaView({super.key, required this.src});

  bool get _isVideo => src.toLowerCase().endsWith('.mp4');

  @override
  Widget build(BuildContext context) {
    if (_isVideo) {
      return Stack(
        fit: StackFit.expand,
        children: [
          _MutedAutoVideo(url: src),
          const Center(
            child: Icon(Icons.play_circle_fill,
                size: 36, color: Colors.white70),
          ),
        ],
      );
    }

    final isNet = src.startsWith('http://') || src.startsWith('https://');

    return isNet
        ? Image.network(
            src,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                const Center(child: Text('画像を読み込めません')),
          )
        : (kIsWeb
            ? const Center(child: Text('画像を読み込めません'))
            : Image.file(
                File(src),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    const Center(child: Text('画像を読み込めません')),
              ));
  }
}

class _MutedAutoVideo extends StatefulWidget {
  final String url;
  const _MutedAutoVideo({required this.url});

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
