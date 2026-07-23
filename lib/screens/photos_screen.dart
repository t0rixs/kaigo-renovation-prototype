import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart' as image_picker;

import '../app_state.dart';
import '../models.dart';
import '../photo_capture_session.dart';
import '../photos/photo_processor.dart';
import 'editor_tool_button.dart';
import 'photo_drawing_canvas.dart';
import 'project_camera_screen.dart';

typedef ProjectPhotoCapture = Future<CapturedProjectPhoto?> Function();

enum PhotoTool { move }

enum _PhotoSource { camera, library }

class PhotosScreen extends StatefulWidget {
  const PhotosScreen({
    super.key,
    required this.state,
    this.capturePhoto,
    this.selectPhoto,
  });

  final AppState state;
  final ProjectPhotoCapture? capturePhoto;
  final ProjectPhotoCapture? selectPhoto;

  @override
  State<PhotosScreen> createState() => _PhotosScreenState();
}

class _PhotosScreenState extends State<PhotosScreen> {
  static const compactPanelBreakpoint = 700.0;
  static const panelItemExtent = 320.0;

  final Set<String> _busySlots = {};
  final ScrollController _menuScroll = ScrollController();
  final PhotoDrawingController _drawingController = PhotoDrawingController();
  final image_picker.ImagePicker _imagePicker = image_picker.ImagePicker();
  PhotoTool? _tool;
  String? _activeLocationId;
  bool _moveCheckpointTaken = false;
  double _panelWidth = 320;
  double _panelHeight = 420;
  bool _compactPanel = false;
  double _panelViewportHeight = 0;
  double _panelVerticalPadding = 12;

  AppState get state => widget.state;

  @override
  void initState() {
    super.initState();
    _menuScroll.addListener(_handleMenuScroll);
    if (widget.capturePhoto == null) {
      unawaited(_restoreInterruptedCaptureSession());
    }
  }

