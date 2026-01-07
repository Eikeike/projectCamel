import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:project_camel/auth/auth_providers.dart';

class DebugScreen extends ConsumerWidget {
  const DebugScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Nur den Ladezustand beobachten, um unnötige Rebuilds des gesamten Screens zu vermeiden
    final isLoading =
        ref.watch(authControllerProvider.select((s) => s.isLoading));

    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Theme Debug')),
      body: const DefaultTabController(
        length: 2,
        child: Column(
          children: [
            TabBar(
              tabs: [
                Tab(text: 'Colors'),
                Tab(text: 'Text'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  ColorSchemePreview(),
                  Center(child: Text("Text Theme Preview Placeholder")),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ColorSchemePreview extends StatelessWidget {
  const ColorSchemePreview({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // Kompakte Liste der anzuzeigenden Farben
    final entries = <(String, Color)>[
      ('primary', scheme.primary),
      ('onPrimary', scheme.onPrimary),
      ('primaryContainer', scheme.primaryContainer),
      ('onPrimaryContainer', scheme.onPrimaryContainer),
      ('secondary', scheme.secondary),
      ('onSecondary', scheme.onSecondary),
      ('secondaryContainer', scheme.secondaryContainer),
      ('onSecondaryContainer', scheme.onSecondaryContainer),
      ('tertiary', scheme.tertiary),
      ('onTertiary', scheme.onTertiary),
      ('surfaceContainerHighest', scheme.surfaceContainerHighest),
      ('onSurfaceVariant', scheme.onSurfaceVariant),
      ('surface(background)', scheme.surface),
      ('onSurface', scheme.onSurface),
      ('error', scheme.error),
      ('onError', scheme.onError),
      ('outline', scheme.outline),
      ('outlineVariant', scheme.outlineVariant),
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final name = entries[index].$1;
        final color = entries[index].$2;

        // Effiziente Helligkeitsberechnung statt ThemeData.estimateBrightness
        final double luminance = color.computeLuminance();
        final Color textColor = luminance > 0.5 ? Colors.black : Colors.white;

        return Container(
          key: ValueKey(name),
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.black.withOpacity(0.1)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                name,
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '#${color.value.toRadixString(16).padLeft(8, '0').toUpperCase()}',
                style: TextStyle(
                  color: textColor.withOpacity(0.7),
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
