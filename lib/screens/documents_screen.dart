import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_state.dart';
import '../documents/document_export_data.dart';
import '../documents/excel_export_service.dart';
import '../formatters.dart';
import '../models.dart';
import 'estimate_screen.dart';

enum _DocumentPage { cost, quote }

class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({
    super.key,
    required this.state,
    required this.onOpenDrawing,
  });

  final AppState state;
  final VoidCallback onOpenDrawing;

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  late final TextEditingController costItemName;
  late final TextEditingController paymentTerms;
  late final TextEditingController grossMargin;
  bool exporting = false;

  AppState get state => widget.state;

  @override
  void initState() {
    super.initState();
    final data = DocumentExportData.fromState(state);
    costItemName = TextEditingController(text: data.costItemName);
    paymentTerms = TextEditingController(text: data.paymentTerms);
    grossMargin = TextEditingController(
      text: _formatMargin(state.documents.grossMarginPercent),
    );
  }

  @override
  void dispose() {
    costItemName.dispose();
    paymentTerms.dispose();
    grossMargin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = DocumentExportData.fromState(state);
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 36),
      children: [
        Text(
          '書類',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          state.customer.projectName.trim().isEmpty
              ? '工事名未設定'
              : state.customer.projectName,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: Colors.black54),
        ),
        const SizedBox(height: 16),
        _DocumentLink(
          key: const ValueKey('document-cost'),
          icon: Icons.receipt_long_outlined,
          title: '原価',
          subtitle:
              '材料原価 ${state.handrailEstimateGroups().length}件  合計 ${formatYen(data.materialTotal)}',
          onTap: () => _openDocument(_DocumentPage.cost),
        ),
        const SizedBox(height: 10),
        _DocumentLink(
          key: const ValueKey('document-quote'),
          icon: Icons.request_quote_outlined,
          title: '見積書',
          subtitle:
              '粗利 ${_formatMargin(data.grossMarginPercent)}%  ${formatYen(data.quoteTotal)}',
          onTap: () => _openDocument(_DocumentPage.quote),
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          key: const ValueKey('excel-export-button'),
          onPressed: exporting ? null : _exportExcel,
          icon: exporting
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.download_outlined),
          label: Text(exporting ? '作成中' : 'Excelをエクスポート'),
        ),
      ],
    );
  }

  Future<void> _openDocument(_DocumentPage page) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final openDrawing = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (routeContext) => AnimatedBuilder(
          animation: state,
          builder: (context, _) {
            final data = DocumentExportData.fromState(state);
            return Scaffold(
              key: ValueKey('document-fullscreen-${page.name}'),
              appBar: AppBar(title: Text(_pageTitle(page))),
              body: SafeArea(
                child: ListView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 36),
                  children: [_documentBody(page, data, routeContext)],
                ),
              ),
            );
          },
        ),
      ),
    );
    if (mounted && openDrawing == true) {
      widget.onOpenDrawing();
    }
  }

  String _pageTitle(_DocumentPage page) => switch (page) {
    _DocumentPage.cost => '原価',
    _DocumentPage.quote => '見積書',
  };

  Widget _documentBody(
    _DocumentPage page,
    DocumentExportData data,
    BuildContext routeContext,
  ) => switch (page) {
    _DocumentPage.cost => _buildCostSection(data, routeContext),
    _DocumentPage.quote => _buildQuote(data),
  };

  Widget _buildCostSection(DocumentExportData data, BuildContext routeContext) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const ValueKey('cost-item-name-field'),
          controller: costItemName,
          decoration: const InputDecoration(labelText: '原価品名'),
          onChanged: (value) {
            state.documents.costItemName = value;
            state.changed();
          },
        ),
        const SizedBox(height: 20),
        MaterialCostSection(
          state: state,
          onOpenDrawing: () => Navigator.of(routeContext).pop(true),
          onEditGroup: _openHandrailDocumentEditor,
        ),
        const SizedBox(height: 14),
        _SummaryRows(
          rows: [
            ('数量', '1'),
            ('単位', '式'),
            ('単価', formatYen(data.materialSubtotal)),
            ('金額', formatYen(data.materialSubtotal)),
            ('小計', formatYen(data.materialSubtotal)),
            ('消費税', formatYen(data.materialTax)),
            ('合計', formatYen(data.materialTotal)),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          alignment: WrapAlignment.end,
          spacing: 10,
          runSpacing: 10,
          children: [
            OutlinedButton.icon(
              key: const ValueKey('cost-details-preview-button'),
              onPressed: () => _showPreview(
                title: '原価内訳書プレビュー',
                table: _detailPreviewTable(data.lines, customer: false),
              ),
              icon: const Icon(Icons.table_rows_outlined),
              label: const Text('内訳書プレビュー'),
            ),
            OutlinedButton.icon(
              key: const ValueKey('cost-preview-button'),
              onPressed: () => _showPreview(
                title: '原価プレビュー',
                table: _costPreviewTable(data),
              ),
              icon: const Icon(Icons.preview_outlined),
              label: const Text('原価プレビュー'),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _openHandrailDocumentEditor(HandrailEstimateGroup group) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => _HandrailDocumentEditor(state: state, group: group),
      ),
    );
  }

  Widget _buildQuote(DocumentExportData data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _AmountBanner(label: '材料費原価合計', value: data.materialSubtotal),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: 180,
            child: TextField(
              key: const ValueKey('gross-margin-field'),
              controller: grossMargin,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: '粗利率',
                suffixText: '%',
              ),
              onChanged: (value) {
                state.documents.grossMarginPercent = (int.tryParse(value) ?? 0)
                    .clamp(0, 99)
                    .toDouble();
                state.changed();
              },
            ),
          ),
        ),
        const SizedBox(height: 16),
        _AmountBanner(label: '見積金額（税込）', value: data.quoteTotal),
        const SizedBox(height: 16),
        TextField(
          key: const ValueKey('quote-payment-terms-field'),
          controller: paymentTerms,
          minLines: 1,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'お支払い条件'),
          onChanged: (value) {
            state.documents.quotePaymentTerms = value;
            state.changed();
          },
        ),
        const SizedBox(height: 24),
        Text(
          '見積明細',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        _detailPreviewTable(data.lines, customer: true),
        const SizedBox(height: 12),
        _SummaryRows(
          rows: [
            ('小計', formatYen(data.quoteSubtotal)),
            ('消費税', formatYen(data.quoteTax)),
            ('合計', formatYen(data.quoteTotal)),
          ],
        ),
      ],
    );
  }

  Widget _costPreviewTable(DocumentExportData data) => _SpreadsheetTable(
    columns: const ['品名', '数量', '単位', '単価', '金額'],
    rows: [
      [
        data.costItemName,
        '1',
        '式',
        formatYen(data.materialSubtotal),
        formatYen(data.materialSubtotal),
      ],
      ['', '', '', '小計', formatYen(data.materialSubtotal)],
      ['', '', '', '消費税', formatYen(data.materialTax)],
      ['', '', '', '合計', formatYen(data.materialTotal)],
    ],
  );

  Widget _detailPreviewTable(
    List<DocumentLineData> lines, {
    required bool customer,
  }) => _SpreadsheetTable(
    columns: const [
      '改修内容',
      '改修場所',
      '品番',
      '内容（規格・範囲）',
      '数量',
      '単位',
      '単価',
      '金額',
      '備考',
    ],
    rows: lines
        .map(
          (line) => [
            line.workContent,
            line.location,
            line.productId,
            line.specification,
            '${line.quantity}',
            line.unit,
            formatYen(customer ? line.customerUnitPrice : line.costUnitPrice),
            formatYen(customer ? line.customerAmount : line.costAmount),
            line.remarks,
          ],
        )
        .toList(),
  );

  Future<void> _showPreview({
    required String title,
    required Widget table,
  }) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.78,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '閉じる',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: table,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportExcel() async {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => exporting = true);
    try {
      await state.saveNow();
      final path = await ExcelExportService().export(
        DocumentExportData.fromState(state),
      );
      if (!mounted || path == null) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Excelをエクスポートしました')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Excelを作成できませんでした: $error')));
    } finally {
      if (mounted) setState(() => exporting = false);
    }
  }
}

