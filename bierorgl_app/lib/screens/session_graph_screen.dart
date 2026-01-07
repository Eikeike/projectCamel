import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class SessionGraphScreen extends StatefulWidget {
  final String valuesJson;
  final int volumeCalibrationValue;

  const SessionGraphScreen({
    super.key,
    required this.valuesJson,
    required this.volumeCalibrationValue,
  });

  @override
  State<SessionGraphScreen> createState() => _SessionGraphScreenState();
}

class _SessionGraphScreenState extends State<SessionGraphScreen> {
  List<FlSpot> flowData = [];
  List<FlSpot> volumeData = [];
  bool isLoading = true;
  double maxTime = 0;
  double totalVolume = 0;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _processData());
  }

  void _processData() {
    try {
      final List<dynamic> decoded = jsonDecode(widget.valuesJson);
      List<int> rawData = decoded.map((item) => item as int).toList();

      // 1. FILTER: Header entfernen & Sortieren
      List<int> filtered = rawData.where((val) => val >= 0 && val < 50000).toList();
      filtered.sort();

      if (filtered.length < 2) {
        if (mounted) setState(() => isLoading = false);
        return;
      }

      final double volStep = 0.5 / widget.volumeCalibrationValue;
      final int t0 = filtered.first;

      List<double> rawFlowValues = [];
      List<double> timeSpots = [];
      List<FlSpot> tempVolumeData = [];

      tempVolumeData.add(const FlSpot(0, 0));

      // 2. ROHWERTE BERECHNEN
      for (int i = 1; i < filtered.length; i++) {
        double currentTimeS = (filtered[i] - t0) / 1000.0;
        double prevTimeS = (filtered[i - 1] - t0) / 1000.0;
        double deltaT = currentTimeS - prevTimeS;

        if (deltaT > 0) {
          double flow = volStep / deltaT;
          rawFlowValues.add(flow > 4.0 ? 0.0 : flow); // Plausibilitäts-Cutoff
          timeSpots.add(currentTimeS);

          double currentVol = i * volStep;
          tempVolumeData.add(FlSpot(currentTimeS, currentVol));

          maxTime = currentTimeS;
          totalVolume = currentVol;
        }
      }

      // 3. GLÄTTUNGS-FILTER (Moving Average - MATLAB: movmean)
      List<FlSpot> smoothedFlowData = [];
      int windowSize = 10; // Fenstergröße anpassen für mehr/weniger Glättung

      for (int i = 0; i < rawFlowValues.length; i++) {
        double sum = 0;
        int count = 0;

        // Berechne Durchschnitt im Fenster um den aktuellen Punkt
        for (int j = i - (windowSize ~/ 2); j <= i + (windowSize ~/ 2); j++) {
          if (j >= 0 && j < rawFlowValues.length) {
            sum += rawFlowValues[j];
            count++;
          }
        }

        smoothedFlowData.add(FlSpot(timeSpots[i], sum / count));
      }

      if (mounted) {
        setState(() {
          flowData = smoothedFlowData;
          volumeData = tempVolumeData;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Fehler: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    double xInterval = (maxTime / 5).clamp(0.1, 5.0);

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: MediaQuery.of(context).size.width * 0.95,
          height: 450,
          padding: const EdgeInsets.fromLTRB(10, 25, 20, 15),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1E),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 15)],
          ),
          child: isLoading
              ? const Center(child: CircularProgressIndicator(color: Colors.orange))
              : Column(
            children: [
              Text(
                "Analyse: ${totalVolume.toStringAsFixed(2)} L | ${maxTime.toStringAsFixed(1)} s",
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 25),
              Expanded(
                child: LineChart(
                  LineChartData(
                    minX: 0, maxX: maxTime, minY: 0,
                    gridData: const FlGridData(show: true, drawVerticalLine: false),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          interval: xInterval,
                          getTitlesWidget: (v, _) => Text("${v.toStringAsFixed(1)}s",
                              style: const TextStyle(color: Colors.white54, fontSize: 9)),
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true, reservedSize: 35,
                          getTitlesWidget: (v, _) => Text(v.toStringAsFixed(1),
                              style: const TextStyle(color: Colors.orange, fontSize: 10)),
                        ),
                      ),
                      rightTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true, reservedSize: 35,
                          getTitlesWidget: (v, _) => Text(v.toStringAsFixed(2),
                              style: const TextStyle(color: Colors.blue, fontSize: 10)),
                        ),
                      ),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    lineBarsData: [
                      LineChartBarData(
                        spots: flowData,
                        isCurved: true,
                        curveSmoothness: 0.3, // Macht die Kurve noch flüssiger
                        color: Colors.orange,
                        barWidth: 3,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(show: true, color: Colors.orange.withOpacity(0.1)),
                      ),
                      LineChartBarData(
                        spots: volumeData,
                        color: Colors.blue.withOpacity(0.5),
                        barWidth: 3,
                        dotData: const FlDotData(show: false),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 15),
              _buildLegend(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _indicator(Colors.orange, "Trinkgeschwindigkeit [L/s]"),
        const SizedBox(width: 20),
        _indicator(Colors.blue, "Volumen [L]"),
      ],
    );
  }

  Widget _indicator(Color c, String t) => Row(children: [
    Container(width: 8, height: 8, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
    const SizedBox(width: 6),
    Text(t, style: const TextStyle(color: Colors.white70, fontSize: 11)),
  ]);
}