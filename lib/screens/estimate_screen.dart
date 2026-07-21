import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../app_state.dart';
import '../controller_disposal_scope.dart';
import '../formatters.dart';
import '../models.dart';

class MaterialCostSection extends StatelessWidget {
  const MaterialCostSection({
    super.key,
    required this.state,
    required this.onOpenDrawing,
    required this.onEditGroup,
  });

  final AppState state;
  final VoidCallback onOpenDrawing;
  final ValueChanged<HandrailEstimateGroup> onEditGroup;

  @override
  Widget build(BuildContext context) {
    final groups = state.handrailEstimateGroups();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '手すり材料原価 ${groups.length}件',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            OutlinedButton.icon(
              onPressed: onOpenDrawing,
              icon: const Icon(CupertinoIcons.square_grid_2x2, size: 19),
              label: const Text('図面を開く'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (groups.isEmpty)
          const _EmptyEstimate()
        else
          ...groups.map(
            (group) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _EstimateLine(
                group: group,
                state: state,
                onTap: () => onEditGroup(group),
              ),
            ),
          ),
        const SizedBox(height: 4),
        _MaterialTotal(total: state.materialCostTotal),
      ],
    );
  }
}

class _EstimateLine extends StatelessWidget {
  const _EstimateLine({
    required this.group,
    required this.state,
    required this.onTap,
  });

  final HandrailEstimateGroup group;
  final AppState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final line = group.primary;
    final product = state.productById(line.productId);
    final cost = state.costForGroup(group);
    final path = state.handrailPath(line);
    final place = group.lines
        .map(state.handrailPlace)
        .firstWhere((value) => value != '場所未設定', orElse: () => '場所未設定');
    return Card(
      key: ValueKey('material-cost-${group.id}'),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'No.${state.constructionNumberFor(line)}  $place',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          product == null
                              ? '商品未選択'
                              : '${product.id}  ${product.name}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    formatYen(cost.total),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Icon(CupertinoIcons.chevron_forward, size: 20),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 14,
                runSpacing: 4,
                children: [
                  _meta(context, Icons.straighten, '${group.lengthMm}mm'),
                  _meta(
                    context,
                    Icons.swap_horiz,
                    group.isConnected
                        ? 'L字'
                        : (path.orientation ?? line.orientation).label,
                  ),
                  if (group.isConnected)
                    _meta(
                      context,
                      Icons.account_tree_outlined,
                      '構成 ${group.lines.length}本',
                    ),
                  _meta(context, Icons.home_outlined, line.environment.label),
                  _meta(
                    context,
                    Icons.build_outlined,
                    line.installationType.label,
                  ),
                  _meta(
                    context,
                    Icons.radio_button_checked,
                    'ジョイント ${cost.jointCount}個',
                  ),
                  _meta(
                    context,
                    Icons.vertical_align_bottom,
                    '柱 ${cost.postCount}本',
                  ),
                ],
              ),
              const Divider(height: 20),
              _CostRow(label: '手すり本体', value: cost.railCost),
              _CostRow(label: 'ジョイント', value: cost.jointCost),
              _CostRow(label: '柱', value: cost.postCost),
              const SizedBox(height: 4),
              _CostRow(label: '材料原価合計', value: cost.total, strong: true),
            ],
          ),
        ),
      ),
    );
  }

  Widget _meta(BuildContext context, IconData icon, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(
        icon,
        size: 15,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      const SizedBox(width: 4),
      Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    ],
  );
}

class _CostRow extends StatelessWidget {
  const _CostRow({
    required this.label,
    required this.value,
    this.strong = false,
  });

  final String label;
  final int value;
  final bool strong;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontWeight: strong ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ),
        Text(
          formatYen(value),
          style: TextStyle(
            fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

class _MaterialTotal extends StatelessWidget {
  const _MaterialTotal({required this.total});

  final int total;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '材料原価合計',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          Text(
            formatYen(total),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    ),
  );
}

class _EmptyEstimate extends StatelessWidget {
  const _EmptyEstimate();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 20),
    decoration: BoxDecoration(
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      children: [
        Icon(
          CupertinoIcons.pencil_outline,
          size: 36,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(height: 10),
        const Text('図面に手すりを追加すると材料原価が表示されます', textAlign: TextAlign.center),
      ],
    ),
  );
}

