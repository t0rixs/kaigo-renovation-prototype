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
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showProductForm(context),
        icon: const Icon(Icons.add),
        label: const Text('商品を追加'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 96),
        children: [
          Text(
            'デフォルト品番',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
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
            '手すり本体・ジョイント・柱の材料単価を管理します',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.black54),
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
        ],
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    HandrailProduct product,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('商品を削除'),
        content: Text('${product.id} ${product.name}を削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
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
    final jointPrice = TextEditingController(
      text: '${product?.jointPrice ?? 0}',
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
        controllers: [
          id,
          name,
          diameter,
          railPrice,
          jointPrice,
          postPrice,
          interval,
        ],
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
                    jointPrice: jointPrice,
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
                        jointPrice: parseInt(
                          jointPrice.text,
                        ).clamp(0, 100000000),
                        postPrice: parseInt(postPrice.text).clamp(0, 100000000),
                        maxJointIntervalMm: maxInterval,
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
                    icon: Icon(product == null ? Icons.add : Icons.check),
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
        padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFE5F1FA),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Text(
                'φ${product.diameterMm}',
                style: const TextStyle(
                  color: Color(0xFF1769AA),
                  fontSize: 12,
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
                    'ジョイント ${formatYen(product.jointPrice)}/個  '
                    '柱 ${formatYen(product.postPrice)}/本',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: '編集',
              icon: const Icon(Icons.edit_outlined),
              onPressed: onEdit,
            ),
            IconButton(
              tooltip: state.isProductInUse(product) ? '図面で使用中です' : '削除',
              icon: const Icon(Icons.delete_outline),
              onPressed: state.isProductInUse(product) ? null : onDelete,
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
    required this.jointPrice,
    required this.postPrice,
    required this.interval,
  });

  final TextEditingController diameter;
  final TextEditingController railPrice;
  final TextEditingController jointPrice;
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
      Row(
        children: [
          Expanded(child: _field(jointPrice, 'ジョイント単価', '円/個')),
          const SizedBox(width: 10),
          Expanded(child: _field(postPrice, '柱単価', '円/本')),
        ],
      ),
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
