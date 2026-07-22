import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import '../photo_capture_session.dart';
import 'app_shell.dart';
import 'products_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.state});

  final AppState state;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_resumePendingPhotoCapture());
    });
  }

  Future<void> _resumePendingPhotoCapture() async {
    final pending = await PhotoCaptureSession.read();
    if (!mounted || pending == null) return;
    final project = widget.state.projects
        .where((item) => item.id == pending.projectId)
        .firstOrNull;
    if (project == null) {
      await PhotoCaptureSession.clear();
      return;
    }
    _openProject(context, project, initialIndex: AppShell.photosTabIndex);
  }

  void _openProject(
    BuildContext context,
    RenovationProject project, {
    int initialIndex = AppShell.drawingTabIndex,
  }) {
    widget.state.selectProject(project.id);
    Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) =>
            AppShell(state: widget.state, initialIndex: initialIndex),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.state,
      builder: (context, _) => Scaffold(
        appBar: CupertinoNavigationBar(
          automaticallyImplyLeading: false,
          middle: const Text('住宅改修'),
          trailing: index == 0
              ? Tooltip(
                  message: '案件を追加',
                  child: CupertinoButton(
                    key: const ValueKey('add-project'),
                    padding: EdgeInsets.zero,
                    onPressed: () =>
                        _openProject(context, widget.state.createProject()),
                    child: const Icon(CupertinoIcons.add),
                  ),
                )
              : null,
        ),
        body: Column(
          children: [
            Material(
              color: Theme.of(context).colorScheme.surface,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: SizedBox(
                      width: double.infinity,
                      child: CupertinoSlidingSegmentedControl<int>(
                        key: const ValueKey('top-navigation'),
                        groupValue: index,
                        children: const {
                          0: Padding(
                            key: ValueKey('top-menu-projects'),
                            padding: EdgeInsets.symmetric(vertical: 7),
                            child: Text('案件'),
                          ),
                          1: Padding(
                            key: ValueKey('top-menu-products'),
                            padding: EdgeInsets.symmetric(vertical: 7),
                            child: Text('商品マスター'),
                          ),
                        },
                        onValueChanged: (value) {
                          if (value == null) return;
                          FocusManager.instance.primaryFocus?.unfocus();
                          setState(() => index = value);
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: IndexedStack(
                index: index,
                children: [
                  _ProjectsView(
                    state: widget.state,
                    onOpenProject: (project) => _openProject(context, project),
                  ),
                  ProductsScreen(state: widget.state),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProjectsView extends StatelessWidget {
  const _ProjectsView({required this.state, required this.onOpenProject});

  final AppState state;
  final ValueChanged<RenovationProject> onOpenProject;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          itemCount: state.projects.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final project = state.projects[index];
            return _ProjectCard(
              key: ValueKey('project-${project.id}'),
              project: project,
              onTap: () => onOpenProject(project),
            );
          },
        ),
      ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({super.key, required this.project, required this.onTap});

  final RenovationProject project;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final customer = project.customer;
    final title = customer.projectName.trim().isEmpty
        ? '工事名未設定'
        : customer.projectName.trim();
    final name = customer.name.trim().isEmpty
        ? 'お客様名未設定'
        : customer.name.trim();
    final place = customer.constructionPlace.trim().isEmpty
        ? '工事場所未設定'
        : customer.constructionPlace.trim();

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _ProjectDetail(icon: CupertinoIcons.person, label: name),
                    const SizedBox(height: 8),
                    _ProjectDetail(icon: CupertinoIcons.location, label: place),
                    const SizedBox(height: 8),
                    _ProjectDetail(
                      icon: CupertinoIcons.time,
                      label: '最終更新 ${_formatDateTime(project.updatedAt)}',
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(CupertinoIcons.chevron_forward),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProjectDetail extends StatelessWidget {
  const _ProjectDetail({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 18,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ),
      ],
    );
  }
}

String _formatDateTime(DateTime value) {
  final local = value.toLocal();
  String twoDigits(int number) => number.toString().padLeft(2, '0');
  return '${local.year}/${twoDigits(local.month)}/${twoDigits(local.day)} '
      '${twoDigits(local.hour)}:${twoDigits(local.minute)}';
}
