import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../main.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  String _version = '';
  String _savedPrefText = 'unknown';

  @override
  void initState() {
    super.initState();
    _loadPackageInfo();
    _loadSavedPref();
  }

  Future<void> _loadSavedPref() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final val = prefs.getBool('isDark');
      setState(() { _savedPrefText = val == null ? 'unset' : val.toString(); });
      debugPrint('AboutScreen: loaded savedPref=$val');
    } catch (e) {
      setState(() { _savedPrefText = 'error'; });
      debugPrint('AboutScreen: failed to read savedPref -> $e');
    }
  }

  Future<void> _loadPackageInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();
      setState(() {
        _version = '${info.version}+${info.buildNumber}';
      });
    } catch (_) {
      setState(() {
        _version = 'unknown';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.findAncestorStateOfType<MyAppState>();
    final isDark = appState?.isDark ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('About', style: TextStyle(color: Colors.white)),
        centerTitle: true,
        backgroundColor: const Color(0xFFCB3231),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const FlutterLogo(size: 96),
              const SizedBox(height: 16),
              const Text('P3 Mulo GPS Tracker App', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Version: ${_version.isEmpty ? '...' : _version}'),
              const SizedBox(height: 12),
              const Text('Author:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text('Magnus Zimmer (magnuszimmer11@gmail.com)'),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Dark mode'),
                value: isDark,
                onChanged: (v) {
                  debugPrint('AboutScreen: switch toggled -> $v; appState is ${appState == null ? 'null' : 'present'}');
                  if (appState == null) {
                    // If appState is not found, write a warning to help debugging.
                    debugPrint('AboutScreen: Unable to find MyAppState in context');
                  }
                  appState?.setDark(v);
                  debugPrint('AboutScreen: called setDark($v); appState.isDark=${appState?.isDark}');
                  // Refresh saved-pref indicator after a short delay to allow write to complete.
                  Future.delayed(const Duration(milliseconds: 150), _loadSavedPref);
                  setState(() {}); // update local UI to reflect new state immediately
                },
              ),
              const SizedBox(height: 8),
              Text('Saved preference: ${_savedPrefText == 'true' ? 'Dark' : _savedPrefText == 'false' ? 'Light' : _savedPrefText}'),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              )
            ],
          ),
        ),
      ),
    );
  }
}
