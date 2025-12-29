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
      // Initiale Demo-Daten für den ersten Start
      _belege = _getDemoData();
      _saveData();
    }
    setState(() => _loading = false);
  }

  List<Map<String, dynamic>> _getDemoData() {
    return [
      {"haendler": "Telekom", "datum": "02.01.2025", "betrag": 39.95, "kategorie": "Internet/Telefon"},
      {"haendler": "HUK Coburg", "datum": "01.01.2025", "betrag": 120.50, "kategorie": "Versicherung"},
      {"haendler": "IKEA (Schreibtisch)", "datum": "28.12.2025", "betrag": 249.00, "kategorie": "Home-Office"},
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

  // --- NEU: EXPORT FUNKTION ---
  Future<void> _exportCsv() async {
    if (_belege.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Keine Daten zum Exportieren da!")));
      return;
    }

    try {
      // 1. CSV String bauen
      StringBuffer csvBuffer = StringBuffer();
      csvBuffer.writeln("Datum;Haendler;Kategorie;Betrag (EUR)"); // Header

      for (var item in _belege) {
        String datum = item['datum'] ?? "";
        String haendler = (item['haendler'] ?? "").replaceAll(";", ","); // Semikolon entfernen um CSV nicht zu brechen
        String kat = item['kategorie'] ?? "";
        String betrag = (item['betrag'] ?? 0).toString().replaceAll(".", ","); // Deutsches Format
        
        csvBuffer.writeln("$datum;$haendler;$kat;$betrag");
      }

      // 2. Datei speichern
      final directory = await getTemporaryDirectory();
      final path = '${directory.path}/Steuer_Export_${DateTime.now().year}.csv';
      final file = File(path);
      await file.writeAsString(csvBuffer.toString());

      // 3. Teilen Dialog öffnen
      await Share.shareXFiles([XFile(path)], text: 'Mein Steuer Ultra Export');
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Export Fehler: $e")));
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
        decoration: const BoxDecoration(
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20)],
        ),
        child: NavigationBar(
          selectedIndex: _idx,
          onDestinationSelected: (i) => setState(() => _idx = i),
          backgroundColor: Colors.white,
          height: 70,
          destinations: const [
            NavigationDestination(
                icon: Icon(Icons.account_balance_wallet_outlined), 
                selectedIcon: Icon(Icons.account_balance_wallet, color: Color(0xFF0F172A)), 
                label: 'Steuer'),
            NavigationDestination(
                icon: Icon(Icons.settings_outlined), 
                selectedIcon: Icon(Icons.settings, color: Color(0xFF0F172A)), 
                label: 'Einstellungen'),
          ],
        ),
      ),
      floatingActionButton: _idx == 0 
          ? FloatingActionButton.extended(
              onPressed: () async {
                final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => const ScannerScreen()));
                if (result != null && result is Map<String, dynamic>) {
                  _addBeleg(result);
                }
              },
              label: const Text("BELEG PRÜFEN", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
              icon: const Icon(Icons.qr_code_scanner),
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}

// --- DASHBOARD ---
class DashboardPage extends StatelessWidget {
  final List<Map<String, dynamic>> belege;
  final Function(int) onDelete;
  
