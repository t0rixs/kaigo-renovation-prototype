import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
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

  void _openProject(BuildContext context, RenovationProject project) {
    widget.state.selectProject(project.id);
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => AppShell(state: widget.state)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.state,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: const Text('住宅改修')),
        floatingActionButton: index == 0
            ? FloatingActionButton.extended(
                heroTag: 'add-project',
                onPressed: () =>
                    _openProject(context, widget.state.createProject()),
                icon: const Icon(Icons.add),
                label: const Text('案件を追加'),
              )
            : null,
        body: Column(
          children: [
            NavigationBar(
              key: const ValueKey('top-navigation'),
              selectedIndex: index,
              onDestinationSelected: (value) {
                FocusManager.instance.primaryFocus?.unfocus();
                setState(() => index = value);
              },
              destinations: const [
                NavigationDestination(
                  key: ValueKey('top-menu-projects'),
                  icon: Icon(Icons.folder_copy_outlined),
                  selectedIcon: Icon(Icons.folder_copy),
                  label: '案件',
                ),
                NavigationDestination(
                  key: ValueKey('top-menu-products'),
                  icon: Icon(Icons.inventory_2_outlined),
                  selectedIcon: Icon(Icons.inventory_2),
                  label: '商品マスター',
                ),
              ],
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
                    _ProjectDetail(icon: Icons.person_outline, label: name),
                    const SizedBox(height: 8),
                    _ProjectDetail(
                      icon: Icons.location_on_outlined,
                      label: place,
                    ),
                    const SizedBox(height: 8),
                    _ProjectDetail(
                      icon: Icons.schedule,
                      label: '最終更新 ${_formatDateTime(project.updatedAt)}',
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(Icons.chevron_right),
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
        Icon(icon, size: 18, color: Colors.black54),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.black87),
          ),
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