Future<void> showWorkLineEditor(
  BuildContext context,
  AppState state,
  WorkLine line,
) async {
  final initialPlace = state.handrailPlace(line);
  final place = TextEditingController(
    text: initialPlace == '場所未設定' ? '' : initialPlace,
  );
  final constructionNumber = TextEditingController(
    text: state.constructionNumberFor(line),
  );
  final length = TextEditingController(text: '${line.lengthMm}');
  final note = TextEditingController(text: line.note);
  var environment = line.environment;
  var installationType = line.installationType;
  var productId = line.productId;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => ControllerDisposalScope(
      controllers: [place, constructionNumber, length, note],
      builder: (_) => StatefulBuilder(
        builder: (context, setSheetState) {
          final products = state.productsFor(environment);
          if (!products.any((product) => product.id == productId)) {
            productId = state.defaultProductIdFor(environment);
          }
          final previewLength = parseInt(length.text).clamp(
            AppState.gridMm,
            line.isHorizontal ? state.canvasWidthMm : state.canvasHeightMm,
          );
          final horizontalDirection = line.x2Mm >= line.x1Mm ? 1 : -1;
          final verticalDirection = line.y2Mm >= line.y1Mm ? 1 : -1;
          final preview = WorkLine(
            id: line.id,
            place: place.text,
            x1Mm: line.x1Mm,
            y1Mm: line.y1Mm,
            x2Mm: line.isHorizontal
                ? line.x1Mm + horizontalDirection * previewLength
                : line.x1Mm,
            y2Mm: line.isHorizontal
                ? line.y1Mm
                : line.y1Mm + verticalDirection * previewLength,
            productId: productId,
            environment: environment,
            installationType: installationType,
          );
          final previewCost = state.costFor(preview);

          return Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              18,
              20,
              20 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '手すりを編集',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: constructionNumber,
                          decoration: const InputDecoration(
                            labelText: '施工箇所番号',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: place,
                          decoration: const InputDecoration(labelText: '設置場所'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<HandrailEnvironment>(
                    initialValue: environment,
                    decoration: const InputDecoration(labelText: '設置環境'),
                    items: HandrailEnvironment.values
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(value.label),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setSheetState(() {
                        environment = value;
                        installationType = value == HandrailEnvironment.outdoor
                            ? HandrailInstallationType.freestanding
                            : HandrailInstallationType.wallMounted;
                        productId = state.defaultProductIdFor(value);
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  Text('設置方式', style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 7),
                  SegmentedButton<HandrailInstallationType>(
                    segments: HandrailInstallationType.values
                        .map(
                          (value) => ButtonSegment(
                            value: value,
                            label: Text(value.label),
                            icon: Icon(
                              value == HandrailInstallationType.wallMounted
                                  ? Icons.wallpaper
                                  : Icons.vertical_align_bottom,
                            ),
                          ),
                        )
                        .toList(),
                    selected: {installationType},
                    onSelectionChanged: (selection) =>
                        setSheetState(() => installationType = selection.first),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    key: ValueKey('product-${environment.name}-$productId'),
                    initialValue:
                        products.any((product) => product.id == productId)
                        ? productId
                        : null,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: '品番'),
                    items: products
                        .map(
                          (product) => DropdownMenuItem(
                            value: product.id,
                            child: Text(
                              '${product.id}  ${product.name}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: products.isEmpty
                        ? null
                        : (value) => setSheetState(() => productId = value),
                  ),
                  if (products.isEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      '${environment.label}対応の商品を商品画面で登録してください',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    controller: length,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '長さ',
                      suffixText: 'mm',
                    ),
                    onChanged: (_) => setSheetState(() {}),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: note,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: '備考'),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        _PreviewRow(
                          label: 'ジョイント',
                          value: '${previewCost.jointCount}個',
                        ),
                        _PreviewRow(
                          label: '柱',
                          value: '${previewCost.postCount}本',
                        ),
                        _PreviewRow(
                          label: '材料原価',
                          value: formatYen(previewCost.total),
                          strong: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: () {
                      state.checkpoint();
                      state.setConstructionNumberForGroup(
                        line,
                        constructionNumber.text.trim().isEmpty
                            ? state.constructionNumberFor(line)
                            : constructionNumber.text.trim(),
                      );
                      line.place = place.text.trim();
                      line.note = note.text.trim();
                      state.setLineLength(line, parseInt(length.text));
                      state.applyHandrailSettings(
                        line,
                        environment: environment,
                        installationType: installationType,
                        productId: productId,
                      );
                      state.changed();
                      Navigator.pop(sheetContext);
                    },
                    icon: const Icon(CupertinoIcons.check_mark),
                    label: const Text('反映する'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () {
                      state.select(line.id);
                      state.deleteSelected();
                      Navigator.pop(sheetContext);
                    },
                    icon: const Icon(CupertinoIcons.trash),
                    label: const Text('この手すりを削除'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ),
  );
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({
    required this.label,
    required this.value,
    this.strong = false,
  });

  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(fontWeight: strong ? FontWeight.w700 : null),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}