  const DashboardPage({super.key, required this.belege, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    double total = 0;
    for(var b in belege) {
      if(b['betrag'] is num) total += (b['betrag'] as num).toDouble();
    }

    return Column(
      children: [
        // Modern Header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(24, 70, 24, 30),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0F172A), Color(0xFF334155)],
            ),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Steuerjahr 2025", style: TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.bold)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: Colors.green.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                    child: const Text("Optimiert", style: TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                  )
                ],
              ),
              const SizedBox(height: 12),
              const Text("Absetzbare Summe", style: TextStyle(color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 4),
              Text(
                NumberFormat.currency(locale: 'de_DE', symbol: '€').format(total), 
                style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w800, color: Colors.white)
              ),
              const SizedBox(height: 20),
              // Stats
              Row(
                children: [
                   _StatBadge(icon: Icons.receipt, label: "${belege.length} Belege"),
                   const SizedBox(width: 12),
                   _StatBadge(icon: Icons.category, label: "${belege.map((e) => e['kategorie']).toSet().length} Kategorien"),
                ],
              )
            ],
          ),
        ),
        
        // Liste
        Expanded(
          child: belege.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.description_outlined, size: 64, color: Colors.grey.shade300),
                    const SizedBox(height: 16),
                    Text("Noch keine Daten", style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
                  ],
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(20),
                itemCount: belege.length,
                separatorBuilder: (_,__) => const SizedBox(height: 12),
                itemBuilder: (ctx, i) {
                  final item = belege[i];
                  final catColor = _getColorForCategory(item['kategorie']);
                  return Dismissible(
                    key: Key(item.hashCode.toString()),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 24),
                      decoration: BoxDecoration(color: Colors.red.shade100, borderRadius: BorderRadius.circular(16)),
                      child: const Icon(Icons.delete_outline, color: Colors.red),
                    ),
                    onDismissed: (_) => onDelete(i),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: catColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(_getIconForCategory(item['kategorie']), color: catColor),
                        ),
                        title: Text(item['haendler'] ?? "Unbekannt", style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(item['kategorie'] ?? "Sonstiges", style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              NumberFormat.currency(locale: 'de_DE', symbol: '€').format(item['betrag']), 
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)
                            ),
                            Text(item['datum'] ?? "", style: TextStyle(color: Colors.grey.shade400, fontSize: 10)),
                          ],
                        ),
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
    
    // Icons für die neuen Kategorien
    if (c.contains('internet') || c.contains('telefon')) return Icons.wifi;
    if (c.contains('versicherung')) return Icons.shield_outlined;
    if (c.contains('home') || c.contains('office') || c.contains('arbeitszimmer')) return Icons.desk;
    if (c.contains('kinder') || c.contains('kita')) return Icons.child_care;
    if (c.contains('haushalt') || c.contains('garten') || c.contains('reinigung')) return Icons.cleaning_services;
    
    // Standard Icons
    if (c.contains('gesundheit') || c.contains('arzt') || c.contains('apotheke')) return Icons.medical_services_outlined;
    if (c.contains('fahrt') || c.contains('tank') || c.contains('bahn')) return Icons.directions_car;
    if (c.contains('arbeitsmittel') || c.contains('technik') || c.contains('software')) return Icons.computer;
    if (c.contains('handwerker')) return Icons.build_outlined;
    if (c.contains('bewirtung') || c.contains('verpflegung')) return Icons.restaurant;
    
    return Icons.receipt_long;
  }

  Color _getColorForCategory(String? cat) {
    if (cat == null) return Colors.grey;
    final c = cat.toLowerCase();
    
    if (c.contains('internet') || c.contains('telefon')) return Colors.purple;
    if (c.contains('versicherung')) return Colors.indigo;
    if (c.contains('home')) return Colors.teal;
    if (c.contains('kinder')) return Colors.pinkAccent;
    if (c.contains('gesundheit')) return Colors.redAccent;
    if (c.contains('fahrt')) return Colors.blue;
    if (c.contains('handwerker') || c.contains('haushalt')) return Colors.orange;
    
    return Colors.blueGrey;
  }
}

class _StatBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  const _StatBadge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white70, size: 14),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
        ],
      ),
    );
  }
}