class _HandrailDocumentEditor extends StatefulWidget {
  const _HandrailDocumentEditor({required this.state, required this.group});

  final AppState state;
  final HandrailEstimateGroup group;

  @override
  State<_HandrailDocumentEditor> createState() =>
      _HandrailDocumentEditorState();
}

class _HandrailDocumentEditorState extends State<_HandrailDocumentEditor> {
  late final TextEditingController place;
  late final TextEditingController workContent;
  late final TextEditingController specification;
  late final TextEditingController remarks;
  late final List<HandrailProduct> compatibleProducts;
  String? productId;

  AppState get state => widget.state;
  HandrailEstimateGroup get group => widget.group;

  @override
  void initState() {
    super.initState();
    final lineData = DocumentExportData.fromState(
      state,
    ).lines.firstWhere((line) => line.handrailId == group.id);
    place = TextEditingController(text: lineData.location);
    workContent = TextEditingController(text: lineData.workContent);
    specification = TextEditingController(text: lineData.specification);
    remarks = TextEditingController(text: lineData.remarks);
    compatibleProducts = state.products
        .where(
          (product) =>
              group.lines.every((line) => product.supports(line.environment)),
        )
        .toList();
    productId =
        compatibleProducts.any(
          (product) => product.id == group.primary.productId,
        )
        ? group.primary.productId
        : compatibleProducts.isEmpty
        ? null
        : compatibleProducts.first.id;
  }

