import 'package:flutter/material.dart';

import '../app_state.dart';

class BasicInfoScreen extends StatefulWidget {
  const BasicInfoScreen({super.key, required this.state});

  final AppState state;

  @override
  State<BasicInfoScreen> createState() => _BasicInfoScreenState();
}

class _BasicInfoScreenState extends State<BasicInfoScreen> {
  late final Map<String, TextEditingController> controllers;

  @override
  void initState() {
    super.initState();
    final info = widget.state.customer;
    controllers = {
      'name': TextEditingController(text: info.name),
      'kana': TextEditingController(text: info.kana),
      'address': TextEditingController(text: info.address),
      'phone': TextEditingController(text: info.phone),
      'insuredNumber': TextEditingController(text: info.insuredNumber),
      'surveyDate': TextEditingController(text: info.surveyDate),
      'birthDate': TextEditingController(text: info.birthDate),
      'familyAddressee': TextEditingController(text: info.familyAddressee),
      'projectName': TextEditingController(text: info.projectName),
      'constructionPlace': TextEditingController(text: info.constructionPlace),
      'estimateValid': TextEditingController(text: info.estimateValid),
      'paymentTerms': TextEditingController(text: info.paymentTerms),
    };
  }

  @override
  void dispose() {
    for (final controller in controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 720 ? 2 : 1;
        final width = columns == 2
            ? (constraints.maxWidth - 44) / 2
            : constraints.maxWidth - 32;
        return ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 36),
          children: [
            Text(
              '基本情報',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              '見積書と工事情報に反映されます',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.black54),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 14,
              children: [
                _field(
                  'お客様名',
                  'name',
                  width,
                  (v) => widget.state.customer.name = v,
                ),
                _field(
                  'フリガナ',
                  'kana',
                  width,
                  (v) => widget.state.customer.kana = v,
                ),
                _field(
                  '住所',
                  'address',
                  width,
                  (v) => widget.state.customer.address = v,
                ),
                _field(
                  '電話番号',
                  'phone',
                  width,
                  (v) => widget.state.customer.phone = v,
                  keyboardType: TextInputType.phone,
                ),
                _field(
                  '被保険者番号',
                  'insuredNumber',
                  width,
                  (v) => widget.state.customer.insuredNumber = v,
                  keyboardType: TextInputType.number,
                ),
                _dateField(
                  '現調依頼日',
                  'surveyDate',
                  width,
                  (v) => widget.state.customer.surveyDate = v,
                ),
                _dateField(
                  '生年月日',
                  'birthDate',
                  width,
                  (v) => widget.state.customer.birthDate = v,
                ),
                _field(
                  'ご家族宛名',
                  'familyAddressee',
                  width,
                  (v) => widget.state.customer.familyAddressee = v,
                ),
                _field(
                  '工事名',
                  'projectName',
                  width,
                  (v) => widget.state.customer.projectName = v,
                ),
                _field(
                  '工事場所',
                  'constructionPlace',
                  width,
                  (v) => widget.state.customer.constructionPlace = v,
                ),
                _field(
                  '見積有効期限',
                  'estimateValid',
                  width,
                  (v) => widget.state.customer.estimateValid = v,
                ),
                _field(
                  '支払条件',
                  'paymentTerms',
                  width,
                  (v) => widget.state.customer.paymentTerms = v,
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _field(
    String label,
    String key,
    double width,
    ValueChanged<String> setter, {
    TextInputType? keyboardType,
  }) => SizedBox(
    width: width,
    child: TextField(
      controller: controllers[key],
      keyboardType: keyboardType,
      decoration: InputDecoration(labelText: label),
      onChanged: (value) {
        setter(value);
        widget.state.changed();
      },
    ),
  );

  Widget _dateField(
    String label,
    String key,
    double width,
    ValueChanged<String> setter,
  ) {
    return SizedBox(
      width: width,
      child: TextField(
        controller: controllers[key],
        readOnly: true,
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.calendar_today_outlined),
        ),
        onTap: () async {
          final current = DateTime.tryParse(controllers[key]!.text);
          final selected = await showDatePicker(
            context: context,
            initialDate: current ?? DateTime.now(),
            firstDate: DateTime(1900),
            lastDate: DateTime(2100),
          );
          if (selected == null) return;
          final value =
              '${selected.year.toString().padLeft(4, '0')}-${selected.month.toString().padLeft(2, '0')}-${selected.day.toString().padLeft(2, '0')}';
          controllers[key]!.text = value;
          setter(value);
          widget.state.changed();
        },
      ),
    );
  }
}
