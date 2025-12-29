import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

// --- HIER API KEY EINTRAGEN (WICHTIG!) ---
const String MANUAL_API_KEY = "AIzaSyC4d4l6umtA4hErJ6trF-yQgNP7oyEgaPU"; 

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
          tertiary: const Color(0xFF5B618A),
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F7FA),
        cardTheme: CardTheme(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          shadowColor: Colors.black12,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF2A2D3E),
          foregroundColor: Colors.white,
          elevation: 0,
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

// --- DASHBOARD ---
class DashboardPage extends StatelessWidget {
  final List<Map<String, dynamic>> belege;
  const DashboardPage({super.key, required this.belege});

  @override
  Widget build(BuildContext context) {
    double total = 0;
    for(var b in belege) {
      if(b['betrag'] is num) total += (b['betrag'] as num).toDouble();
    }

    return Stack(
      children: [
        Container(
          height: 250,
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [Color(0xFF2A2D3E), Color(0xFF3F4462)]),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
          ),
        ),
        SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Steuer Ultra", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                    Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.settings, color: Colors.white)),
                  ],
                ),
              ),
              Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 15, offset: const Offset(0, 5))]),
                  child: Column(
                    children: [
                      const Text("GESAMTAUSGABEN", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                      const SizedBox(height: 5),
                      Text(NumberFormat.currency(locale: 'de_DE', symbol: '€').format(total), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Color(0xFF2A2D3E))),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 25),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Text("Neueste Belege", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: belege.isEmpty 
                  ? const Center(child: Text("Keine Belege vorhanden", style: TextStyle(color: Colors.grey))) 
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: belege.length,
                      itemBuilder: (ctx, i) => _ReceiptTile(data: belege[i]),
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// --- FOLDERS ---
class FoldersPage extends StatelessWidget {
  final List<Map<String, dynamic>> belege;
  const FoldersPage({super.key, required this.belege});

  @override
  Widget build(BuildContext context) {
    // Gruppieren
    final folders = <String, List<Map<String, dynamic>>>{
      "Büro": [],
      "Material": [],
      "Verpflegung": [],
      "Tanken": [],
      "Reise": [],
      "Technik": [],
      "Privat": [],
      "Sonstiges": [],
    };

    for(var b in belege) {
      String cat = (b['kategorie'] ?? "Sonstiges").toString();
      // Einfaches Matching
      bool found = false;
      for(var key in folders.keys) {
        if (cat.toLowerCase().contains(key.toLowerCase())) {
          folders[key]!.add(b);
          found = true;
          break;
        }
      }
      if(!found) folders["Sonstiges"]!.add(b);
    }

    // Nur Ordner mit Inhalt oder wichtigste anzeigen
    final activeFolders = folders.entries.where((e) => true).toList(); 

    return Scaffold(
      appBar: AppBar(title: const Text("Meine Ordner")),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, crossAxisSpacing: 16, mainAxisSpacing: 16, childAspectRatio: 1.1
        ),
        itemCount: activeFolders.length,
        itemBuilder: (ctx, i) {
          final entry = activeFolders[i];
          final count = entry.value.length;
          final title = entry.key;
          IconData icon;
          Color color;
          
          switch(title) {
            case "Material": icon = Icons.construction; color = Colors.orange; break;
            case "Büro": icon = Icons.desk; color = Colors.blue; break;
            case "Tanken": icon = Icons.local_gas_station; color = Colors.purple; break;
            case "Verpflegung": icon = Icons.restaurant; color = Colors.green; break;
            default: icon = Icons.folder; color = Colors.grey;
          }

          return InkWell(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FolderDetailScreen(title: title, items: entry.value))),
            child: Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(icon, size: 40, color: color),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text("$count Dokumente", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  )
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class FolderDetailScreen extends StatelessWidget {
  final String title;
  final List<Map<String, dynamic>> items;
  const FolderDetailScreen({super.key, required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: items.isEmpty
          ? const Center(child: Text("Leer"))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              itemBuilder: (ctx, i) => _ReceiptTile(data: items[i]),
            ),
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
    await Permission.camera.request();
    final img = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 80);
    if(img != null) {
      _analyze(File(img.path));
    } else {
      if(!mounted) return;
      Navigator.pop(context);
    }
  }

  Future<void> _analyze(File f) async {
    setState(() { _busy = true; _status = "Analysiere Beleg..."; });
    try {
      String key = const String.fromEnvironment('MY_API_KEY');
      if(key.isEmpty) key = MANUAL_API_KEY;
      
      final model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: key);
      final prompt = TextPart('Extrahiere JSON: { "haendler": "String", "datum": "TT.MM.YYYY", "betrag": 0.0, "kategorie": "Material/Büro/Tanken/Verpflegung" }');
      final content = [Content.multi([prompt, DataPart('image/jpeg', await f.readAsBytes())])];
      final res = await model.generateContent(content);
      
      final text = res.text?.replaceAll(RegExp(r'```json|```'), '').trim() ?? "{}";
      final json = jsonDecode(text);
      if(!mounted) return;
      Navigator.pop(context, json);
    } catch(e) {
      setState(() { _busy = false; _status = "Fehler: $e\n\nBitte nochmal versuchen."; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if(_busy) const CircularProgressIndicator(color: Colors.amber),
            const SizedBox(height: 20),
            Text(_status, style: const TextStyle(color: Colors.white), textAlign: TextAlign.center),
            if(!_busy) ElevatedButton(onPressed: _start, child: const Text("Erneut versuchen"))
          ],
        ),
      ),
    );
  }
}

class _ReceiptTile extends StatelessWidget {
  final Map<String, dynamic> data;
  const _ReceiptTile({required this.data});
  @override
  Widget build(BuildContext context) {
    final amt = (data['betrag'] as num?)?.toDouble() ?? 0.0;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(backgroundColor: Colors.indigo.shade50, child: const Icon(Icons.receipt, color: Colors.indigo)),
        title: Text(data['haendler'] ?? "?", style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(data['kategorie'] ?? ""),
        trailing: Text(NumberFormat.currency(locale: 'de_DE', symbol: '€').format(amt), style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}