  @override
  void dispose() {
    place.dispose();
    workContent.dispose();
    specification.dispose();
    remarks.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final line = group.primary;
    return Scaffold(
      key: const ValueKey('document-handrail-editor'),
      appBar: AppBar(title: const Text('原価内訳を編集')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 36),
          children: [
            Text(
              'No.${state.constructionNumberFor(line)}',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              '${group.lengthMm}mm / ${line.environment.label} / '
              '${line.installationType.label}',
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 18),
            TextField(
              key: const ValueKey('document-handrail-place-field'),
              controller: place,
              decoration: const InputDecoration(labelText: '設置場所'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: const ValueKey('document-handrail-product-field'),
              initialValue: productId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: '品番'),
              items: compatibleProducts
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
              onChanged: compatibleProducts.isEmpty
                  ? null
                  : (value) => setState(() => productId = value),
            ),
            if (compatibleProducts.isEmpty) ...[
              const SizedBox(height: 6),
              Text(
                '${line.environment.label}対応の商品を品番画面で登録してください',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('document-work-content-field'),
              controller: workContent,
              maxLines: 2,
              decoration: const InputDecoration(labelText: '改修内容（付帯工事含む）'),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('document-specification-field'),
              controller: specification,
              maxLines: 3,
              decoration: const InputDecoration(labelText: '内容（規格・範囲）'),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('document-remarks-field'),
              controller: remarks,
              maxLines: 3,
              decoration: const InputDecoration(labelText: '備考（定価等）'),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              key: const ValueKey('save-document-handrail'),
              onPressed: productId == null ? null : _save,
              icon: const Icon(Icons.check),
              label: const Text('反映する'),
            ),
          ],
        ),
      ),
    );
  }

  void _save() {
    final saved = state.applyHandrailDocumentSettings(
      group,
      place: place.text,
      productId: productId!,
      workContent: workContent.text,
      specification: specification.text,
      remarks: remarks.text,
    );
    if (saved) {
      Navigator.pop(context);
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('選択した品番を反映できませんでした')));
  }
}

class _DocumentLink extends StatelessWidget {
  const _DocumentLink({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    shape: RoundedRectangleBorder(
      side: const BorderSide(color: Color(0xFFDCE1E5)),
      borderRadius: BorderRadius.circular(8),
    ),
    clipBehavior: Clip.antiAlias,
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      leading: Icon(icon, size: 26),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    ),
  );
}

class _SummaryRows extends StatelessWidget {
  const _SummaryRows({required this.rows});

  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) => Column(
    children: rows
        .map(
          (row) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Expanded(child: Text(row.$1)),
                Text(
                  row.$2,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        )
        .toList(),
  );
}

class _AmountBanner extends StatelessWidget {
  const _AmountBanner({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.primaryContainer,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        Text(
          formatYen(value),
          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
        ),
      ],
    ),
  );
}

class _SpreadsheetTable extends StatelessWidget {
  const _SpreadsheetTable({required this.columns, required this.rows});

  final List<String> columns;
  final List<List<String>> rows;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: DataTable(
      headingRowColor: const WidgetStatePropertyAll(Color(0xFFE8EEF3)),
      border: TableBorder.all(color: const Color(0xFFB7C0C8)),
      columns: columns.map((label) => DataColumn(label: Text(label))).toList(),
      rows: rows
          .map(
            (row) => DataRow(
              cells: List.generate(
                columns.length,
                (index) => DataCell(Text(index < row.length ? row[index] : '')),
              ),
            ),
          )
          .toList(),
    ),
  );
}

String _formatMargin(double value) => value == value.roundToDouble()
    ? '${value.round()}'
    : value.toStringAsFixed(1);
