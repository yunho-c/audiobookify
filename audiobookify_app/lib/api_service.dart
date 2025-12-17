import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart';
import 'post.dart';
import 'files.dart';
// import 'audio_file.dart';

class ApiService {
  // static const String baseUrl = 'https://jsonplaceholder.typicode.com';
  static const String baseUrl = 'http://localhost:8000';
  // static const String baseUrl = 'https://tts.yunhocho.com';
  // static const String baseUrl = 'https://e2a.yunhocho.com';

  Future<List<Post>> getPosts() async {
    final response = await get(Uri.parse('$baseUrl/posts'));

    if (response.statusCode == 200) {
      List<dynamic> body = json.decode(response.body);
      List<Post> posts = body
          .map(
            (dynamic item) => Post.fromJson(item),
          )
          .toList();
      return posts;
    } else {
      throw Exception('Failed to load posts');
    }
  }

  // Future<List<AudioFile>> uploadEpub(File epubFile) async {
  Future<List<dynamic>> uploadEpub(File epubFile, {String? id}) async {
    var request = MultipartRequest('POST', Uri.parse('$baseUrl/convert'))
      ..files.add(await MultipartFile.fromPath('file', epubFile.path));
    if (id != null)
      request.fields.addEntries(<String, String>{'id': id}.entries);

    final response = await request.send();
    if (response.statusCode == 200) {
      final responseData = await response.stream.bytesToString();
      List<dynamic> body = json.decode(responseData);
      return body;
      // final audioFiles =
      //     body.map((dynamic item) => AudioFile.fromJson(item)).toList();
      // return audioFiles;
    } else {
      throw Exception('Failed to upload .epub file');
    }
  }

  Future<void> download(String path) async {
    final response = await get(Uri.parse('$baseUrl/download?path=$path'));

    if (response.statusCode == 200) {
      // print(response.body);
      // saveBytesToFile(response.body, path);
      final fileName = path.split('/').sublist(2).join('/');
      saveBytesToFile(response.bodyBytes, fileName);
    } else {
      throw Exception('Failed to download audio: $path');
    }
  }

  // Future<dynamic> status(String bookId) async {
  Future<Map<String, dynamic>> status(String bookId) async {
    final response = await get(Uri.parse('$baseUrl/status?book_id=$bookId'));

    if (response.statusCode == 200) {
      // List<dynamic> body = json.decode(response.body);
      Map<String, dynamic> body = json.decode(response.body);
      return body;
    } else {
      throw Exception('Error decoding chapter status: $response');
    }
  }
}
