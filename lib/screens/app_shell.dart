import 'package:flutter/material.dart';

import '../app_state.dart';
import 'basic_info_screen.dart';
import 'documents_screen.dart';
import 'drawing_screen.dart';
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

  static const titles = ['基本情報', '品番', '施工箇所図面', '書類'];

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
          appBar: AppBar(
            leading: BackButton(onPressed: _handleBack),
            titleSpacing: 8,
            toolbarHeight: 64,
            title: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: const Text(
                    '改',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(titles[index], overflow: TextOverflow.ellipsis),
                      Text(
                        widget.state.customer.projectName.trim().isEmpty
                            ? '工事名未設定'
                            : widget.state.customer.projectName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.black54,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          body: IndexedStack(
            index: index,
            children: [
              BasicInfoScreen(state: widget.state),
              ProductsScreen(state: widget.state),
              DrawingScreen(state: widget.state),
              DocumentsScreen(state: widget.state, onOpenDrawing: _openDrawing),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: index,
            onDestinationSelected: (value) {
              FocusManager.instance.primaryFocus?.unfocus();
              setState(() => index = value);
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.badge_outlined),
                selectedIcon: Icon(Icons.badge),
                label: '基本情報',
              ),
              NavigationDestination(
                icon: Icon(Icons.inventory_2_outlined),
                selectedIcon: Icon(Icons.inventory_2),
                label: '品番',
              ),
              NavigationDestination(
                icon: Icon(Icons.architecture_outlined),
                selectedIcon: Icon(Icons.architecture),
                label: '図面',
              ),
              NavigationDestination(
                icon: Icon(Icons.request_quote_outlined),
                selectedIcon: Icon(Icons.request_quote),
                label: '書類',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