// --- EINSTELLUNGEN ---
class SettingsPage extends StatefulWidget {
  final VoidCallback onDeleteAll;
  final VoidCallback onExport; // Neuer Callback für Export
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
    if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("API Key gespeichert!")));
    Future.delayed(const Duration(seconds: 2), () {
      if(mounted) setState(() => _saved = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Einstellungen", style: TextStyle(color: Colors.black)), 
        backgroundColor: Colors.transparent, 
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle("KI Verbindung"),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
              child: Column(
                children: [
                  TextField(
                    controller: _controller,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: "Google Gemini API Key",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.key),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _saveKey,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _saved ? Colors.green : const Color(0xFF0F172A),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(_saved ? "GESPEICHERT ✓" : "KEY SPEICHERN", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
            _buildSectionTitle("Daten-Export"),
            Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
              child: ListTile(
                leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.ios_share, color: Colors.blue)),
                title: const Text("Als CSV exportieren"),
                subtitle: const Text("Für Excel oder WISO Steuer"),
                trailing: const Icon(Icons.chevron_right),
                onTap: widget.onExport, // Ruft die Export Funktion auf
              ),
            ),

            const SizedBox(height: 32),
            _buildSectionTitle("Datenbank"),
            Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
              child: ListTile(
                leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.delete_forever, color: Colors.red)),
                title: const Text("Alles löschen"),
                subtitle: const Text("Setzt die App zurück"),
                onTap: () {
                  showDialog(context: context, builder: (ctx) => AlertDialog(
                    title: const Text("Achtung"),
                    content: const Text("Wirklich alle Belege löschen?"),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Abbrechen")),
                      TextButton(onPressed: () {
                        widget.onDeleteAll();
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Daten gelöscht.")));
                      }, child: const Text("Löschen", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
                    ],
                  ));
                },
              ),
            ),
            
            const SizedBox(height: 40),
            Center(child: Text("Steuer Ultra v1.3 Export", style: TextStyle(color: Colors.grey.shade400, fontSize: 12))),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blueGrey, letterSpacing: 1)),
    );
  }
}

// --- SCANNER ---
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
      showDialog(context: context, builder: (ctx) => AlertDialog(
        title: const Text("API Key fehlt"),
        content: const Text("Bitte trage in den Einstellungen deinen Google API Key ein."),
        actions: [TextButton(onPressed: () { Navigator.pop(ctx); Navigator.pop(context); }, child: const Text("OK"))],
      ));
      return;
    }

    await Permission.camera.request();
    final img = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 85);
    if(img != null) _analyze(File(img.path), apiKey);
    else if(mounted) Navigator.pop(context);
  }

  Future<void> _analyze(File f, String key) async {
    setState(() { _busy = true; _status = "Analysiere Beleg..."; });
    try {
      final model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: key);
      
      const promptText = '''
      Analysiere diesen Beleg für die Steuererklärung.
      Antworte NUR mit diesem JSON-Format (kein Markdown):
      {
        "haendler": "Name",
        "datum": "TT.MM.YYYY",
        "betrag": 0.00,
        "kategorie": "WÄHLE: 'Arbeitsmittel', 'Home-Office', 'Internet/Telefon', 'Fahrtkosten', 'Gesundheit', 'Handwerker', 'Haushaltsnahe DL', 'Versicherung', 'Kinderbetreuung', 'Bewirtung' oder 'Sonstiges'"
      }
      ''';

      final prompt = TextPart(promptText);
      final content = [Content.multi([prompt, DataPart('image/jpeg', await f.readAsBytes())])];
      final res = await model.generateContent(content);
      
      String text = res.text?.replaceAll(RegExp(r'```json|```'), '').trim() ?? "{}";
      final startIndex = text.indexOf('{');
      final endIndex = text.lastIndexOf('}');
      if (startIndex != -1 && endIndex != -1) {
        text = text.substring(startIndex, endIndex + 1);
      }

      if(mounted) Navigator.pop(context, jsonDecode(text));
    } catch(e) {
      setState(() { _busy = false; _status = "Fehler: $e\n\nNochmal versuchen."; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if(_busy) const SizedBox(width: 60, height: 60, child: CircularProgressIndicator(color: Colors.blueAccent)),
              const SizedBox(height: 32),
              Text(_status, style: const TextStyle(color: Colors.white, fontSize: 16), textAlign: TextAlign.center),
              if(!_busy) Padding(
                padding: const EdgeInsets.only(top: 32),
                child: ElevatedButton(onPressed: _start, child: const Text("Neuer Versuch")),
              )
            ],
          ),
        ),
      ),
    );
  }
}
