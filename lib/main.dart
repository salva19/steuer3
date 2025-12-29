import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const SteuerApp());
}

class SteuerApp extends StatelessWidget {
  const SteuerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Steuer Ultra',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo, // Seriöses Business-Blau
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          backgroundColor: Colors.indigo,
          foregroundColor: Colors.white,
        ),
      ),
      home: const ScannerScreen(),
    );
  }
}

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  String _result = "Tippe auf die Kamera, um einen Beleg zu scannen.";
  bool _loading = false;
  File? _image;

  // API Key wird beim Build injiziert
  final String apiKey = const String.fromEnvironment('MY_API_KEY');

  Future<void> _scanReceipt() async {
    // 1. Berechtigung prüfen
    var status = await Permission.camera.request();
    if (!status.isGranted) return;

    // 2. Foto machen
    final picker = ImagePicker();
    final photo = await picker.pickImage(source: ImageSource.camera);

    if (photo == null) return;

    setState(() {
      _image = File(photo.path);
      _loading = true;
      _result = "Analysiere Belegdaten...";
    });

    try {
      if (apiKey.isEmpty) {
        throw "API Key fehlt! Bitte App mit --dart-define=MY_API_KEY=... starten.";
      }

      final model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: apiKey,
      );

      // Prompt optimiert für Steuerdaten
      final prompt = TextPart('''
        Du bist ein professioneller Buchhaltungs-Assistent für deutsches Steuerrecht. 
        Extrahiere Daten aus diesem Beleg. 
        Antworte AUSSCHLIESSLICH als valides JSON: 
        { 
          "datum": "TT.MM.JJJJ", 
          "haendler": "Name", 
          "betrag": 0.00, 
          "kategorie": "Büro/Verpflegung/Reise/Material", 
          "steuer_relevant": true 
        }
      ''');
      
      final imageBytes = await _image!.readAsBytes();
      final content = [
        Content.multi([prompt, DataPart('image/jpeg', imageBytes)])
      ];

      final response = await model.generateContent(content);
      
      String text = response.text ?? "Keine Antwort von der KI.";
      
      // Markdown entfernen falls vorhanden
      text = text.replaceAll('```json', '').replaceAll('```', '').trim();

      setState(() {
        _result = text;
      });
    } catch (e) {
      setState(() {
        _result = "Fehler bei der Analyse: $e";
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Steuer Ultra")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // BILD-BEREICH
            Container(
              height: 300,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!)
              ),
              child: _image != null 
                ? ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.file(_image!, fit: BoxFit.cover))
                : const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_long, size: 60, color: Colors.grey),
                      SizedBox(height: 10),
                      Text("Kein Beleg ausgewählt"),
                    ],
                  ),
            ),
            const SizedBox(height: 24),
            
            // ANALYSE-ERGEBNIS
            if (_loading) 
              const CircularProgressIndicator()
            else    
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.indigo.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.indigo.shade100),
                ),
                child: Text(
                  _result, 
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _loading ? null : _scanReceipt,
        icon: const Icon(Icons.camera_alt),
        label: const Text("Beleg scannen"),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
