/// Height is always stored (in `profiles.height_cm`) and calculated with
/// (BMI, etc.) in centimeters; this is the single place that converts it for
/// display/entry when someone prefers inches. Mirrors [Units] (weight's
/// kg/lb equivalent) - see AppState.heightUnitPref, which is device-local
/// for the same reason [AppState.themePref] is: how you like measurements
/// *shown* on this device isn't really account data.
class HeightUnits {
  static const double _cmPerIn = 2.54;

  static double cmToIn(double cm) => cm / _cmPerIn;

  static double inToCm(double inches) => inches * _cmPerIn;

  static double displayValue(double cm, String unitPref) => unitPref == 'in' ? cmToIn(cm) : cm;

  static double toCm(double value, String unitPref) => unitPref == 'in' ? inToCm(value) : value;

  static String label(String unitPref) => unitPref == 'in' ? 'in' : 'cm';

  static String format(double cm, String unitPref, {int decimals = 0}) {
    return displayValue(cm, unitPref).toStringAsFixed(decimals);
  }

  static String formatWithUnit(double cm, String unitPref, {int decimals = 0}) {
    return '${format(cm, unitPref, decimals: decimals)} ${label(unitPref)}';
  }
}
