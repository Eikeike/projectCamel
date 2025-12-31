import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class SessionGraphScreen extends StatefulWidget {
  final String valuesJson;
  final double clkFactor;
  final int timestampsPerLiter;

  const SessionGraphScreen({
    super.key,
    required this.valuesJson,
    required this.clkFactor,
    required this.timestampsPerLiter,
  });

  @override
  State<SessionGraphScreen> createState() => _SessionGraphScreenState();
}

class _SessionGraphScreenState extends State<SessionGraphScreen> {
  List<FlSpot> flowData = [];
  List<FlSpot> volumeData = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    // Die Berechnung in einem 'microtask' ausführen, um den UI-Thread nicht zu blockieren.
    Future.microtask(() => _processData());
  }

  void _processData() {
    try {
      // 1. Rohdaten laden und parsen
      // Ignoriere die abnormalen Werte (große Sprünge) am Anfang/Ende des Arrays
      final List<int> rawTimestamps = (jsonDecode(widget.valuesJson) as List)
          .map((item) => item as int)
          .where((val) => val < 30000000)
          .toList();

      if (rawTimestamps.length < 2) {
        setState(() => isLoading = false);
        return;
      }

      // 2. Grundberechnungen (wie im MATLAB-Skript)
      final List<double> timeS = rawTimestamps.map((t) => t * widget.clkFactor).toList();
      final double volStep = 1.0 / widget.timestampsPerLiter;

      List<double> flow = [];
      for (int i = 1; i < timeS.length; i++) {
        double timeDiff = timeS[i] - timeS[i - 1];
        if (timeDiff > 0) {
          flow.add(volStep / timeDiff);
        }
      }
      final List<double> timeFlow = timeS.sublist(1);

      // 3. Daten für fl_chart vorbereiten
      List<FlSpot> tempFlowData = [];
      for (int i = 0; i < flow.length; i++) {
        // Filtere extreme Ausreißer im Durchfluss für eine bessere Darstellung
        if (flow[i] < 10) { // Limit auf 10 L/s, kann angepasst werden
          tempFlowData.add(FlSpot(timeFlow[i], flow[i]));
        }
      }

      List<FlSpot> tempVolumeData = [];
      for (int i = 0; i < timeS.length; i++) {
        tempVolumeData.add(FlSpot(timeS[i], i * volStep));
      }

      setState(() {
        flowData = tempFlowData;
        volumeData = tempVolumeData;
        isLoading = false;
      });

    } catch (e) {
      print("Fehler bei der Graphen-Datenverarbeitung: $e");
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withOpacity(0.5),
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Container(
            height: 500,
            width: double.infinity,
            color: const Color(0xFF2c2c2e), // Dunkler Hintergrund für den Graphen
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : flowData.isEmpty
                ? const Center(child: Text("Nicht genügend Daten für den Graphen vorhanden.", style: TextStyle(color: Colors.white)))
                : Column(
              children: [
                const Text(
                  "Analyse des Trinkverhaltens",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: LineChart(
                    LineChartData(
                      gridData: FlGridData(show: true, drawVerticalLine: true, getDrawingHorizontalLine: (value) => const FlLine(color: Colors.white12, strokeWidth: 1,), getDrawingVerticalLine: (value) => const FlLine(color: Colors.white12, strokeWidth: 1,),),
                      titlesData: FlTitlesData(
                        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40, interval: 0.5,)),
                        bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30, interval: 1,)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      borderData: FlBorderData(show: true, border: Border.all(color: Colors.white24)),
                      lineBarsData: [
                        // Durchfluss-Graph
                        LineChartBarData(
                          spots: flowData,
                          isCurved: true,
                          color: const Color(0xFFFF9500),
                          barWidth: 3,
                          isStrokeCapRound: true,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            color: const Color(0xFFFF9500).withOpacity(0.3),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 8.0),
                  child: Text("Durchfluss [L/s]", style: TextStyle(color: Colors.white70, fontSize: 12)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