  @override
  void dispose() {
    _menuScroll
      ..removeListener(_handleMenuScroll)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locations = state.photoLocations;
    if (locations.isEmpty) {
      _activeLocationId = null;
    } else if (!locations.any((item) => item.id == _activeLocationId)) {
      _activeLocationId = locations.first.id;
    }
    return Column(
      key: const ValueKey('photos-screen'),
      children: [
        _toolbar(locations),
        _statusBar(),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              _compactPanel = constraints.maxWidth < compactPanelBreakpoint;
              if (_compactPanel) {
                _panelWidth = constraints.maxWidth;
                _panelHeight = math.min(
                  430,
                  math.max(360, constraints.maxHeight * .58),
                );
              } else {
                _panelWidth = math.min(360, constraints.maxWidth * .4);
                _panelHeight = constraints.maxHeight;
              }
              return Stack(
                children: [
                  Positioned.fill(
                    child: PhotoDrawingCanvas(
                      state: state,
                      controller: _drawingController,
                      activeLocationId: _activeLocationId,
                      moveMode: _tool == PhotoTool.move,
                      onMarkerTap: _openLocation,
                      onMarkerMoveStart: _beginMarkerMove,
                      onMarkerMove: _moveMarker,
                      onMarkerMoveEnd: _endMarkerMove,
                    ),
                  ),
                  if (_compactPanel)
                    Positioned(
                      key: const ValueKey('photo-bottom-menu'),
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: _panelHeight,
                      child: _photoMenu(locations, compact: true),
                    )
                  else
                    Positioned(
                      key: const ValueKey('photo-right-menu'),
                      top: 0,
                      right: 0,
                      bottom: 0,
                      width: _panelWidth,
                      child: _photoMenu(locations, compact: false),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  double _toolBarHeight() {
    final scaledLabel = MediaQuery.textScalerOf(context).scale(11);
    return (68 + math.max(0, scaledLabel - 11) * 2).clamp(68, 94).toDouble();
  }

  Widget _toolbar(List<RenovationPhotoLocation> locations) => Container(
    key: const ValueKey('photo-toolbar'),
    height: _toolBarHeight(),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      border: Border(
        bottom: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
    ),
    child: ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 7),
      children: [
        EditorToolButton(
          key: const ValueKey('move-photo-location'),
          icon: CupertinoIcons.move,
          label: '移動',
          selected: _tool == PhotoTool.move,
          enabled: locations.isNotEmpty,
          onTap: () => _toggleTool(PhotoTool.move),
        ),
      ],
    ),
  );

  Widget _statusBar() {
    final text = switch (_tool) {
      PhotoTool.move => '移動：丸番号をドラッグして位置を変更（250mm単位）',
      null => '手すりNoごとに写真位置を自動表示・ドラッグで画面移動',
    };
    return Container(
      width: double.infinity,
      color: Theme.of(context).colorScheme.primaryContainer,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: Theme.of(context).colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  void _toggleTool(PhotoTool value) {
    setState(() {
      _tool = _tool == value ? null : value;
    });
  }

  void _openLocation(RenovationPhotoLocation location) {
    setState(() {
      if (_tool != PhotoTool.move) _tool = null;
      _activeLocationId = location.id;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToLocation(location);
      _centerLocation(location);
    });
  }

  void _beginMarkerMove(RenovationPhotoLocation location) {
    setState(() {
      _activeLocationId = location.id;
      _moveCheckpointTaken = false;
    });
  }

  void _moveMarker(RenovationPhotoLocation location, Offset pointMm) {
    final nextX = state.snapMm(pointMm.dx);
    final nextY = state.snapMm(pointMm.dy);
    if (location.xMm == nextX && location.yMm == nextY) return;
    if (!_moveCheckpointTaken) {
      state.checkpoint();
      _moveCheckpointTaken = true;
    }
    if (state.movePhotoLocation(location, xMm: nextX, yMm: nextY)) {
      setState(() {});
    }
  }

  void _endMarkerMove(RenovationPhotoLocation location) {
    if (!mounted) return;
    setState(() {
      _activeLocationId = location.id;
      _moveCheckpointTaken = false;
    });
  }

  Widget _photoMenu(
    List<RenovationPhotoLocation> locations, {
    required bool compact,
  }) {
    return Material(
      key: const ValueKey('photo-side-menu'),
      elevation: 12,
      color: Theme.of(context).colorScheme.surface,
      shape: compact
          ? const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            )
          : null,
      clipBehavior: compact ? Clip.antiAlias : Clip.none,
      child: SafeArea(
        left: false,
        child: Column(
          children: [
            SizedBox(
              height: 52,
              child: Row(
                children: [
                  const SizedBox(width: 16),
                  Text(
                    '写真',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(width: 4),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: locations.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          '図面に手すりを配置すると、Noごとの写真欄が表示されます',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ),
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        _panelViewportHeight = constraints.maxHeight;
                        _panelVerticalPadding = math.max(
                          12,
                          (constraints.maxHeight - panelItemExtent) / 2,
                        );
                        return ListView.builder(
                          key: const ValueKey('photo-location-list'),
                          controller: _menuScroll,
                          padding: EdgeInsets.symmetric(
                            vertical: _panelVerticalPadding,
                          ),
                          itemExtent: panelItemExtent,
                          itemCount: locations.length,
                          itemBuilder: (context, index) {
                            final location = locations[index];
                            return _PhotoLocationPanelItem(
                              location: location,
                              number: location.handrailNumber,
                              active: location.id == _activeLocationId,
                              isBusy: (slot) => _busySlots.contains(
                                _slotKey(location.id, slot),
                              ),
                              onCapture: (slot) => _capture(location, slot),
                              onMemoChanged: (slot, value) =>
                                  state.setProjectPhotoMemo(
                                    projectId: state.activeProject.id,
                                    locationId: location.id,
                                    slot: slot,
                                    value: value,
                                  ),
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleMenuScroll() {
    if (!_menuScroll.hasClients || state.photoLocations.isEmpty) {
      return;
    }
    final centerOffset =
        _menuScroll.offset + _menuScroll.position.viewportDimension / 2;
    final index =
        ((centerOffset - _panelVerticalPadding - panelItemExtent / 2) /
                panelItemExtent)
            .round()
            .clamp(0, state.photoLocations.length - 1);
    final location = state.photoLocations[index];
    if (location.id == _activeLocationId) return;
    setState(() => _activeLocationId = location.id);
    _centerLocation(location);
  }

  void _scrollToLocation(RenovationPhotoLocation location) {
    if (!_menuScroll.hasClients) return;
    final index = state.photoLocations.indexWhere(
      (item) => item.id == location.id,
    );
    if (index < 0) return;
    final target =
        (_panelVerticalPadding +
                index * panelItemExtent +
                panelItemExtent / 2 -
                _panelViewportHeight / 2)
            .clamp(0.0, _menuScroll.position.maxScrollExtent);
    _menuScroll.animateTo(
      target,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  void _centerLocation(RenovationPhotoLocation location) {
    _drawingController.centerOn(
      location,
      rightInset: _compactPanel ? 0 : _panelWidth,
      bottomInset: _compactPanel ? _panelHeight : 0,
    );
  }

  String _slotKey(String locationId, ProjectPhotoSlot slot) =>
      '$locationId-${slot.name}';

  Future<void> _capture(
    RenovationPhotoLocation location,
    ProjectPhotoSlot slot,
  ) async {
    final busyKey = _slotKey(location.id, slot);
    if (_busySlots.contains(busyKey)) return;
    await _choosePhotoSource(
      replacing: location.photoFor(slot) != null,
      onSelected: (source) {
        unawaited(_captureFromSource(location, slot, source));
      },
      onDelete: () {
        state.clearProjectPhoto(
          projectId: state.activeProject.id,
          locationId: location.id,
          slot: slot,
        );
      },
    );
  }

  Future<void> _captureFromSource(
    RenovationPhotoLocation location,
    ProjectPhotoSlot slot,
    _PhotoSource source,
  ) async {
    final busyKey = _slotKey(location.id, slot);
    if (!mounted || _busySlots.contains(busyKey)) return;
    setState(() => _busySlots.add(busyKey));

    try {
      final photo = switch (source) {
        _PhotoSource.camera =>
          widget.capturePhoto != null
              ? await widget.capturePhoto!()
              : await _captureWithCamera(location.id, slot),
        _PhotoSource.library =>
          widget.selectPhoto != null
              ? await widget.selectPhoto!()
              : await _selectFromLibrary(location.id, slot),
      };
      if (photo == null || !mounted) return;
      state.setProjectPhoto(
        projectId: state.activeProject.id,
        locationId: location.id,
        slot: slot,
        photo: photo,
      );
    } on CameraException catch (_) {
      _showError('カメラを使用できませんでした。');
    } catch (error, stackTrace) {
      debugPrint('Photo import failed: $error\n$stackTrace');
      _showError('写真を読み込めませんでした。もう一度お試しください。');
    } finally {
      if (mounted) setState(() => _busySlots.remove(busyKey));
    }
  }

  Future<void> _choosePhotoSource({
    required bool replacing,
    required ValueChanged<_PhotoSource> onSelected,
    required VoidCallback onDelete,
  }) => showCupertinoModalPopup<void>(
    context: context,
    builder: (sheetContext) => CupertinoActionSheet(
      title: Text(replacing ? '写真を変更' : '写真を追加'),
      message: const Text('追加方法を選択してください'),
      actions: [
        CupertinoActionSheetAction(
          key: const ValueKey('photo-source-camera'),
          onPressed: () {
            Navigator.of(sheetContext).pop();
            onSelected(_PhotoSource.camera);
          },
          child: const _PhotoSourceAction(
            icon: CupertinoIcons.camera,
            label: '撮影',
          ),
        ),
        CupertinoActionSheetAction(
          key: const ValueKey('photo-source-library'),
          onPressed: () {
            Navigator.of(sheetContext).pop();
            onSelected(_PhotoSource.library);
          },
          child: const _PhotoSourceAction(
            icon: CupertinoIcons.photo_on_rectangle,
            label: '画像を選択',
          ),
        ),
        if (replacing)
          CupertinoActionSheetAction(
            key: const ValueKey('delete-project-photo'),
            isDestructiveAction: true,
            onPressed: () {
              Navigator.of(sheetContext).pop();
              onDelete();
            },
            child: const _PhotoSourceAction(
              icon: CupertinoIcons.trash,
              label: '写真を削除',
            ),
          ),
      ],
      cancelButton: CupertinoActionSheetAction(
        key: const ValueKey('cancel-photo-source'),
        onPressed: () => Navigator.of(sheetContext).pop(),
        child: const Text('キャンセル'),
      ),
    ),
  );

  Future<CapturedProjectPhoto?> _captureWithCamera(
    String locationId,
    ProjectPhotoSlot slot,
  ) async {
    await PhotoCaptureSession.begin(
      projectId: state.activeProject.id,
      locationId: locationId,
      slot: slot,
    );

    if (!mounted) return null;
    final file = await Navigator.of(context).push<XFile>(
      CupertinoPageRoute(
        fullscreenDialog: true,
        builder: (_) => const ProjectCameraScreen(),
      ),
    );
    await PhotoCaptureSession.clear();
    return file == null ? null : _photoFromFile(file);
  }

  Future<CapturedProjectPhoto?> _selectFromLibrary(
    String locationId,
    ProjectPhotoSlot slot,
  ) async {
    if (kIsWeb) {
      final file = await _imagePicker.pickImage(
        source: image_picker.ImageSource.gallery,
      );
      return file == null ? null : _photoFromFile(file);
    }
    await PhotoCaptureSession.begin(
      projectId: state.activeProject.id,
      locationId: locationId,
      slot: slot,
    );
    try {
      final file = await _imagePicker.pickImage(
        source: image_picker.ImageSource.gallery,
      );
      return file == null ? null : _photoFromFile(file);
    } finally {
      await PhotoCaptureSession.clear();
    }
  }

  Future<void> _restoreInterruptedCaptureSession() async {
    final pending = await PhotoCaptureSession.read();
    if (pending == null) return;
    final location = pending.projectId == state.activeProject.id
        ? state.photoLocations
              .where((item) => item.id == pending.locationId)
              .firstOrNull
        : null;
    await PhotoCaptureSession.clear();
    if (!mounted || location == null) return;
    setState(() {
      _activeLocationId = location.id;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToLocation(location);
      _centerLocation(location);
    });
  }

  Future<CapturedProjectPhoto> _photoFromFile(XFile file) async {
    final sourceBytes = await file.readAsBytes();
    final bytes = await processCapturedPhoto(sourceBytes);
    return CapturedProjectPhoto(
      base64Data: base64Encode(bytes),
      mimeType: 'image/jpeg',
      fileName: _jpegFileName(file.name),
      capturedAt: DateTime.now(),
    );
  }

  String _jpegFileName(String originalName) {
    final separator = originalName.lastIndexOf('.');
    final stem = separator <= 0
        ? originalName
        : originalName.substring(0, separator);
    return '$stem.jpg';
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _PhotoSourceAction extends StatelessWidget {
  const _PhotoSourceAction({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [Icon(icon, size: 22), const SizedBox(width: 10), Text(label)],
  );
}

class _PhotoLocationPanelItem extends StatelessWidget {
  const _PhotoLocationPanelItem({
    required this.location,
    required this.number,
    required this.active,
    required this.isBusy,
    required this.onCapture,
    required this.onMemoChanged,
  });

  final RenovationPhotoLocation location;
  final String number;
  final bool active;
  final bool Function(ProjectPhotoSlot slot) isBusy;
  final ValueChanged<ProjectPhotoSlot> onCapture;
  final void Function(ProjectPhotoSlot slot, String value) onMemoChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: DecoratedBox(
        key: ValueKey('photo-location-${location.id}'),
        decoration: BoxDecoration(
          color: active
              ? colors.primaryContainer.withValues(alpha: .35)
              : colors.surface,
          border: Border.all(
            color: active ? colors.primary : colors.outlineVariant,
            width: active ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: active ? colors.primary : colors.onSurfaceVariant,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      number,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      location.locationName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _PhotoSlot(
                        locationId: location.id,
                        label: '改修前',
                        slot: ProjectPhotoSlot.before,
                        photo: location.beforePhoto,
                        memo: location.beforeMemo,
                        busy: isBusy(ProjectPhotoSlot.before),
                        onTap: () => onCapture(ProjectPhotoSlot.before),
                        onMemoChanged: (value) =>
                            onMemoChanged(ProjectPhotoSlot.before, value),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _PhotoSlot(
                        locationId: location.id,
                        label: '改修後',
                        slot: ProjectPhotoSlot.after,
                        photo: location.afterPhoto,
                        memo: location.afterMemo,
                        busy: isBusy(ProjectPhotoSlot.after),
                        onTap: () => onCapture(ProjectPhotoSlot.after),
                        onMemoChanged: (value) =>
                            onMemoChanged(ProjectPhotoSlot.after, value),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhotoSlot extends StatelessWidget {
  const _PhotoSlot({
    required this.locationId,
    required this.label,
    required this.slot,
    required this.photo,
    required this.memo,
    required this.busy,
    required this.onTap,
    required this.onMemoChanged,
  });

  final String locationId;
  final String label;
  final ProjectPhotoSlot slot;
  final CapturedProjectPhoto? photo;
  final String memo;
  final bool busy;
  final VoidCallback onTap;
  final ValueChanged<String> onMemoChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final imageBytes = _decode(photo?.base64Data);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 7),
        Expanded(
          child: Semantics(
            button: true,
            label: imageBytes == null ? '$labelの写真を撮影' : '$labelの写真を再撮影',
            child: Material(
              color: colors.surfaceContainerHighest,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: colors.outlineVariant),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                key: ValueKey('photo-${slot.name}-$locationId'),
                onTap: busy ? null : onTap,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (imageBytes != null)
                      Padding(
                        key: ValueKey(
                          'photo-image-padding-${slot.name}-$locationId',
                        ),
                        padding: const EdgeInsets.all(8),
                        child: Image.memory(
                          imageBytes,
                          key: ValueKey('photo-image-${slot.name}-$locationId'),
                          fit: BoxFit.contain,
                          gaplessPlayback: true,
                        ),
                      )
                    else
                      Center(
                        child: Icon(
                          CupertinoIcons.add_circled,
                          size: 34,
                          color: colors.primary,
                        ),
                      ),
                    if (imageBytes != null)
                      Positioned(
                        right: 8,
                        bottom: 8,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: colors.surface.withValues(alpha: .9),
                            shape: BoxShape.circle,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Icon(
                              CupertinoIcons.camera_fill,
                              size: 20,
                              color: colors.primary,
                            ),
                          ),
                        ),
                      ),
                    if (busy)
                      ColoredBox(
                        color: colors.surface.withValues(alpha: .72),
                        child: const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CupertinoActivityIndicator(radius: 14),
                              SizedBox(height: 9),
                              Text('写真を処理中'),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          key: ValueKey('photo-memo-${slot.name}-$locationId'),
          initialValue: memo,
          minLines: 1,
          maxLines: 2,
          textInputAction: TextInputAction.newline,
          onChanged: onMemoChanged,
          decoration: const InputDecoration(
            labelText: 'メモ',
            isDense: true,
            border: OutlineInputBorder(),
          ),
        ),
      ],
    );
  }

  Uint8List? _decode(String? data) {
    if (data == null || data.isEmpty) return null;
    try {
      return base64Decode(data);
    } on FormatException {
      return null;
    }
  }
}
