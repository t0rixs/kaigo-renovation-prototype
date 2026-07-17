import '../app_state.dart';
import '../models.dart';

class DocumentLineData {
  const DocumentLineData({
    required this.handrailId,
    required this.workContent,
    required this.location,
    required this.productId,
    required this.specification,
    required this.quantity,
    required this.unit,
    required this.costUnitPrice,
    required this.costAmount,
    required this.customerUnitPrice,
    required this.customerAmount,
    required this.remarks,
  });

  final String handrailId;
  final String workContent;
  final String location;
  final String productId;
  final String specification;
  final int quantity;
  final String unit;
  final int costUnitPrice;
  final int costAmount;
  final int customerUnitPrice;
  final int customerAmount;
  final String remarks;
}

class DocumentExportData {
  const DocumentExportData({
    required this.customerName,
    required this.customerKana,
    required this.customerAddress,
    required this.customerPhone,
    required this.insuredNumber,
    required this.surveyDate,
    required this.birthDate,
    required this.projectName,
    required this.constructionPlace,
    required this.estimateValid,
    required this.paymentTerms,
    required this.costItemName,
    required this.materialSubtotal,
    required this.materialTax,
    required this.materialTotal,
    required this.grossMarginPercent,
    required this.quoteSubtotal,
    required this.quoteTax,
    required this.quoteTotal,
    required this.lines,
    required this.exportedAt,
  });

  final String customerName;
  final String customerKana;
  final String customerAddress;
  final String customerPhone;
  final String insuredNumber;
  final String surveyDate;
  final String birthDate;
  final String projectName;
  final String constructionPlace;
  final String estimateValid;
  final String paymentTerms;
  final String costItemName;
  final int materialSubtotal;
  final int materialTax;
  final int materialTotal;
  final double grossMarginPercent;
  final int quoteSubtotal;
  final int quoteTax;
  final int quoteTotal;
  final List<DocumentLineData> lines;
  final DateTime exportedAt;

  int get coverQuoteAmount => quoteTotal;

  factory DocumentExportData.fromState(AppState state, {DateTime? exportedAt}) {
    final customer = state.customer;
    final documents = state.documents;
    final margin = documents.grossMarginPercent.clamp(0, 99).toDouble();
    final lines = state.handrailEstimateGroups().map((group) {
      final line = group.primary;
      final fields = documents.fieldsFor(group.id);
      final product = state.productById(line.productId);
      final cost = state.costForGroup(group);
      final customerUnitPrice = (cost.total / (1 - margin / 100)).round();
      return DocumentLineData(
        handrailId: line.id,
        workContent: fields.workContent.trim().isEmpty
            ? '手すり設置'
            : fields.workContent.trim(),
        location: _defaultLocation(state, line),
        productId: product?.id ?? line.productId ?? '',
        specification: fields.specification.trim().isEmpty
            ? _defaultSpecification(group, product)
            : fields.specification.trim(),
        quantity: 1,
        unit: '式',
        costUnitPrice: cost.total,
        costAmount: cost.total,
        customerUnitPrice: customerUnitPrice,
        customerAmount: customerUnitPrice,
        remarks: fields.remarks.trim(),
      );
    }).toList();
    final materialSubtotal = state.materialCostTotal;
    final materialTax = materialSubtotal * 10 ~/ 100;
    final quoteSubtotal = lines.fold<int>(
      0,
      (total, line) => total + line.customerAmount,
    );
    final quoteTax = quoteSubtotal * 10 ~/ 100;
    final customerName = customer.name.trim();
    final costItemName = documents.costItemName.trim().isEmpty
        ? customerName.isEmpty
              ? '住宅改修工事一式'
              : '$customerName様邸 住宅改修工事一式'
        : documents.costItemName.trim();
    return DocumentExportData(
      customerName: customer.name,
      customerKana: customer.kana,
      customerAddress: customer.address,
      customerPhone: customer.phone,
      insuredNumber: customer.insuredNumber,
      surveyDate: customer.surveyDate,
      birthDate: customer.birthDate,
      projectName: customer.projectName,
      constructionPlace: customer.constructionPlace.trim().isEmpty
          ? customer.address
          : customer.constructionPlace,
      estimateValid: customer.estimateValid,
      paymentTerms: documents.quotePaymentTerms.trim().isEmpty
          ? customer.paymentTerms
          : documents.quotePaymentTerms.trim(),
      costItemName: costItemName,
      materialSubtotal: materialSubtotal,
      materialTax: materialTax,
      materialTotal: materialSubtotal + materialTax,
      grossMarginPercent: margin,
      quoteSubtotal: quoteSubtotal,
      quoteTax: quoteTax,
      quoteTotal: quoteSubtotal + quoteTax,
      lines: lines,
      exportedAt: exportedAt ?? DateTime.now(),
    );
  }
}

String _defaultLocation(AppState state, WorkLine line) {
  return state.handrailPlace(line);
}

String _defaultSpecification(
  HandrailEstimateGroup group,
  HandrailProduct? product,
) {
  final line = group.primary;
  final productName = product?.name.trim() ?? '';
  final diameter = product == null ? '' : ' φ${product.diameterMm}';
  final prefix = productName.isEmpty ? '手すり' : productName;
  final shape = group.isConnected ? ' L字' : '';
  return '$prefix$diameter$shape ${group.lengthMm}mm ${line.installationType.label}';
}
