import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:glob/glob.dart';
import 'package:glob/list_local_fs.dart';

Future<File> saveFile(File file, String fileName) async {
  final directory = await getApplicationDocumentsDirectory();
  final path = directory.path;
  final File newFile = File('$path/$fileName');
  return file.copy(newFile.path);
}

Future<File> saveBytesToFile(dynamic bytes, String fileName) async {
  final directory = await getApplicationDocumentsDirectory();
  final file = File('${directory.path}/$fileName');
  await Directory(file.parent.path).create(recursive: true);
  await file.writeAsBytes(bytes);
  return file;
}

Future<File?> getSavedFile(String fileName) async {
  final directory = await getApplicationDocumentsDirectory();
  final path = directory.path;
  final File file = File('$path/$fileName');
  if (await file.exists()) {
    return file;
  }
  return null;
}

Future<List<String>> findFiles(String pattern) async {
  final directory = await getApplicationDocumentsDirectory();
  final glob = Glob('${directory.path}/$pattern');

  List<String> matchingFiles =
      await glob.listSync().map((entity) => entity.path).toList();
  return matchingFiles;
}

String sanitizeFileName(String fileName) {
  // Trim leading and trailing whitespace
  String sanitized = fileName.trim();

  // Replace reserved names
  List<String> reservedNames = [
    'CON', 'PRN', 'AUX', 'NUL',
    'COM1', 'COM2', 'COM3', 'COM4', 'COM5', 'COM6', 'COM7', 'COM8', 'COM9',
    'LPT1', 'LPT2', 'LPT3', 'LPT4', 'LPT5', 'LPT6', 'LPT7', 'LPT8', 'LPT9'
  ];

  if (reservedNames.contains(sanitized.toUpperCase())) {
    sanitized = '_$sanitized';
  }

  // Replace invalid characters with underscores
  sanitized = sanitized.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');

  // Replace multiple spaces or underscores with a single underscore
  sanitized = sanitized.replaceAll(RegExp(r'[ _]+'), '_');

  // Remove leading periods and replace multiple periods with a single one
  sanitized = sanitized.replaceAll(RegExp(r'^\.+'), '');
  sanitized = sanitized.replaceAll(RegExp(r'\.+'), '.');

  // Ensure it doesn't end with a period
  sanitized = sanitized.replaceAll(RegExp(r'\.$'), '');

  // If the name is empty after sanitization, provide a default
  if (sanitized.isEmpty) {
    sanitized = 'unnamed_file';
  }

  // Truncate if longer than 255 characters, preserving the file extension if present
  if (sanitized.length > 255) {
    int lastDotIndex = sanitized.lastIndexOf('.');
    if (lastDotIndex != -1 && lastDotIndex > 245) {
      String extension = sanitized.substring(lastDotIndex);
      sanitized = sanitized.substring(0, 255 - extension.length) + extension;
    } else {
      sanitized = sanitized.substring(0, 255);
    }
  }

  return sanitized;
}
