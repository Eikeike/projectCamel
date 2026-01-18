import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class SessionChart extends StatelessWidget {
  final List<int> allValues;
  final double volumeCalibrationValue;

  const SessionChart({
    super.key,
    required this.allValues,
    required this.volumeCalibrationValue,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (allValues.length < 5) return const SizedBox.shrink();

    final double volStep =
        0.5 / (volumeCalibrationValue > 0 ? volumeCalibrationValue : 1.0);

    // ... (Physik-Berechnungen bleiben identisch)
    List<double> rawFlowValues = [];
    List<double> timeSpots = [];
    List<FlSpot> volumeSpots = [const FlSpot(0, 0)];
    final int t0 = allValues.first;

    for (int i = 1; i < allValues.length; i++) {
      double currentTimeS = (allValues[i] - t0) / 1000.0;
      double deltaT = currentTimeS - ((allValues[i - 1] - t0) / 1000.0);
      if (deltaT > 0) {
        rawFlowValues.add((volStep / deltaT).clamp(0.0, 5.0));
        timeSpots.add(currentTimeS);
        volumeSpots.add(FlSpot(currentTimeS, i * volStep));
      }
    }

    List<FlSpot> flowSpots = [];
    for (int i = 0; i < rawFlowValues.length; i++) {
      double sum = 0;
      int count = 0;
      for (int j = i - 6; j <= i + 6; j++) {
        if (j >= 0 && j < rawFlowValues.length) {
          sum += rawFlowValues[j];
          count++;
        }
      }
      flowSpots.add(FlSpot(timeSpots[i], sum / count));
    }

    double maxFlow = flowSpots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    double maxVol = volumeSpots.last.y;
    double maxTime = volumeSpots.last.x;
    final double yLeftMax = maxFlow * 1.2;
    final double yRightMax = maxVol * 1.2;
    List<FlSpot> normalizedVolumeSpots = volumeSpots
        .map((s) => FlSpot(s.x, (s.y / yRightMax) * yLeftMax))
        .toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildLegend(theme),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            // sideSize etwas verkleinert, um den Graph breiter zu machen
            const double sideSize = 48.0;

            return Padding(
              // Kleineres Padding zum Bildschirmrand
              padding: const EdgeInsets.symmetric(horizontal: 0),
              child: SizedBox(
                height: 320, // Etwas mehr Höhe für die X-Achse
                width: constraints.maxWidth,
                child: LineChart(
                  LineChartData(
                    minX: 0,
                    maxX: maxTime,
                    minY: 0,
                    maxY: yLeftMax,
                    lineTouchData: _buildTouchData(theme, yLeftMax, yRightMax),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: yLeftMax / 5,
                      getDrawingHorizontalLine: (v) => FlLine(
                        color: theme.colorScheme.onSurface.withOpacity(0.08),
                        strokeWidth: 1,
                      ),
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: sideSize,
                          interval: yLeftMax / 5,
                          getTitlesWidget: (v, m) => SideTitleWidget(
                            axisSide: m.axisSide,
                            space: 4,
                            child: Text('${v.toStringAsFixed(2)} L/s',
                                style: TextStyle(
                                    color: theme.colorScheme.primary,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ),
                      rightTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: sideSize,
                          interval: yLeftMax / 5,
                          getTitlesWidget: (v, m) {
                            double realVol = (v / yLeftMax) * yRightMax;
                            return SideTitleWidget(
                              axisSide: m.axisSide,
                              space: 4,
                              child: Text('${realVol.toStringAsFixed(1)} L',
                                  style: TextStyle(
                                      color: theme.colorScheme.tertiary,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold)),
                            );
                          },
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize:
                              32, // RESERVIERTER PLATZ FÜR DIE X-ACHSE
                          interval: maxTime / 5,
                          getTitlesWidget: (v, m) => SideTitleWidget(
                            axisSide: m.axisSide,
                            space: 8,
                            child: Text('${v.toStringAsFixed(1)}s',
                                style: TextStyle(
                                    color: theme.colorScheme.onSurface
                                        .withOpacity(0.5),
                                    fontSize: 10)),
                          ),
                        ),
                      ),
                      topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                    ),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: normalizedVolumeSpots,
                        isCurved: true,
                        color: theme.colorScheme.tertiary,
                        //dashArray: [5, 10],
                        barWidth: 2,
                        dotData: const FlDotData(show: false),
                      ),
                      LineChartBarData(
                        spots: flowSpots,
                        isCurved: true,
                        color: theme.colorScheme.primary,
                        barWidth: 3,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                            show: true,
                            color: theme.colorScheme.primary.withOpacity(0.1)),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // Die Hilfsmethoden bleiben identisch...
  Widget _buildLegend(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _indicator(theme.colorScheme.primary, "Flow [L/s]", theme),
        const SizedBox(width: 24),
        _indicator(theme.colorScheme.tertiary, "Volumen [L]", theme),
      ],
    );
  }

  Widget _indicator(Color c, String t, ThemeData theme) => Row(children: [
        Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(t,
            style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: 12,
                fontWeight: FontWeight.bold)),
      ]);

  LineTouchData _buildTouchData(
      ThemeData theme, double yLeftMax, double yRightMax) {
    return LineTouchData(
      touchTooltipData: LineTouchTooltipData(
        getTooltipColor: (spot) => theme.colorScheme.surfaceContainerHigh,
        getTooltipItems: (spots) => spots.map((s) {
          // FLOW Linie
          if (s.barIndex == 1) {
            return LineTooltipItem(
              '${s.y.toStringAsFixed(3)} L/s',
              TextStyle(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            );
          }

          // VOLUMEN Linie
          double realVol = (s.y / yLeftMax) * yRightMax;
          return LineTooltipItem(
            '${realVol.toStringAsFixed(3)} L',
            TextStyle(
              color: theme.colorScheme.tertiary,
              fontWeight: FontWeight.bold,
            ),
          );
        }).toList(),
      ),
    );
  }
}
