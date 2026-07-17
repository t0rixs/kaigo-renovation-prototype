String formatYen(num value) {
  final digits = value.round().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return '¥$buffer';
}

int parseInt(String value) => int.tryParse(value.replaceAll(',', '')) ?? 0;

double parseDouble(String value) => double.tryParse(value) ?? 0;
