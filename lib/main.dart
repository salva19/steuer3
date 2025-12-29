import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

// HINWEIS: Der API Key kommt normalerweise aus den GitHub Secrets.
// Falls du lokal testest, kannst du ihn hier eintragen, aber committe ihn nicht öffentlich!
const String MANUAL_API_KEY = ""; 

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
          seedColor: const Color(0xFF2A2D3E),
          brightness: Brightness.light,
          primary: const Color(0xFF2A2D3E),
          secondary: const Color(0xFFEBC15A),
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F7FA),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF2A2D3E),
          foregroundColor: Colors.white,
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
    }
    setState(() => _loading = false);
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

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardPage(belege: _belege),
      FoldersPage(belege: _belege),
    ];

    return Scaffold(
      body: _loading ? const Center(child: CircularProgressIndicator()) : pages[_idx],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _idx,
        onDestinationSelected: (i) => setState(() => _idx = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Übersicht'),
          NavigationDestination(icon: Icon(Icons.folder_outlined), selectedIcon: Icon(Icons.folder), label: 'Ordner'),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => const ScannerScreen()));
          if (result != null && result is Map<String, dynamic>) {
            _addBeleg(result);
          }
        },
        label: const Text("BELEG SCANNEN"),
        icon: const Icon(Icons.qr_code_scanner),
        backgroundColor: const Color(0xFFEBC15A),
        foregroundColor: Colors.black,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}

class DashboardPage extends StatelessWidget {
  final List<Map<String, dynamic>> belege;
  const DashboardPage({super.key, required this.belege});

  @override
  Widget build(BuildContext context) {
    double total = 0;
    for(var b in belege) {
      if(b['betrag'] is num) total += (b['betrag'] as num).toDouble();
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.only(top: 60, bottom: 30, left: 20, right: 20),
          decoration: const BoxDecoration(
            color: Color(0xFF2A2D3E),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
          ),
          child: Column(
            children: [
              const Text("Gesamtausgaben", style: TextStyle(color: Colors.white70)),
              Text(NumberFormat.currency(locale: 'de_DE', symbol: '€').format(total), 
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: belege.length,
            itemBuilder: (ctx, i) => Card(
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.receipt)),
                title: Text(belege[i]['haendler'] ?? "Unbekannt"),
                subtitle: Text(belege[i]['kategorie'] ?? "Sonstiges"),
                trailing: Text("${belege[i]['betrag']} €"),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class FoldersPage extends StatelessWidget {
  final List<Map<String, dynamic>> belege;
  const FoldersPage({super.key, required this.belege});
  
  @override
  Widget build(BuildContext context) {
    return const Center(child: Text("Ordner Struktur"));
  }
}

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});
  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  String _status = "Kamera starten...";
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    await Permission.camera.request();
    final img = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 80);
    if(img != null) {
      _analyze(File(img.path));
    } else {
      if(mounted) Navigator.pop(context);
    }
  }

  Future<void> _analyze(File f) async {
    setState(() { _busy = true; _status = "KI analysiert Beleg..."; });
    try {
      // Versuche API Key aus Environment (Github Secrets) oder Fallback
      String key = const String.fromEnvironment('MY_API_KEY');
      if(key.isEmpty) key = MANUAL_API_KEY;
      
      if(key.isEmpty) throw "Kein API Key gefunden!";

      final model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: key);
      final prompt = TextPart('Extrahiere JSON: { "haendler": "String", "datum": "TT.MM.YYYY", "betrag": 0.0, "kategorie": "Büro/Verpflegung/Material/Tanken" }');
      final content = [Content.multi([prompt, DataPart('image/jpeg', await f.readAsBytes())])];
      final res = await model.generateContent(content);
      
      final text = res.text?.replaceAll(RegExp(r'```json|```'), '').trim() ?? "{}";
      if(mounted) Navigator.pop(context, jsonDecode(text));
    } catch(e) {
      setState(() { _busy = false; _status = "Fehler: $e"; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if(_busy) const CircularProgressIndicator(),
            const SizedBox(height: 20),
            Text(_status, style: const TextStyle(color: Colors.white), textAlign: TextAlign.center),
            if(!_busy) ElevatedButton(onPressed: _start, child: const Text("Nochmal versuchen"))
          ],
        ),
      ),
    );
  }
}
