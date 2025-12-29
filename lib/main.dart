import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

void main() {
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(const SteuerUltraApp());
}

class SteuerUltraApp extends StatelessWidget {
  const SteuerUltraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Steuer Ultra',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Roboto',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F172A),
          primary: const Color(0xFF0F172A),
          secondary: const Color(0xFF3B82F6),
          background: const Color(0xFFF8FAFC),
        ),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        cardTheme: CardTheme(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          color: Colors.white,
          margin: const EdgeInsets.only(bottom: 12),
        ),
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _idx = 0;
  List<Map<String, dynamic>> _belege = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString('belege_data');
    
    if (data != null) {
      setState(() {
        _belege = List<Map<String, dynamic>>.from(jsonDecode(data));
      });
    } else {
      _belege = _getDemoData();
      _saveData();
    }
    setState(() => _loading = false);
  }

  List<Map<String, dynamic>> _getDemoData() {
    return [
      {"haendler": "Telekom", "datum": "02.01.2025", "betrag": 39.95, "kategorie": "Internet/Telefon"},
      {"haendler": "HUK Coburg", "datum": "01.01.2025", "betrag": 120.50, "kategorie": "Versicherung"},
      {"haendler": "IKEA", "datum": "28.12.2025", "betrag": 249.00, "kategorie": "Home-Office"},
      {"haendler": "Apotheke am Eck", "datum": "15.12.2025", "betrag": 42.90, "kategorie": "Gesundheit"},
      {"haendler": "Tankstelle Nord", "datum": "10.12.2025", "betrag": 78.50, "kategorie": "Fahrtkosten"},
      {"haendler": "Malerbetrieb Müller", "datum": "05.12.2025", "betrag": 450.00, "kategorie": "Handwerker"},
    ];
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('belege_data', jsonEncode(_belege));
  }

  void _addBeleg(Map<String, dynamic> data) {
    setState(() {
      _belege.insert(0, data);
      _saveData();
    });
  }

  void _deleteBeleg(int index) {
    setState(() {
      _belege.removeAt(index);
      _saveData();
    });
  }

  void _deleteAll() {
    setState(() {
      _belege.clear();
      _saveData();
    });
  }

  Future<void> _exportCsv() async {
    if (_belege.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Keine Daten vorhanden!")));
      return;
    }
    try {
      StringBuffer csvBuffer = StringBuffer();
      csvBuffer.writeln("Datum;Haendler;Kategorie;Betrag (EUR)"); 
      for (var item in _belege) {
        String datum = item['datum'] ?? "";
        String haendler = (item['haendler'] ?? "").replaceAll(";", ","); 
        String kat = item['kategorie'] ?? "";
        String betrag = (item['betrag'] ?? 0).toString().replaceAll(".", ","); 
        csvBuffer.writeln("$datum;$haendler;$kat;$betrag");
      }
      final directory = await getTemporaryDirectory();
      final path = '${directory.path}/Steuer_Export_${DateTime.now().year}.csv';
      final file = File(path);
      await file.writeAsString(csvBuffer.toString());
      await Share.shareXFiles([XFile(path)], text: 'Mein Steuer Ultra Export');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Fehler: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardPage(belege: _belege, onDelete: _deleteBeleg),
      SettingsPage(onDeleteAll: _deleteAll, onExport: _exportCsv),
    ];

    return Scaffold(
      body: _loading ? const Center(child: CircularProgressIndicator()) : pages[_idx],
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20)]),
        child: NavigationBar(
          selectedIndex: _idx,
          onDestinationSelected: (i) => setState(() => _idx = i),
          backgroundColor: Colors.white,
          height: 70,
          destinations: const [
            NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), selectedIcon: Icon(Icons.account_balance_wallet, color: Color(0xFF0F172A)), label: 'Steuer'),
            NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings, color: Color(0xFF0F172A)), label: 'Einstellungen'),
          ],
        ),
      ),
      floatingActionButton: _idx == 0 
          ? FloatingActionButton.extended(
              onPressed: () async {
                final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => const ScannerScreen()));
                if (result != null && result is Map<String, dynamic>) _addBeleg(result);
              },
              label: const Text("BELEG PRÜFEN", style: TextStyle(fontWeight: FontWeight.bold)),
              icon: const Icon(Icons.qr_code_scanner),
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}

