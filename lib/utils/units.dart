/// Weight is always stored in the database as kilograms; this is the single
/// place that converts it for display/entry when a user prefers pounds.
class Units {
  static const double _kgPerLb = 0.45359237;

  static double kgToLb(double kg) => kg / _kgPerLb;

  static double lbToKg(double lb) => lb * _kgPerLb;

  /// Converts [kg] into the unit the user prefers ('kg' or 'lb').
  static double displayValue(double kg, String unitPref) => unitPref == 'lb' ? kgToLb(kg) : kg;

  /// Converts a value typed in the user's preferred unit back into kg for
  /// storage.
  static double toKg(double value, String unitPref) => unitPref == 'lb' ? lbToKg(value) : value;

  static String label(String unitPref) => unitPref == 'lb' ? 'lb' : 'kg';

  static String format(double kg, String unitPref, {int decimals = 1}) {
    return displayValue(kg, unitPref).toStringAsFixed(decimals);
  }

  static String formatWithUnit(double kg, String unitPref, {int decimals = 1}) {
    return '${format(kg, unitPref, decimals: decimals)} ${label(unitPref)}';
  }
}
