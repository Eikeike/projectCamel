import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DebugScreen extends ConsumerWidget {
  const DebugScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Falls du den Auth-Ladezustand noch prüfen möchtest:
    // final isLoading = ref.watch(authControllerProvider.select((s) => s.isLoading));
    const bool isLoading = false;

    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Design System Debug'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Color Pairs', icon: Icon(Icons.palette_outlined)),
              Tab(text: 'Typography', icon: Icon(Icons.text_fields_outlined)),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            ColorSchemePreview(),
            TypographyPreview(),
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

    // Gruppierung der Farben nach Funktion
    final sections = <String, List<(Color, Color, String)>>{
      'Accent Colors (Main)': [
        (scheme.primary, scheme.onPrimary, 'Primary'),
        (
          scheme.primaryContainer,
          scheme.onPrimaryContainer,
          'Primary Container'
        ),
        (scheme.secondary, scheme.onSecondary, 'Secondary'),
        (
          scheme.secondaryContainer,
          scheme.onSecondaryContainer,
          'Secondary Container'
        ),
        (scheme.tertiary, scheme.onTertiary, 'Tertiary'),
        (
          scheme.tertiaryContainer,
          scheme.onTertiaryContainer,
          'Tertiary Container'
        ),
      ],
      'Surface & Background (M3)': [
        (scheme.surface, scheme.onSurface, 'Surface Base'),
        (scheme.surfaceDim, scheme.onSurface, 'Surface Dim'),
        (scheme.surfaceBright, scheme.onSurface, 'Surface Bright'),
        (scheme.surfaceContainerLowest, scheme.onSurface, 'Container Lowest'),
        (scheme.surfaceContainerLow, scheme.onSurface, 'Container Low'),
        (scheme.surfaceContainer, scheme.onSurface, 'Container Medium'),
        (scheme.surfaceContainerHigh, scheme.onSurface, 'Container High'),
        (scheme.surfaceContainerHighest, scheme.onSurface, 'Container Highest'),
        (scheme.surfaceVariant, scheme.onSurfaceVariant, 'Surface Variant'),
      ],
      'Feedback & Special': [
        (scheme.error, scheme.onError, 'Error'),
        (scheme.errorContainer, scheme.onErrorContainer, 'Error Container'),
        (scheme.inverseSurface, scheme.onInverseSurface, 'Inverse Surface'),
        (scheme.outline, scheme.onSurface, 'Outline'),
        (scheme.outlineVariant, scheme.onSurfaceVariant, 'Outline Variant'),
        (scheme.scrim, Colors.white, 'Scrim (Shadow/Overlay)'),
      ],
    };

    return ListView(
      padding: const EdgeInsets.all(16),
      children: sections.entries.map((section) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 8, left: 4),
              child: Text(
                section.key,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
            ...section.value.map((pair) => ColorPairCard(
                  label: pair.$3,
                  bgColor: pair.$1,
                  textColor: pair.$2,
                )),
          ],
        );
      }).toList(),
    );
  }
}

class ColorPairCard extends StatelessWidget {
  final String label;
  final Color bgColor;
  final Color textColor;

  const ColorPairCard({
    super.key,
    required this.label,
    required this.bgColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.2),
        ),
      ),
      child: ListTile(
        title: Text(
          label,
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          'Hex: #${bgColor.value.toRadixString(16).toUpperCase().substring(2)}',
          style: TextStyle(
            color: textColor.withOpacity(0.8),
            fontFamily: 'monospace',
            fontSize: 11,
          ),
        ),
        trailing: Icon(Icons.check_circle_outline, color: textColor, size: 20),
      ),
    );
  }
}

class TypographyPreview extends StatelessWidget {
  const TypographyPreview({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    final styles = [
      ('Display Large', textTheme.displayLarge),
      ('Display Medium', textTheme.displayMedium),
      ('Display Small', textTheme.displaySmall),
      ('Headline Large', textTheme.headlineLarge),
      ('Headline Medium', textTheme.headlineMedium),
      ('Headline Small', textTheme.headlineSmall),
      ('Title Large', textTheme.titleLarge),
      ('Title Medium', textTheme.titleMedium),
      ('Title Small', textTheme.titleSmall),
      ('Body Large', textTheme.bodyLarge),
      ('Body Medium', textTheme.bodyMedium),
      ('Body Small', textTheme.bodySmall),
      ('Label Large', textTheme.labelLarge),
      ('Label Medium', textTheme.labelMedium),
      ('Label Small', textTheme.labelSmall),
    ];

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: styles.length,
      separatorBuilder: (context, index) => const Divider(height: 24),
      itemBuilder: (context, index) {
        final (name, style) = styles[index];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name,
                style: textTheme.labelSmall
                    ?.copyWith(color: Theme.of(context).colorScheme.primary)),
            const SizedBox(height: 4),
            Text('The quick brown fox jumps over the lazy dog', style: style),
          ],
        );
      },
    );
  }
}
