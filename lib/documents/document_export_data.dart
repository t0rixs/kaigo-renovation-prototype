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

class DocumentPhotoData {
  const DocumentPhotoData({
    required this.number,
    required this.location,
    required this.beforeMemo,
    required this.afterMemo,
    required this.beforePhoto,
    required this.afterPhoto,
  });

  final String number;
  final String location;
  final String beforeMemo;
  final String afterMemo;
  final CapturedProjectPhoto? beforePhoto;
  final CapturedProjectPhoto? afterPhoto;
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
    required this.photos,
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
  final List<DocumentPhotoData> photos;
  final DateTime exportedAt;

  int get coverQuoteAmount => quoteTotal;

  factory DocumentExportData.fromState(AppState state, {DateTime? exportedAt}) {
    final customer = state.customer;
    final documents = state.documents;
    final margin = documents.grossMarginPercent.clamp(0, 99).toDouble();
    final lines = <DocumentLineData>[];
    for (final group in state.handrailEstimateGroups()) {
      final line = group.primary;
      final fields = documents.fieldsFor(group.id);
      final product = state.productById(line.productId);
      final cost = state.costForGroup(group);
      final handrailCost = cost.total - cost.reinforcementPlateCost;
      final customerUnitPrice = _customerPrice(handrailCost, margin);
      lines.add(
        DocumentLineData(
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
          costUnitPrice: handrailCost,
          costAmount: handrailCost,
          customerUnitPrice: customerUnitPrice,
          customerAmount: customerUnitPrice,
          remarks: fields.remarks.trim(),
        ),
      );
      final reinforcementPoints = state
          .connectionPointsForGroup(group)
          .where((point) => point.hasReinforcementPlate)
          .toList();
      for (final (index, point) in reinforcementPoints.indexed) {
        final price = point.reinforcementPlatePrice;
        final number = index + 1;
        lines.add(
          DocumentLineData(
            handrailId: '${line.id}-reinforcement-$number',
            workContent: '補強板取付',
            location: _defaultLocation(state, line),
            productId: '補強板',
            specification: '接続点 $number',
            quantity: 1,
            unit: '枚',
            costUnitPrice: price,
            costAmount: price,
            customerUnitPrice: _customerPrice(price, margin),
            customerAmount: _customerPrice(price, margin),
            remarks: '手すりNo.${state.constructionNumberFor(line)}',
          ),
        );
      }
    }
    final materialSubtotal = state.materialCostTotal;
    final materialTax = materialSubtotal * 10 ~/ 100;
    final quoteSubtotal = lines.fold<int>(
      0,
      (total, line) => total + line.customerAmount,
    );
    final quoteTax = quoteSubtotal * 10 ~/ 100;
    final photos = state.photoLocations.map((photoLocation) {
      final detectedLocation = state.placeNameAt(
        photoLocation.xMm,
        photoLocation.yMm,
      );
      return DocumentPhotoData(
        number: photoLocation.handrailNumber,
        location: detectedLocation.isEmpty
            ? photoLocation.locationName
            : detectedLocation,
        beforeMemo: photoLocation.beforeMemo,
        afterMemo: photoLocation.afterMemo,
        beforePhoto: photoLocation.beforePhoto,
        afterPhoto: photoLocation.afterPhoto,
      );
    }).toList();
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
      photos: photos,
      exportedAt: exportedAt ?? DateTime.now(),
    );
  }
}

int _customerPrice(int cost, double margin) =>
    (cost / (1 - margin / 100)).round();

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
  final shape = group.shapeLabel.isEmpty ? '' : ' ${group.shapeLabel}';
  return '$prefix$diameter$shape ${group.lengthMm}mm ${line.installationType.label}';
}
