import 'dart:io';
import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../../data/models/book.dart';

class AiService {
  final String apiKey;
  final String modelName;

  AiService(this.apiKey, {this.modelName = 'gemini-2.5-flash'});

  Future<Book?> extractBookDetails(List<String> imagePaths) async {
    if (apiKey.isEmpty) throw Exception('API Key is missing');

    final model = GenerativeModel(
      model: modelName,
      apiKey: apiKey,
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
      ),
    );

    final prompt = TextPart(
        'You are a bibliographic data expert. Analyze the provided book image and extract the title.\n'
        'Return a single valid JSON object. Do not include markdown formatting or code blocks.\n\n'
        'EXTRACTION RULES:\n'
        '1. **Native Language:** Extract text exactly in the script it appears on the cover. If the title is in Tamil, return Tamil text (e.g., "பொன்னியின் செல்வன்"). **Do not translate** into English.\n'
        '2. **Title:** Capture the full title. If there is a distinct subtitle, dont include.\n'
        'REQUIRED JSON STRUCTURE:\n'
        '{\n'
        '  "title": "string"\n'
        '}\n\n'
        'If the title is not visible, return null for title.');

    final imageParts = <DataPart>[];
    for (final path in imagePaths) {
      final file = File(path);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        imageParts.add(DataPart('image/jpeg', bytes)); // Assuming JPEG/PNG
      }
    }

    if (imageParts.isEmpty) throw Exception('No valid images provided');

    final content = [
      Content.multi([prompt, ...imageParts])
    ];

    try {
      final response = await model.generateContent(content);
      final text = response.text;

      if (text == null) return null;

      final json = jsonDecode(text) as Map<String, dynamic>;

      return Book(
        title: json['title'] ?? '',
        sku: '', // Not extracting SKU
        price: 0.0,
        stockQuantity: 0,
        author: '', // Not extracting author
        publisher: '', // Not extracting publisher
        category: '',
        isbn: '',
        description: '',
      );
    } catch (e) {
      throw Exception('Failed to extract book details: $e');
    }
  }
}
