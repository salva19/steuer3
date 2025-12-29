import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

class ReceiptScannerScreen extends StatefulWidget {
  const ReceiptScannerScreen({super.key});

  @override
  State<ReceiptScannerScreen> createState() => _ReceiptScannerScreenState();
}

class _ReceiptScannerScreenState extends State<ReceiptScannerScreen> {
  File? _image;
  String _ergebnisText = "Mache ein Foto von einem Beleg, um ihn zu analysieren.";
  bool _ladeStatus = false;
  Map<String, dynamic>? _extractedData;

  // HINWEIS: In einer echten App sollte der API Key sicher gespeichert werden.
  // Hier wird er beim Build übergeben oder muss hartkodiert werden für Tests.
  // z.B. --dart-define=MY_API_KEY=xyz
  final String apiKey = const String.fromEnvironment('MY_API_KEY');

  Future<void> _fotoMachen() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera);

    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
        _ergebnisText = "Analysiere Beleg... Bitte warten.";
        _ladeStatus = true;
        _extractedData = null;
      });
      await _analysiereMitGemini(File(pickedFile.path));
    }
  }

  Future<void> _analysiereMitGemini(File bild) async {
    if (apiKey.isEmpty) {
      setState(() {
        _ergebnisText = "FEHLER: Kein API Key gefunden!\n"
            "Bitte starte die App mit: flutter run --dart-define=MY_API_KEY=dein_key";
        _ladeStatus = false;
      });
      return;
    }

    try {
      final model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: apiKey,
      );

      final prompt = TextPart('''
        Du bist ein professioneller Buchhaltungs-Assistent für deutsches Steuerrecht. 
        Deine Aufgabe ist es, Daten aus diesem Foto eines Belegs/Rechnung präzise zu extrahieren.

        Bitte antworte AUSSCHLIESSLICH mit einem validen JSON-Objekt.
        Das JSON muss folgende Struktur haben:

        {
          "datum": "TT.MM.JJJJ",
          "haendler": "Name des Geschäfts",
          "betrag_gesamt": 0.00,
          "waehrung": "EUR",
          "kategorie": "Werkzeug/Material/Tanken/Verpflegung/Büro",
          "steuer_relevant": true
        }

        Falls ein Wert nicht lesbar ist, setze ihn auf null.
      ''');

      final imageBytes = await bild.readAsBytes();
      final imagePart = DataPart('image/jpeg', imageBytes);

      final response = await model.generateContent([
        Content.multi([prompt, imagePart])
      ]);

      if (response.text != null) {
        // Versuche JSON zu parsen (manchmal ist Markdown drumherum)
        String cleanJson = response.text!.replaceAll('```json', '').replaceAll('```', '').trim();
        final data = jsonDecode(cleanJson);

        setState(() {
          _extractedData = data;
          _ergebnisText = "Analyse erfolgreich!";
          _ladeStatus = false;
        });
      } else {
        throw Exception("Leere Antwort von der KI");
      }
    } catch (e) {
      setState(() {
        _ergebnisText = "Fehler bei der Analyse: $e";
        _ladeStatus = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Beleg Scanner"),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Bild Anzeige
            Container(
              height: 250,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: _image != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(_image!, fit: BoxFit.cover),
                    )
                  : const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.camera_alt, size: 50, color: Colors.grey),
                          SizedBox(height: 10),
                          Text("Kein Bild ausgewählt", style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
            ),
            const SizedBox(height: 20),

            // Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _ladeStatus ? null : _fotoMachen,
                icon: _ladeStatus 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) 
                  : const Icon(Icons.camera),
                label: Text(_ladeStatus ? "Analysiere..." : "Foto machen & Analysieren"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 30),

            // Ergebnis Bereich
            if (_extractedData != null) ...[
              const Text("Gefundene Daten:", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _ResultRow("Händler", _extractedData!['haendler']?.toString()),
                      _ResultRow("Datum", _extractedData!['datum']?.toString()),
                      _ResultRow("Betrag", "${_extractedData!['betrag_gesamt']?.toString() ?? '-'} ${_extractedData!['waehrung'] ?? ''}"),
                      _ResultRow("Kategorie", _extractedData!['kategorie']?.toString()),
                      _ResultRow("Steuerlich relevant", (_extractedData!['steuer_relevant'] == true) ? "JA" : "NEIN", highlight: true),
                    ],
                  ),
                ),
              ),
            ] else ...[
              Text(_ergebnisText, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
            ],
          ],
        ),
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  final String label;
  final String? value;
  final bool highlight;

  const _ResultRow(this.label, this.value, {this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(
            value ?? "n/a", 
            style: TextStyle(
              fontWeight: FontWeight.bold, 
              color: highlight ? Colors.green : Colors.black87
            )
          ),
        ],
      ),
    );
  }
}
