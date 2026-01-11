import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants.dart';
import '../core/color_constants.dart';
import '../theme/theme_provider.dart';
// Importiere den neuen Provider hier (Pfad ggf. anpassen):
import '../services/secret_settings_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  // --- LOKALER STATE ---
  // Dieser Zähler bleibt lokal, da er nur für die aktuelle Session relevant ist
  int _easterEggTapCount = 0;

  // Platzhalter für Biermodus
  bool _tempBeerMode = false;

  void _handleVersionTap() {
    // 1. Status aus dem neuen Notifier lesen
    final isUnlocked = ref.read(secretSettingsProvider);

    if (isUnlocked) return; // Bereits freigeschaltet, nichts tun

    setState(() {
      _easterEggTapCount++;
    });

    // Feedback zwischen 3 und 7 Klicks
    if (_easterEggTapCount >= 3 && _easterEggTapCount < 7) {
      final remaining = 7 - _easterEggTapCount;
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Du bist noch $remaining Schritte von den Geheimen Optionen entfernt...',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          duration: const Duration(milliseconds: 500),
        ),
      );
    }

    // Freischaltung
    if (_easterEggTapCount >= 7) {
      // 2. UNLOCK AUFRUFEN (über den Notifier)
      ref.read(secretSettingsProvider.notifier).unlock();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Geheime Optionen dauerhaft freigeschaltet!',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
          backgroundColor: Theme.of(context).colorScheme.primary,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // THEME STATE
    final themeState = ref.watch(themeProvider);
    final currentMode = themeState.mode;
    final bool useSystem = currentMode == ThemeMode.system;

    // --- NEU: HIER DEN STATUS WATCHEN ---
    final bool isSecretMenuVisible = ref.watch(secretSettingsProvider);

    // Prüfen für Vorschau: Ist es dunkel?
    final bool isPreviewDark = useSystem
        ? MediaQuery.of(context).platformBrightness == Brightness.dark
        : currentMode == ThemeMode.dark;

    // Theme Optionen laden
    final List<Map<String, dynamic>> themeOptions = AppConstants.themeOptions;

    return Scaffold(
      appBar: AppBar(title: const Text('Einstellungen')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ================================================================
            // 1. DARSTELLUNG
            // ================================================================
            const Text(
              'Darstellung',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Text('App-Design wählen',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(height: 16),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: List.generate(themeOptions.length, (index) {
                        final color = themeOptions[index]['seed'] as Color;
                        final isSelected =
                            themeState.seedColor.value == color.value;
                        return _buildRealM3Preview(
                          context: context,
                          name: themeOptions[index]['name'],
                          seedColor: color,
                          isDark: isPreviewDark,
                          isSelected: isSelected,
                          onTap: () => ref
                              .read(themeProvider.notifier)
                              .setSeedColor(color),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Divider(indent: 20, endIndent: 20),
                  SwitchListTile(
                    title: const Text('Systemeinstellung'),
                    subtitle: const Text('Automatisch anpassen'),
                    secondary: const Icon(Icons.settings_system_daydream),
                    value: useSystem,
                    onChanged: (val) {
                      if (val) {
                        ref
                            .read(themeProvider.notifier)
                            .setThemeMode(ThemeMode.system);
                      } else {
                        final isDark =
                            MediaQuery.of(context).platformBrightness ==
                                Brightness.dark;
                        ref.read(themeProvider.notifier).setThemeMode(
                            isDark ? ThemeMode.dark : ThemeMode.light);
                      }
                    },
                  ),
                  SwitchListTile(
                    title: const Text('Dunkelmodus'),
                    subtitle: Text(useSystem
                        ? 'Vom System verwaltet'
                        : (isPreviewDark ? 'Aktiviert' : 'Deaktiviert')),
                    secondary: Icon(
                        isPreviewDark ? Icons.dark_mode : Icons.light_mode),
                    value: isPreviewDark,
                    onChanged: useSystem
                        ? null
                        : (val) => ref
                            .read(themeProvider.notifier)
                            .setThemeMode(
                                val ? ThemeMode.dark : ThemeMode.light),
                  ),
                ],
              ),
            ),

            // ================================================================
            // 2. DATEN & SYNCHRONISIERUNG
            // ================================================================
            const SizedBox(height: 32),
            const Text(
              'Daten & Sync',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.sync),
                    title: const Text('Jetzt synchronisieren'),
                    subtitle: const Text('Daten manuell mit Server abgleichen'),
                    onTap: () {
                      debugPrint("Sync Button gedrückt (Placeholder)");
                    },
                  ),
                  const Divider(indent: 16, endIndent: 16, height: 1),
                  ListTile(
                    leading: const Icon(Icons.wifi_protected_setup),
                    title: const Text('Nur im WLAN'),
                    subtitle: const Text('Datensparmodus (Beta)'),
                    trailing: Switch(
                      value: false, // Dummy für UI
                      onChanged: (val) {
                        // TODO: Implementieren wenn gewünscht
                      },
                    ),
                  ),
                ],
              ),
            ),

            // ================================================================
            // 3. GEHEIME OPTIONEN (EASTER EGG)
            // ================================================================
            // Hier nutzen wir nun die Variable aus dem Provider
            if (isSecretMenuVisible) ...[
              const SizedBox(height: 32),
              Row(
                children: [
                  Icon(Icons.build_circle_outlined,
                      color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Geheime Optionen',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primaryContainer
                      .withOpacity(0.5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withOpacity(0.2)),
                ),
                child: Column(
                  children: [
                    // SLIDER 1: Legacy Theme
                    SwitchListTile(
                      title: const Text('Legacy Farbtheme'),
                      subtitle: const Text(
                          'Setzt das Farbthema auf die Farben der Alpha-Version zurück.'),
                      activeColor: Theme.of(context).colorScheme.primary,
                      secondary: Icon(Icons.history,
                          color: Theme.of(context).colorScheme.primary),

                      // ECHTER WERT AUS DEM THEME PROVIDER
                      value: themeState.isLegacyMode,

                      onChanged: (val) {
                        ref.read(themeProvider.notifier).setLegacyMode(val);
                        if (val) {
                          // Post frame callback für die Snackbar
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      "Zurück in die Zukunft... oder Vergangenheit? 🕰️"),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            }
                          });
                        }
                      },
                    ),

                    Divider(
                        height: 1,
                        indent: 16,
                        endIndent: 16,
                        color: Theme.of(context)
                            .colorScheme
                            .onPrimaryContainer
                            .withOpacity(0.2)),

                    // SLIDER 2: Biermodus
                    SwitchListTile(
                      title: const Text('Biermodus'),
                      subtitle: const Text(
                          'Verändert die Strings auf der 7-Segment-Anzeige des Gerätes.'),
                      activeColor: Theme.of(context).colorScheme.primary,
                      secondary: Icon(Icons.sports_bar,
                          color: Theme.of(context).colorScheme.primary),
                      value: _tempBeerMode,
                      onChanged: (val) {
                        setState(() => _tempBeerMode = val);
                        if (val) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("O'zapft is! 🍻")));
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],

            // ================================================================
            // 4. INFO
            // ================================================================
            const SizedBox(height: 32),
            const Text(
              'Info',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.description_outlined),
                    title: const Text('Open Source Lizenzen'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => showLicensePage(
                      context: context,
                      applicationName: 'Bierorgl',
                      applicationIcon: const Icon(Icons.sports_bar),
                      applicationVersion: '1.0.0',
                    ),
                  ),
                  const Divider(indent: 16, endIndent: 16, height: 1),

                  // --- APP VERSION TILE MIT EASTER EGG TRIGGER ---
                  InkWell(
                    onTap: _handleVersionTap,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                    child: ListTile(
                      leading: const Icon(Icons.info_outline),
                      title: const Text('App Version'),
                      trailing: Text(
                        '1.0.0',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ================================================================
            // 5. BENUTZERKONTO
            // ================================================================
            const SizedBox(height: 32),
            const Text(
              'Benutzerkonto',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(Icons.logout,
                        color: Theme.of(context).colorScheme.error),
                    title: Text('Abmelden',
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontWeight: FontWeight.w500)),
                    onTap: () => _showLogoutDialog(context, ref),
                  ),
                  const Divider(indent: 16, endIndent: 16, height: 1),
                  ListTile(
                    leading: Icon(Icons.delete_forever,
                        color: Theme.of(context).colorScheme.error),
                    title: Text('Konto löschen',
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error)),
                    onTap: () => _showDeleteAccountDialog(context),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // --- HILFSMETHODEN FÜR DIALOGE ---

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Abmelden?'),
        content: const Text('Möchtest du dich wirklich aus der App abmelden?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              debugPrint("User hat Logout geklickt");
            },
            child: const Text('Abmelden'),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konto löschen'),
        content: const Text(
          'Achtung: Diese Aktion kann nicht rückgängig gemacht werden. Alle deine Events und Daten werden unwiderruflich gelöscht.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () {
              Navigator.pop(context);
              debugPrint("User will Konto löschen");
            },
            child: const Text('Endgültig löschen'),
          ),
        ],
      ),
    );
  }

  // --- VORSCHAU WIDGET ---
  Widget _buildRealM3Preview({
    required BuildContext context,
    required String name,
    required Color seedColor,
    required bool isDark,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final ColorScheme previewScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: isDark ? Brightness.dark : Brightness.light,
    );

    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(right: 12),
        child: Column(
          children: [
            Container(
              width: 80,
              height: 120,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: isSelected
                    ? Border.all(
                        color: Theme.of(context).colorScheme.primary, width: 3)
                    : Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant,
                        width: 1),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withOpacity(0.25),
                            blurRadius: 8,
                            offset: const Offset(0, 4))
                      ]
                    : [],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: Material(
                  color: previewScheme.surface,
                  child: Column(
                    children: [
                      Container(
                        height: 32,
                        width: double.infinity,
                        color: previewScheme.surfaceContainer,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        alignment: Alignment.centerLeft,
                        child: Row(children: [
                          Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                  color: previewScheme.onSurfaceVariant,
                                  shape: BoxShape.circle)),
                          const SizedBox(width: 6),
                          Container(
                              width: 30,
                              height: 4,
                              decoration: BoxDecoration(
                                  color: previewScheme.onSurface,
                                  borderRadius: BorderRadius.circular(2))),
                        ]),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                    height: 20,
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                        color: previewScheme.secondaryContainer,
                                        borderRadius:
                                            BorderRadius.circular(6))),
                                const SizedBox(height: 6),
                                Container(
                                    height: 4,
                                    width: 40,
                                    color:
                                        previewScheme.outline.withOpacity(0.5)),
                                const Spacer(),
                                Align(
                                    alignment: Alignment.bottomRight,
                                    child: Container(
                                        width: 20,
                                        height: 20,
                                        decoration: BoxDecoration(
                                            color:
                                                previewScheme.primaryContainer,
                                            borderRadius:
                                                BorderRadius.circular(6)),
                                        child: Icon(Icons.edit,
                                            size: 12,
                                            color: previewScheme
                                                .onPrimaryContainer)))
                              ]),
                        ),
                      )
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(name,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}
