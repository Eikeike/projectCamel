import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:project_camel/auth/auth_providers.dart';

class DebugScreen extends ConsumerWidget {
  const DebugScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);

    if (authState.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final userId = authState.userId!; 

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
              //TextThemePreview(),
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

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        const Text('ColorScheme', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        ...entries.map((e) {
          final name = e.$1;
          final color = e.$2;

          return Container(
            margin: const EdgeInsets.symmetric(vertical: 6),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.black12),
            ),
            child: Text(
              name,
              style: TextStyle(
                color: ThemeData.estimateBrightnessForColor(color) == Brightness.dark
                    ? Colors.white
                    : Colors.black,
              ),
            ),
          );
        }),
      ],
    );
  }
}
