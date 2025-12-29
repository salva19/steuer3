import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';

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
        fontFamily: 'Roboto', // Standard sans-serif
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2A2D3E), // Dark Navy
          brightness: Brightness.light,
          primary: const Color(0xFF2A2D3E),
          secondary: const Color(0xFFEBC15A), // Gold Accent
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
      home: const DashboardScreen(),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // Lokale Session-Liste für Belege (in echter App Database nutzen)
  List<Map<String, dynamic>> _belege = [];
  double _totalExpenses = 0.00;

  void _addBeleg(Map<String, dynamic> data) {
    setState(() {
      _belege.insert(0, data);
      if (data['betrag'] != null && data['betrag'] is num) {
        _totalExpenses += (data['betrag'] as num).toDouble();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Header
          Container(
            height: 280,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF2A2D3E), Color(0xFF3F4462)],
              ),
              borderRadius: BorderRadius.only(bottomLeft: Radius.circular(40), bottomRight: Radius.circular(40)),
            ),
          ),
          
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Content
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Guten Tag,", style: TextStyle(color: Colors.white70, fontSize: 14)),
                          Text("Steuerübersicht", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.notifications_outlined, color: Colors.white),
                      )
                    ],
                  ),
                ),

                // Expense Summary Card
                Center(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 10)),
                      ],
                    ),
                    child: Column(
                      children: [
                        const Text("LIMIT DIESEN MONAT", style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                        const SizedBox(height: 10),
                        Text(
                          NumberFormat.currency(locale: 'de_DE', symbol: '€').format(_totalExpenses),
                          style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: Color(0xFF2A2D3E)),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _QuickStat(icon: Icons.receipt_long, label: "${_belege.length} Belege", color: Colors.blue),
                            _QuickStat(icon: Icons.pie_chart, label: "Jahresabschluss", color: Colors.amber),
                            _QuickStat(icon: Icons.upload_file, label: "Export", color: Colors.green),
                          ],
                        )
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 25),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: Text("Letzte Aktivitäten", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2A2D3E))),
                ),
                const SizedBox(height: 10),

                // List of Receipts
                Expanded(
                  child: _belege.isEmpty 
                    ? _EmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        itemCount: _belege.length,
                        itemBuilder: (ctx, i) => _ReceiptTile(data: _belege[i]),
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
      
      // Floating Scan Button
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => const ScannerScreen()));
          if (result != null && result is Map<String, dynamic>) {
            _addBeleg(result);
          }
        },
        label: const Text("BELEG SCANNEN"),
        icon: const Icon(Icons.qr_code_scanner),
        backgroundColor: const Color(0xFF2A2D3E),
        foregroundColor: Colors.white,
        elevation: 8,
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
  String _statusText = "Kamera starten...";
  bool _isAnalyzing = false;
  File? _image;

  final String envKey = const String.fromEnvironment('MY_API_KEY');

  Future<void> _takePicture() async {
    await Permission.camera.request();
    final picker = ImagePicker();
    final xfile = await picker.pickImage(source: ImageSource.camera, imageQuality: 85);

    if (xfile != null) {
      setState(() {
        _image = File(xfile.path);
        _isAnalyzing = true;
        _statusText = "KI analysiert Beleg...";
      });
      _analyzeImage(File(xfile.path));
    }
  }

  Future<void> _analyzeImage(File img) async {
    try {
      // 1. Key bestimmen (Fallback auf Manual)
      String key = envKey;
      if (key.isEmpty) key = MANUAL_API_KEY;

      if (key.isEmpty || key.contains("DEIN KEY")) {
        throw "Kein API Key gefunden!\nBitte MANUAL_API_KEY in main.dart setzen.";
      }

      // 2. Gemini Setup
      final model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: key);
      final prompt = TextPart('''
        Du bist Steuer-Profi. Extrahiere JSON aus dem Foto:
        { "haendler": "String", "datum": "TT.MM.YYYY", "betrag": 0.00, "kategorie": "String" }
        Nur JSON.
      ''');
      
      final bytes = await img.readAsBytes();
      final content = [Content.multi([prompt, DataPart('image/jpeg', bytes)])];
      
      final response = await model.generateContent(content);
      final text = response.text?.replaceAll(RegExp(r'```json|```'), '').trim() ?? "{}";
      
      try {
        final json = jsonDecode(text);
        if(!mounted) return;
        Navigator.pop(context, json); // Erfolgreich zurück
      } catch (e) {
        throw "Konnte Daten nicht lesen: $text";
      }

    } catch (e) {
      setState(() {
        _isAnalyzing = false;
        _statusText = "Fehler: $e";
      });
    }
  }

  @override
  void initState() {
    super.initState();
    // Direkt Kamera öffnen wenn Screen startet
    WidgetsBinding.instance.addPostFrameCallback((_) => _takePicture());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          if (_image != null) 
            SizedBox.expand(child: Image.file(_image!, fit: BoxFit.cover)),
          
          // Overlay
          Container(
            color: Colors.black54,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isAnalyzing)
                    const CircularProgressIndicator(color: Colors.amber),
                  const SizedBox(height: 20),
                  Text(
                    _statusText,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 30),
                  if (!_isAnalyzing && _image != null)
                     ElevatedButton.icon(
                       onPressed: _takePicture, 
                       icon: const Icon(Icons.refresh), 
                       label: const Text("Neu versuchen")
                     )
                ],
              ),
            ),
          ),
          
          // Back Button
          Positioned(
            top: 40, left: 20,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
              onPressed: () => Navigator.pop(context),
            ),
          )
        ],
      ),
    );
  }
}

// --- WIDGETS ---

class _QuickStat extends StatelessWidget {
  final IconData icon; final String label; final Color color;
  const _QuickStat({required this.icon, required this.label, required this.color});
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CircleAvatar(radius: 20, backgroundColor: color.withOpacity(0.1), child: Icon(icon, color: color, size: 20)),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black54)),
      ],
    );
  }
}

class _ReceiptTile extends StatelessWidget {
  final Map<String, dynamic> data;
  const _ReceiptTile({required this.data});
  @override
  Widget build(BuildContext context) {
    final date = data['datum'] ?? "Heute";
    final amount = (data['betrag'] as num?)?.toDouble() ?? 0.00;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))]),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: const Color(0xFFF5F7FA), borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.receipt, color: Color(0xFF2A2D3E)),
        ),
        title: Text(data['haendler'] ?? "Unbekannter Händler", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Text("$date • ${data['kategorie'] ?? 'Sonstiges'}"),
        trailing: Text(
          NumberFormat.currency(locale: 'de_DE', symbol: '€').format(amount),
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF2A2D3E)),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text("Noch keine Belege", style: TextStyle(color: Colors.grey[500], fontSize: 16)),
        ],
      ),
    );
  }
}
