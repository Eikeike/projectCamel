import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
// WICHTIG: Pfad zu deinem Session Model anpassen!
import 'package:project_camel/models/session.dart';
import './indicator.dart';

class PieChartSample2 extends ConsumerStatefulWidget {
  // 1. Hier fügen wir die Variable hinzu
  final List<Session> sessions;

  const PieChartSample2({
    super.key,
    required this.sessions, // 2. Und machen sie im Konstruktor zur Pflicht
  });

  @override
  ConsumerState<PieChartSample2> createState() => _PieChart2State();
}

class _PieChart2State extends ConsumerState<PieChartSample2> {
  int touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    // Falls keine Sessions da sind, leeren Container oder Text zeigen
    if (widget.sessions.isEmpty) {
      return const SizedBox(
          height: 200, child: Center(child: Text("Keine Daten")));
    }

    return AspectRatio(
      aspectRatio: 1.3,
      child: Row(
        children: <Widget>[
          const SizedBox(height: 18),
          Expanded(
            child: AspectRatio(
              aspectRatio: 1,
              child: PieChart(
                PieChartData(
                  pieTouchData: PieTouchData(
                    touchCallback: (FlTouchEvent event, pieTouchResponse) {
                      setState(() {
                        if (!event.isInterestedForInteractions ||
                            pieTouchResponse == null ||
                            pieTouchResponse.touchedSection == null) {
                          touchedIndex = -1;
                          return;
                        }
                        touchedIndex = pieTouchResponse
                            .touchedSection!.touchedSectionIndex;
                      });
                    },
                  ),
                  borderData: FlBorderData(show: false),
                  sectionsSpace: 2,
                  centerSpaceRadius: 40,
                  // Aufruf unserer dynamischen Sektionen
                  sections: showingSections(),
                ),
              ),
            ),
          ),
          // Legende
          Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Indicator(
                color: Theme.of(context).colorScheme.primaryContainer,
                text: 'Kölsch',
                isSquare: true,
              ),
              const SizedBox(height: 4),
              Indicator(
                color: Theme.of(context).colorScheme.secondaryContainer,
                text: '0.33 L',
                isSquare: true,
              ),
              const SizedBox(height: 4),
              Indicator(
                color: Theme.of(context).colorScheme.tertiaryContainer,
                text: '0.5 L',
                isSquare: true,
              ),
              const SizedBox(height: 4),
              Indicator(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                text: '> 0.5 L',
                isSquare: true,
              ),
              const SizedBox(height: 18),
            ],
          ),
          const SizedBox(width: 28),
        ],
      ),
    );
  }

  List<PieChartSectionData> showingSections() {
    // 1. Gesamtanzahl für die Prozentrechnung
    final total = widget.sessions.length;

    // 2. Zählen der Daten (wie bisher)
    final countKoelsch = widget.sessions.where((s) => s.volumeML == 200).length;
    final count33 = widget.sessions.where((s) => s.volumeML == 330).length;
    final count50 = widget.sessions.where((s) => s.volumeML == 500).length;
    final countOther = widget.sessions.where((s) => s.volumeML > 500).length;

    final data = [
      (
        count: countKoelsch,
        color: Theme.of(context).colorScheme.primaryContainer
      ),
      (count: count33, color: Theme.of(context).colorScheme.secondaryContainer),
      (count: count50, color: Theme.of(context).colorScheme.tertiaryContainer),
      (
        count: countOther,
        color: Theme.of(context).colorScheme.surfaceContainerHighest
      ),
    ];

    return List.generate(4, (i) {
      final isTouched = i == touchedIndex;
      final fontSize = isTouched ? 25.0 : 16.0;
      final radius = isTouched ? 60.0 : 50.0;

      final item = data[i];
      final double val = item.count.toDouble();

      // --- HIER IST DIE ÄNDERUNG ---

      // Berechnung der Prozentzahl
      // Wenn total 0 ist (sollte durch den check im build nicht passieren), fangen wir es ab.
      final double percentage = total > 0 ? (val / total * 100) : 0;

      // Titel formatieren: Keine Nachkommastellen (toStringAsFixed(0)) und "%" anhängen
      final String title = val > 0 ? '${percentage.toStringAsFixed(0)}%' : '';

      // -----------------------------

      return PieChartSectionData(
        color: item.color,
        value: val,
        title: title, // Jetzt steht hier z.B. "40%"
        radius: radius,
        titleStyle: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      );
    });
  }
}
