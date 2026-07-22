import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../app_state.dart';
import 'basic_info_screen.dart';
import 'documents_screen.dart';
import 'drawing_screen.dart';
import 'photos_screen.dart';
import 'products_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.state});

  final AppState state;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  static const drawingIndex = 2;

  int index = drawingIndex;

  static const titles = ['基本情報', '品番', '施工箇所図面', '写真', '書類'];

  void _openDrawing() {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => index = drawingIndex);
  }

  void _handleBack() {
    if (index != drawingIndex) {
      _openDrawing();
      return;
    }
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.state,
      builder: (context, _) => PopScope<void>(
        canPop: index == drawingIndex,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && index != drawingIndex) {
            _openDrawing();
          }
        },
        child: Scaffold(
          appBar: CupertinoNavigationBar(
            automaticallyImplyLeading: false,
            leading: Tooltip(
              message: index == drawingIndex ? '案件一覧へ戻る' : '図面へ戻る',
              child: CupertinoButton(
                key: const ValueKey('project-back-button'),
                padding: EdgeInsets.zero,
                onPressed: _handleBack,
                child: const Icon(CupertinoIcons.chevron_left),
              ),
            ),
            middle: Text(titles[index], overflow: TextOverflow.ellipsis),
          ),
          body: IndexedStack(
            index: index,
            children: [
              BasicInfoScreen(state: widget.state),
              ProductsScreen(state: widget.state),
              DrawingScreen(state: widget.state),
              PhotosScreen(state: widget.state),
              DocumentsScreen(state: widget.state, onOpenDrawing: _openDrawing),
            ],
          ),
          bottomNavigationBar: CupertinoTabBar(
            key: const ValueKey('project-tab-bar'),
            currentIndex: index,
            onTap: (value) {
              FocusManager.instance.primaryFocus?.unfocus();
              setState(() => index = value);
            },
            items: const [
              BottomNavigationBarItem(
                icon: Icon(CupertinoIcons.person_crop_rectangle),
                activeIcon: Icon(CupertinoIcons.person_crop_rectangle_fill),
                label: '基本情報',
              ),
              BottomNavigationBarItem(
                icon: Icon(CupertinoIcons.cube_box),
                activeIcon: Icon(CupertinoIcons.cube_box_fill),
                label: '品番',
              ),
              BottomNavigationBarItem(
                icon: Icon(CupertinoIcons.square_grid_2x2),
                activeIcon: Icon(CupertinoIcons.square_grid_2x2_fill),
                label: '図面',
              ),
              BottomNavigationBarItem(
                icon: Icon(CupertinoIcons.camera),
                activeIcon: Icon(CupertinoIcons.camera_fill),
                label: '写真',
              ),
              BottomNavigationBarItem(
                icon: Icon(CupertinoIcons.doc_text),
                activeIcon: Icon(CupertinoIcons.doc_text_fill),
                label: '書類',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