class DashboardPage extends StatelessWidget {
  final List<Map<String, dynamic>> belege;
  final Function(int) onDelete;
  const DashboardPage({super.key, required this.belege, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    double total = 0;
    for(var b in belege) { if(b['betrag'] is num) total += (b['betrag'] as num).toDouble(); }

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(24, 70, 24, 30),
          decoration: const BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF0F172A), Color(0xFF334155)]),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Absetzbare Summe", style: TextStyle(color: Colors.white70)),
              Text(NumberFormat.currency(locale: 'de_DE', symbol: '€').format(total), style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w800, color: Colors.white)),
            ],
          ),
        ),
        Expanded(
          child: belege.isEmpty ? const Center(child: Text("Keine Daten")) : ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: belege.length,
            separatorBuilder: (_,__) => const SizedBox(height: 12),
            itemBuilder: (ctx, i) {
              final item = belege[i];
              return Dismissible(
                key: Key(item.hashCode.toString()),
                onDismissed: (_) => onDelete(i),
                background: Container(color: Colors.red),
                child: Card(
                  child: ListTile(
                    leading: Icon(_getIconForCategory(item['kategorie'])),
                    title: Text(item['haendler'] ?? "Unbekannt", style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(item['kategorie'] ?? "Sonstiges"),
                    trailing: Text(NumberFormat.currency(locale: 'de_DE', symbol: '€').format(item['betrag']), style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  IconData _getIconForCategory(String? cat) {
    if (cat == null) return Icons.receipt;
    final c = cat.toLowerCase();
    if (c.contains('internet') || c.contains('telefon')) return Icons.wifi;
    if (c.contains('versicherung')) return Icons.shield_outlined;
    if (c.contains('home') || c.contains('office')) return Icons.desk;
    if (c.contains('gesundheit')) return Icons.medical_services_outlined;
    if (c.contains('fahrt') || c.contains('tank')) return Icons.directions_car;
    if (c.contains('handwerker')) return Icons.build;
    if (c.contains('bewirtung')) return Icons.restaurant;
    return Icons.receipt_long;
  }
}

class SettingsPage extends StatefulWidget {
  final VoidCallback onDeleteAll;
  final VoidCallback onExport;
  const SettingsPage({super.key, required this.onDeleteAll, required this.onExport});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final TextEditingController _controller = TextEditingController();
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _loadKey();
  }

  Future<void> _loadKey() async {
    final prefs = await SharedPreferences.getInstance();
    _controller.text = prefs.getString('custom_api_key') ?? "";
  }

  Future<void> _saveKey() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('custom_api_key', _controller.text.trim());
    setState(() => _saved = true);
    if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Gespeichert!")));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Einstellungen"), backgroundColor: Colors.transparent, elevation: 0),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          TextField(controller: _controller, obscureText: true, decoration: const InputDecoration(labelText: "Google Gemini API Key", border: OutlineInputBorder())),
          const SizedBox(height: 10),
          ElevatedButton(onPressed: _saveKey, style: ElevatedButton.styleFrom(backgroundColor: _saved ? Colors.green : const Color(0xFF0F172A)), child: Text(_saved ? "GESPEICHERT" : "SPEICHERN", style: const TextStyle(color: Colors.white))),
          const SizedBox(height: 30),
          ListTile(leading: const Icon(Icons.share, color: Colors.blue), title: const Text("Exportieren (CSV)"), onTap: widget.onExport, tileColor: Colors.white),
          const SizedBox(height: 10),
          ListTile(leading: const Icon(Icons.delete_forever, color: Colors.red), title: const Text("Alles löschen"), onTap: widget.onDeleteAll, tileColor: Colors.white),
        ],
      ),
    );
  }
}

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});
  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  String _status = "Kamera wird gestartet...";
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    final prefs = await SharedPreferences.getInstance();
    final apiKey = prefs.getString('custom_api_key');
    if (apiKey == null || apiKey.isEmpty) {
      if (!mounted) return;
      showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text("Key fehlt"), actions: [TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text("OK"))]));
      return;
    }
    await Permission.camera.request();
    final img = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 85);
    if(img != null) _analyze(File(img.path), apiKey);
    else if(mounted) Navigator.pop(context);
  }

  Future<void> _analyze(File f, String key) async {
    setState(() { _busy = true; _status = "Analysiere..."; });
    try {
      final model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: key);
      const promptText = '''Analysiere Beleg für Steuer. Antworte NUR JSON: {"haendler": "x", "datum": "TT.MM.YYYY", "betrag": 0.0, "kategorie": "Arbeitsmittel/Internet/Home-Office/Fahrtkosten/Gesundheit/Handwerker/Versicherung/Kinder/Bewirtung/Sonstiges"}''';
      final res = await model.generateContent([Content.multi([TextPart(promptText), DataPart('image/jpeg', await f.readAsBytes())])]);
      String text = res.text?.replaceAll(RegExp(r'```json|```'), '').trim() ?? "{}";
      final startIndex = text.indexOf('{');
      final endIndex = text.lastIndexOf('}');
      if (startIndex != -1 && endIndex != -1) text = text.substring(startIndex, endIndex + 1);
      if(mounted) Navigator.pop(context, jsonDecode(text));
    } catch(e) {
      setState(() { _busy = false; _status = "Fehler: $e"; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(backgroundColor: Colors.black, body: Center(child: Text(_status, style: const TextStyle(color: Colors.white))));
  }
}
