import 'package:intl/intl.dart';

String formatMoney(num value, [String? currencyCode]) {
  if (currencyCode == null || currencyCode.isEmpty) {
    return NumberFormat.decimalPattern().format(value);
  }

  try {
    return NumberFormat.simpleCurrency(name: currencyCode).format(value);
  } catch (_) {
    return '$currencyCode ${value.toStringAsFixed(2)}';
  }
}

String formatShortDate(DateTime value) {
  return DateFormat('MMM d').format(value.toLocal());
}

String formatDateTime(DateTime value) {
  return DateFormat('MMM d, HH:mm').format(value.toLocal());
}
