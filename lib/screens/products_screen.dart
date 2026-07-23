import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../app_state.dart';
import '../controller_disposal_scope.dart';
import '../formatters.dart';
import '../models.dart';

class ProductsScreen extends StatelessWidget {
  const ProductsScreen({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 36),
      children: [
        Text(
          'デフォルト品番',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        Wrap(
          alignment: WrapAlignment.end,
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.tonalIcon(
              key: const ValueKey('add-product'),
              onPressed: () => _showProductForm(context),
              icon: const Icon(CupertinoIcons.add),
              label: const Text('手すり追加'),
            ),
            FilledButton.tonalIcon(
              key: const ValueKey('add-joint-product'),
              onPressed: () => _showJointProductForm(context),
              icon: const Icon(CupertinoIcons.add),
              label: const Text('部品追加'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 620;
                final selectors = [
                  _DefaultProductSelector(
                    state: state,
                    environment: HandrailEnvironment.indoor,
                  ),
                  _DefaultProductSelector(
                    state: state,
                    environment: HandrailEnvironment.outdoor,
                  ),
                ];
                if (wide) {
                  return Row(
                    children: [
                      Expanded(child: selectors[0]),
                      const SizedBox(width: 12),
                      Expanded(child: selectors[1]),
                    ],
                  );
                }
                return Column(
                  children: [
                    selectors[0],
                    const SizedBox(height: 12),
                    selectors[1],
                  ],
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 22),
        Text(
          '手すり商品 ${state.products.length}件',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          '手すり本体と柱の材料単価、使用する標準部品を管理します',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        if (state.products.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('商品が登録されていません')),
            ),
          )
        else
          ...state.products.map(
            (product) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ProductCard(
                state: state,
                product: product,
                onEdit: () => _showProductForm(context, product: product),
                onDelete: () => _confirmDelete(context, product),
              ),
            ),
          ),
        const SizedBox(height: 14),
        _JointProductSection(
          title: '端部ブラケット',
          products: state.sortedJointProducts
              .where((item) => item.type == JointProductType.endBracket)
              .toList(),
          state: state,
          onEdit: (product) => _showJointProductForm(context, product: product),
          onDelete: (product) => _confirmJointDelete(context, product),
        ),
        _JointProductSection(
          title: '中受ブラケット',
          products: state.sortedJointProducts
              .where(
                (item) => item.type == JointProductType.intermediateBracket,
              )
              .toList(),
          state: state,
          onEdit: (product) => _showJointProductForm(context, product: product),
          onDelete: (product) => _confirmJointDelete(context, product),
        ),
        _JointProductSection(
          title: '接続ジョイント',
          products: state.sortedJointProducts
              .where((item) => item.type.isConnection)
              .toList(),
          state: state,
          onEdit: (product) => _showJointProductForm(context, product: product),
          onDelete: (product) => _confirmJointDelete(context, product),
        ),
      ],
    );
  }

  Future<void> _confirmJointDelete(
    BuildContext context,
    JointProduct product,
  ) async {
    final result = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('部品を削除'),
        content: Text('${product.id} ${product.name}を削除しますか？'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, true),
            child: const Text('削除'),
          ),
        ],
      ),
    );
    if (result == true) state.deleteJointProduct(product);
  }

  Future<void> _confirmDelete(
    BuildContext context,
    HandrailProduct product,
  ) async {
    final result = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('商品を削除'),
        content: Text('${product.id} ${product.name}を削除しますか？'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, true),
            child: const Text('削除'),
          ),
        ],
      ),
    );
    if (result == true) state.deleteProduct(product);
  }

  Future<void> _showProductForm(
    BuildContext context, {
    HandrailProduct? product,
  }) async {
    final id = TextEditingController(text: product?.id ?? '');
    final name = TextEditingController(text: product?.name ?? '');
    final diameter = TextEditingController(
      text: '${product?.diameterMm ?? 35}',
    );
    final railPrice = TextEditingController(
      text: '${product?.railPricePerMeter ?? 0}',
    );
    final postPrice = TextEditingController(text: '${product?.postPrice ?? 0}');
    final interval = TextEditingController(
      text: '${product?.maxJointIntervalMm ?? 1000}',
    );
    var indoor = product?.supports(HandrailEnvironment.indoor) ?? true;
    var outdoor = product?.supports(HandrailEnvironment.outdoor) ?? false;
    String? error;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => ControllerDisposalScope(
        controllers: [id, name, diameter, railPrice, postPrice, interval],
        builder: (_) => StatefulBuilder(
          builder: (context, setSheetState) => Padding(
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
                    product == null ? '手すり商品を追加' : '手すり商品を編集',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: id,
                    enabled: product == null,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(labelText: '品番'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: name,
                    decoration: const InputDecoration(labelText: '商品名'),
                  ),
                  const SizedBox(height: 14),
                  Text('対応環境', style: Theme.of(context).textTheme.labelLarge),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: indoor,
                    title: const Text('屋内'),
                    controlAffinity: ListTileControlAffinity.leading,
                    onChanged: (value) =>
                        setSheetState(() => indoor = value ?? false),
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: outdoor,
                    title: const Text('屋外'),
                    controlAffinity: ListTileControlAffinity.leading,
                    onChanged: (value) =>
                        setSheetState(() => outdoor = value ?? false),
                  ),
                  const SizedBox(height: 4),
                  _NumberFields(
                    diameter: diameter,
                    railPrice: railPrice,
                    postPrice: postPrice,
                    interval: interval,
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: () {
                      final productId = id.text.trim();
                      final productName = name.text.trim();
                      final diameterMm = parseInt(diameter.text);
                      final maxInterval = parseInt(interval.text);
                      if (productId.isEmpty || productName.isEmpty) {
                        setSheetState(() => error = '品番と商品名を入力してください');
                        return;
                      }
                      if (!indoor && !outdoor) {
                        setSheetState(() => error = '対応環境を1つ以上選択してください');
                        return;
                      }
                      if (diameterMm <= 0 || maxInterval <= 0) {
                        setSheetState(
                          () => error = '直径と最大ジョイント間隔は1以上で入力してください',
                        );
                        return;
                      }
                      final replacement = HandrailProduct(
                        id: productId,
                        name: productName,
                        environmentTags: {
                          if (indoor) HandrailEnvironment.indoor,
                          if (outdoor) HandrailEnvironment.outdoor,
                        },
                        diameterMm: diameterMm,
                        railPricePerMeter: parseInt(
                          railPrice.text,
                        ).clamp(0, 100000000),
                        postPrice: parseInt(postPrice.text).clamp(0, 100000000),
                        maxJointIntervalMm: maxInterval,
                        defaultEndBracketId: product?.defaultEndBracketId,
                        defaultIntermediateBracketId:
                            product?.defaultIntermediateBracketId,
                        defaultLJointId: product?.defaultLJointId,
                      );
                      if (product == null) {
                        if (!state.addProduct(replacement)) {
                          setSheetState(() => error = '同じ品番が登録されています');
                          return;
                        }
                      } else {
                        state.updateProduct(product, replacement);
                      }
                      Navigator.pop(sheetContext);
                    },
                    icon: Icon(
                      product == null
                          ? CupertinoIcons.add
                          : CupertinoIcons.check_mark,
                    ),
                    label: Text(product == null ? '追加する' : '変更を保存'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showJointProductForm(
    BuildContext context, {
    JointProduct? product,
  }) async {
    final id = TextEditingController(text: product?.id ?? '');
    final name = TextEditingController(text: product?.name ?? '');
    final unitPrice = TextEditingController(text: '${product?.unitPrice ?? 0}');
    var type = product?.type ?? JointProductType.endBracket;
    String? error;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => ControllerDisposalScope(
        controllers: [id, name, unitPrice],
        builder: (_) => StatefulBuilder(
          builder: (context, setSheetState) => Padding(
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
                    product == null ? '部品を追加' : '部品を編集',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: id,
                    enabled: product == null,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(labelText: '品番'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: name,
                    decoration: const InputDecoration(labelText: '品名'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<JointProductType>(
                    initialValue: type,
                    decoration: const InputDecoration(labelText: '部品種別'),
                    items: JointProductType.values
                        .map(
                          (item) => DropdownMenuItem(
                            value: item,
                            child: Text(item.label),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) setSheetState(() => type = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: unitPrice,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '単価',
                      suffixText: '円/個',
                    ),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: () {
                      final productId = id.text.trim();
                      final productName = name.text.trim();
                      if (productId.isEmpty || productName.isEmpty) {
                        setSheetState(() => error = '品番と品名を入力してください');
                        return;
                      }
                      final replacement = JointProduct(
                        id: productId,
                        name: productName,
                        type: type,
                        unitPrice: parseInt(unitPrice.text).clamp(0, 100000000),
                      );
                      if (product == null) {
                        if (!state.addJointProduct(replacement)) {
                          setSheetState(() => error = '同じ品番が登録されています');
                          return;
                        }
                      } else {
                        state.updateJointProduct(product, replacement);
                      }
                      Navigator.pop(sheetContext);
                    },
                    icon: Icon(
                      product == null
                          ? CupertinoIcons.add
                          : CupertinoIcons.check_mark,
                    ),
                    label: Text(product == null ? '追加する' : '変更を保存'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DefaultProductSelector extends StatelessWidget {
  const _DefaultProductSelector({
    required this.state,
    required this.environment,
  });

  final AppState state;
  final HandrailEnvironment environment;

  @override
  Widget build(BuildContext context) {
    final products = state.productsFor(environment);
    final selected = state.defaultProductIdFor(environment);
    return DropdownButtonFormField<String>(
      initialValue: products.any((product) => product.id == selected)
          ? selected
          : null,
      decoration: InputDecoration(labelText: '${environment.label}デフォルト'),
      items: products
          .map(
            (product) => DropdownMenuItem(
              value: product.id,
              child: Text(product.name, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: products.isEmpty
          ? null
          : (value) => state.setDefaultProduct(environment, value),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.state,
    required this.product,
    required this.onEdit,
    required this.onDelete,
  });

  final AppState state;
  final HandrailProduct product;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final environments = product.environmentTags
        .map((tag) => tag.label)
        .join('・');
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Text(
                    'φ${product.diameterMm}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.id,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 2),
                      Text(product.name),
                      const SizedBox(height: 5),
                      Text(
                        '$environments  /  最大間隔 ${product.maxJointIntervalMm}mm',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '手すり ${formatYen(product.railPricePerMeter)}/m  '
                        '柱 ${formatYen(product.postPrice)}/本',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: '編集',
                  icon: const Icon(CupertinoIcons.pencil),
                  onPressed: onEdit,
                ),
                IconButton(
                  tooltip: state.isProductInUse(product) ? '図面で使用中です' : '削除',
                  icon: const Icon(CupertinoIcons.trash),
                  onPressed: state.isProductInUse(product) ? null : onDelete,
                ),
              ],
            ),
            const Divider(height: 22),
            LayoutBuilder(
              builder: (context, constraints) {
                final selectors = [
                  _ProductJointSelector(
                    key: ValueKey('product-${product.id}-end-bracket'),
                    state: state,
                    product: product,
                    type: JointProductType.endBracket,
                    label: '端部ブラケット',
                    selectedId: product.defaultEndBracketId,
                  ),
                  _ProductJointSelector(
                    key: ValueKey('product-${product.id}-middle-bracket'),
                    state: state,
                    product: product,
                    type: JointProductType.intermediateBracket,
                    label: '中受ブラケット',
                    selectedId: product.defaultIntermediateBracketId,
                  ),
                  _ProductJointSelector(
                    key: ValueKey('product-${product.id}-l-joint'),
                    state: state,
                    product: product,
                    type: JointProductType.lShapeConnection,
                    label: 'L字接続ジョイント',
                    selectedId: product.defaultLJointId,
                  ),
                ];
                if (constraints.maxWidth >= 760) {
                  return Row(
                    children: [
                      Expanded(child: selectors[0]),
                      const SizedBox(width: 10),
                      Expanded(child: selectors[1]),
                      const SizedBox(width: 10),
                      Expanded(child: selectors[2]),
                    ],
                  );
                }
                return Column(
                  children: [
                    selectors[0],
                    const SizedBox(height: 10),
                    selectors[1],
                    const SizedBox(height: 10),
                    selectors[2],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _NumberFields extends StatelessWidget {
  const _NumberFields({
    required this.diameter,
    required this.railPrice,
    required this.postPrice,
    required this.interval,
  });

  final TextEditingController diameter;
  final TextEditingController railPrice;
  final TextEditingController postPrice;
  final TextEditingController interval;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Row(
        children: [
          Expanded(child: _field(diameter, '直径', 'mm')),
          const SizedBox(width: 10),
          Expanded(child: _field(interval, '最大ジョイント間隔', 'mm')),
        ],
      ),
      const SizedBox(height: 12),
      _field(railPrice, '手すり単価', '円/m'),
      const SizedBox(height: 12),
      _field(postPrice, '柱単価', '円/本'),
    ],
  );

  Widget _field(
    TextEditingController controller,
    String label,
    String suffix,
  ) => TextField(
    controller: controller,
    keyboardType: TextInputType.number,
    decoration: InputDecoration(labelText: label, suffixText: suffix),
  );
}

class _ProductJointSelector extends StatelessWidget {
  const _ProductJointSelector({
    super.key,
    required this.state,
    required this.product,
    required this.type,
    required this.label,
    required this.selectedId,
  });

  final AppState state;
  final HandrailProduct product;
  final JointProductType type;
  final String label;
  final String? selectedId;

  @override
  Widget build(BuildContext context) {
    final options = state.jointProductsForType(type);
    final value = options.any((item) => item.id == selectedId)
        ? selectedId
        : null;
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: options
          .map(
            (item) => DropdownMenuItem(
              value: item.id,
              child: Text(
                '${item.id}  ${item.name}',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
      onChanged: options.isEmpty
          ? null
          : (value) => state.setProductDefaultJoint(product, type, value),
    );
  }
}

class _JointProductSection extends StatelessWidget {
  const _JointProductSection({
    required this.title,
    required this.products,
    required this.state,
    required this.onEdit,
    required this.onDelete,
  });

  final String title;
  final List<JointProduct> products;
  final AppState state;
  final ValueChanged<JointProduct> onEdit;
  final ValueChanged<JointProduct> onDelete;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '$title ${products.length}件',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        if (products.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('登録された部品はありません'),
          )
        else
          ...products.map(
            (product) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Card(
                child: ListTile(
                  title: Text(
                    product.id,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 2),
                      Text(product.name),
                      const SizedBox(height: 2),
                      Text(
                        '種別: ${product.type.shortLabel}  /  '
                        '${formatYen(product.unitPrice)}/個',
                      ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: '編集',
                        icon: const Icon(CupertinoIcons.pencil),
                        onPressed: () => onEdit(product),
                      ),
                      IconButton(
                        tooltip: state.isJointProductInUse(product)
                            ? '手すり商品の標準部品です'
                            : '削除',
                        icon: const Icon(CupertinoIcons.trash),
                        onPressed: state.isJointProductInUse(product)
                            ? null
                            : () => onDelete(product),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}
