import 'package:flutter/material.dart';
import 'package:audiobookify_app/file_upload_form.dart';

class BookPage extends StatefulWidget {
  const BookPage({super.key});

  @override
  _BookPageState createState() => _BookPageState();
}

class _BookPageState extends State<BookPage> {
  @override
  Widget build(BuildContext context) {
    return const FileUploadForm();
  }
}
