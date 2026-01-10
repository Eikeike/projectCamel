class SessionCalculatorService {
  /// Schlägt Volumen vor (10% Toleranz)
  static int suggestVolume(int? measuredML) {
    if (measuredML == null || measuredML <= 0) return 500;
    const double toleranceFactor = 0.10;
    bool isInTolerance(int target, int measured) =>
        (measured - target).abs() <= (target * toleranceFactor);

    if (isInTolerance(200, measuredML)) return 200;
    if (isInTolerance(330, measuredML)) return 330;
    if (isInTolerance(500, measuredML)) return 500;
    return measuredML;
  }

  /// Durchschnittlicher Flow
  static double calculateAverageFlow(int durationMS, int volumeML) {
    if (durationMS <= 0) return 0;
    return (volumeML / 1000.0) / (durationMS / 1000.0);
  }

  /// Berechnet den Peak Flow identisch zum SessionChart (Moving Window)
  static double calculatePeakFlow(
      List<int> allValues, double calibrationFactor) {
    if (allValues.length < 5) return 0;

    final double volStep =
        0.5 / (calibrationFactor > 0 ? calibrationFactor : 1.0);

    // 1. Raw Flow berechnen (identisch zum Chart-Loop)
    List<double> rawFlowValues = [];
    for (int i = 1; i < allValues.length; i++) {
      double deltaT = (allValues[i] - allValues[i - 1]) / 1000.0;
      if (deltaT > 0) {
        rawFlowValues.add((volStep / deltaT).clamp(0.0, 5.0));
      }
    }

    // 2. Moving Window Glättung (+/- 6 Samples)
    double maxSmoothedFlow = 0;
    for (int i = 0; i < rawFlowValues.length; i++) {
      double sum = 0;
      int count = 0;
      for (int j = i - 6; j <= i + 6; j++) {
        if (j >= 0 && j < rawFlowValues.length) {
          sum += rawFlowValues[j];
          count++;
        }
      }
      double currentSmoothed = sum / count;
      if (currentSmoothed > maxSmoothedFlow) {
        maxSmoothedFlow = currentSmoothed;
      }
    }

    return maxSmoothedFlow;
  }
}
