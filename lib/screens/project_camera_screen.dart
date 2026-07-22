import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

@visibleForTesting
bool shouldReleaseCameraForLifecycle(AppLifecycleState state) =>
    state == AppLifecycleState.paused ||
    state == AppLifecycleState.hidden ||
    state == AppLifecycleState.detached;

@visibleForTesting
bool cameraFlashControlsAvailable({required bool isWeb}) => !isWeb;

class ProjectCameraScreen extends StatefulWidget {
  const ProjectCameraScreen({super.key});

  @override
  State<ProjectCameraScreen> createState() => _ProjectCameraScreenState();
}

class _ProjectCameraScreenState extends State<ProjectCameraScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  Object? _initializationError;
  bool _initializing = false;
  bool _capturing = false;
  bool _cameraShouldBeActive = true;
  FlashMode _flashMode = FlashMode.off;
  int _initializationGeneration = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_initializeCamera());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraShouldBeActive = false;
    _initializationGeneration++;
    unawaited(_controller?.dispose());
    _controller = null;
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Permission dialogs make the app inactive while camera initialization is
    // still in progress. Treat only an actual background transition as a stop.
    if (shouldReleaseCameraForLifecycle(state)) {
      _cameraShouldBeActive = false;
      final controller = _controller;
      if (controller != null) {
        _initializationGeneration++;
      }
      if (mounted) {
        setState(() {
          _controller = null;
        });
      } else {
        _controller = null;
      }
      unawaited(controller?.dispose());
      return;
    }
    if (state == AppLifecycleState.resumed) {
      _cameraShouldBeActive = true;
      if (_controller == null && !_initializing) {
        unawaited(_initializeCamera());
      }
    }
  }

  Future<void> _initializeCamera() async {
    if (_initializing) return;
    final generation = ++_initializationGeneration;
    if (mounted) {
      setState(() {
        _initializing = true;
        _initializationError = null;
      });
    }

    CameraController? nextController;
    try {
      final cameras = await availableCameras();
      if (_isStaleInitialization(generation)) {
        await _finishStaleInitialization(null);
        return;
      }
      if (cameras.isEmpty) {
        throw CameraException('no_camera', '利用できるカメラがありません。');
      }
      final camera = cameras
          .where((item) => item.lensDirection == CameraLensDirection.back)
          .firstOrNull;
      nextController = CameraController(
        camera ?? cameras.first,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await nextController.initialize();
      if (cameraFlashControlsAvailable(isWeb: kIsWeb)) {
        await nextController.setFlashMode(_flashMode);
      }
      if (_isStaleInitialization(generation)) {
        await _finishStaleInitialization(nextController);
        return;
      }
      setState(() {
        _controller = nextController;
        _initializing = false;
      });
    } on CameraException catch (error) {
      await nextController?.dispose();
      if (!mounted) return;
      if (_isStaleInitialization(generation)) {
        _restartAfterStaleInitialization();
        return;
      }
      setState(() {
        _initializationError = error;
        _initializing = false;
      });
    } catch (error) {
      await nextController?.dispose();
      if (!mounted) return;
      if (_isStaleInitialization(generation)) {
        _restartAfterStaleInitialization();
        return;
      }
      setState(() {
        _initializationError = error;
        _initializing = false;
      });
    }
  }

  bool _isStaleInitialization(int generation) =>
      !mounted ||
      generation != _initializationGeneration ||
      !_cameraShouldBeActive;

  Future<void> _finishStaleInitialization(CameraController? controller) async {
    await controller?.dispose();
    if (!mounted) return;
    _restartAfterStaleInitialization();
  }

  void _restartAfterStaleInitialization() {
    setState(() => _initializing = false);
    if (_cameraShouldBeActive && _controller == null) {
      unawaited(_initializeCamera());
    }
  }

  Future<void> _takePicture() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _capturing) {
      return;
    }
    setState(() => _capturing = true);
    try {
      final file = await controller.takePicture();
      if (mounted) Navigator.of(context).pop(file);
    } on CameraException {
      if (!mounted) return;
      setState(() => _capturing = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('写真を撮影できませんでした。')));
    }
  }

  Future<void> _toggleFlash() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    final next = _flashMode == FlashMode.off ? FlashMode.auto : FlashMode.off;
    try {
      await controller.setFlashMode(next);
      if (mounted) setState(() => _flashMode = next);
    } on CameraException {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('この端末でフラッシュを切り替えられません。')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Scaffold(
      key: const ValueKey('project-camera-screen'),
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (controller != null && controller.value.isInitialized)
            _CameraPreviewFill(controller: controller)
          else
            _CameraStatus(
              loading: _initializing,
              error: _initializationError,
              onRetry: _initializeCamera,
            ),
          SafeArea(
            child: Stack(
              children: [
                Positioned(
                  left: 12,
                  top: 8,
                  child: _CameraControlButton(
                    tooltip: '閉じる',
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: CupertinoIcons.xmark,
                  ),
                ),
                if (cameraFlashControlsAvailable(isWeb: kIsWeb))
                  Positioned(
                    right: 12,
                    top: 8,
                    child: _CameraControlButton(
                      tooltip: _flashMode == FlashMode.off
                          ? 'フラッシュを自動にする'
                          : 'フラッシュをオフにする',
                      onPressed: controller == null ? null : _toggleFlash,
                      icon: _flashMode == FlashMode.off
                          ? CupertinoIcons.bolt_slash_fill
                          : CupertinoIcons.bolt_fill,
                    ),
                  ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Semantics(
                      button: true,
                      label: '写真を撮影',
                      child: CupertinoButton(
                        key: const ValueKey('camera-shutter'),
                        padding: EdgeInsets.zero,
                        onPressed: controller == null || _capturing
                            ? null
                            : _takePicture,
                        child: Container(
                          width: 76,
                          height: 76,
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: .32),
                            shape: BoxShape.circle,
                          ),
                          child: DecoratedBox(
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: _capturing
                                ? const Center(
                                    child: CupertinoActivityIndicator(
                                      color: Colors.black,
                                    ),
                                  )
                                : null,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CameraPreviewFill extends StatelessWidget {
  const _CameraPreviewFill({required this.controller});

  final CameraController controller;

  @override
  Widget build(BuildContext context) {
    final screenAspectRatio = MediaQuery.sizeOf(context).aspectRatio;
    var scale = screenAspectRatio * controller.value.aspectRatio;
    if (scale < 1) scale = 1 / scale;
    return ClipRect(
      child: Transform.scale(
        scale: scale,
        child: Center(child: CameraPreview(controller)),
      ),
    );
  }
}

class _CameraStatus extends StatelessWidget {
  const _CameraStatus({
    required this.loading,
    required this.error,
    required this.onRetry,
  });

  final bool loading;
  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (loading || error == null) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoActivityIndicator(color: Colors.white, radius: 15),
            SizedBox(height: 12),
            Text('カメラを準備中', style: TextStyle(color: Colors.white)),
          ],
        ),
      );
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(CupertinoIcons.camera, color: Colors.white70, size: 42),
            const SizedBox(height: 12),
            const Text(
              'カメラを使用できません',
              style: TextStyle(color: Colors.white, fontSize: 17),
            ),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('再試行')),
          ],
        ),
      ),
    );
  }
}

class _CameraControlButton extends StatelessWidget {
  const _CameraControlButton({
    required this.tooltip,
    required this.onPressed,
    required this.icon,
  });

  final String tooltip;
  final VoidCallback? onPressed;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: onPressed,
        style: IconButton.styleFrom(
          backgroundColor: Colors.black.withValues(alpha: .5),
          foregroundColor: Colors.white,
          disabledForegroundColor: Colors.white38,
        ),
        icon: Icon(icon),
      ),
    );
  }
}
