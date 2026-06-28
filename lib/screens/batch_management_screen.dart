import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:universal_html/html.dart' as html;

class CsvService {
  // Convert list of maps to CSV string
  static String convertToCsv(List<Map<String, dynamic>> data) {
    if (data.isEmpty) return '';

    // Get headers from first item
    List<String> headers = data.first.keys.map((k) => k.toString()).toList();

    // Convert to CSV
    List<List<dynamic>> rows = [headers];
    for (var item in data) {
      rows.add(headers.map((h) => item[h] ?? '').toList());
    }

    return const ListToCsvConverter().convert(rows);
  }

  // Parse CSV string to list of maps
  static List<Map<String, dynamic>> parseCsv(String csvString) {
    List<List<dynamic>> rows = const CsvToListConverter().convert(csvString);
    if (rows.isEmpty) return [];

    List<String> headers = rows.first.map((h) => h.toString()).toList();
    List<Map<String, dynamic>> result = [];

    for (var i = 1; i < rows.length; i++) {
      Map<String, dynamic> row = {};
      for (var j = 0; j < headers.length; j++) {
        row[headers[j]] = rows[i][j].toString();
      }
      result.add(row);
    }

    return result;
  }

  // Download CSV file
  static void downloadCsv(String csvContent, String filename) {
    final blob = html.Blob([csvContent], 'text/csv');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', filename)
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  // Trigger file picker (returns Future<String?>)
  static Future<String?> pickCsvFile() async {
    final input = html.FileUploadInputElement()..accept = '.csv';
    input.click();

    await input.onChange.first;

    if (input.files != null && input.files!.isNotEmpty) {
      final file = input.files!.first;
      final reader = html.FileReader();
      reader.readAsText(file);
      await reader.onLoad.first;
      return reader.result as String;
    }
    return null;
  }
}
