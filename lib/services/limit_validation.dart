double? parseLimit(String input) {
  final value = double.tryParse(input.trim().replaceAll(',', '.'));
  if (value == null || !value.isFinite || value < 0.1 || value > 500000) {
    return null;
  }
  return value;
}
