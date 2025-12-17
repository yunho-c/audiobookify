import 'dart:io';
import 'package:audiobookify/database_helper.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'api_service.dart';
import 'files.dart';
// import 'audio_file.dart';
import 'epub.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path/path.dart' as p;

class BookCreator extends StatefulWidget {
  // final void Function(String) addBook; // ORIG
  final void Function(String, List<String>) addBook;
  final void Function(Book) startModal; // rename, maybe

  // const BookCreator({required this.addBook, super.key});
  const BookCreator(
      {required this.addBook, required this.startModal, super.key});

  @override
  _BookCreatorState createState() => _BookCreatorState();
}

class _BookCreatorState extends State<BookCreator> {
  PlatformFile? _selectedFile;
  Map<String, String>? epubMetadata;
  String? bookname;

  var api = ApiService();

  void _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();

    if (result != null) {
      setState(() {
        _selectedFile = result.files.first;
        epubMetadata = epubInfo(result.files.first.path!);
        // bookname = sanitizeFileName(result.files.first.path!.split('/').last);
        bookname = sanitizeFileName(epubMetadata!['title']!);
      });
    }
  }

  void _submit() async {
    if (_selectedFile != null) {
      File file = File(_selectedFile!.path!);

      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const Center(child: CircularProgressIndicator());
        },
      );

      try {
        // List<AudioFile> result = await api.uploadEpub(file);
        List<dynamic> result = await api.uploadEpub(file, id: bookname); // ORIG
        // var result = api.uploadEpub(file, id: bookname); // ALT: don't await

        // DEPR: POST call to convert returns paths
        // for (final path in result) {
        //   api.download(path);
        // }
        // print(result);

        // NEW: POST call to convert returns chapters
        List<String> chapters = result.cast();

        // Handle the result
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('File ${_selectedFile!.name} uploaded successfully')),
        );
        widget.addBook(bookname!, chapters); // ALT1
        Book book = await DatabaseHelper.instance.getBook(bookname!);

        // Hide loading indicator
        Navigator.of(context).pop();

        // TODO move to corresponding BookPage
        widget.startModal(book);
      } catch (e) {
        // Hide loading indicator
        Navigator.of(context).pop();

        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading file: $e')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a file')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New Audiobook'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ElevatedButton(
            onPressed: _pickFile,
            child: const Text('Choose File (.epub)'),
          ),
          if (_selectedFile != null)
            Text('Selected file: ${_selectedFile!.name}'),
          if (epubMetadata != null) Text('Metadata: ${epubMetadata}...'),
          if (epubMetadata != null)
            Text(
              'Title',
              textAlign: TextAlign.left,
              style: Theme.of(context).textTheme.headlineLarge,
            ),
          if (epubMetadata != null)
            Text(
              '${epubMetadata!['title']}',
              textAlign: TextAlign.left,
            ),
          if (bookname != null)
            Text(
              '${bookname}',
              textAlign: TextAlign.left,
            ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          child: const Text('Cancel'),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        ElevatedButton(
          onPressed: _submit,
          child: const Text('Start'),
        ),
      ],
    );
  }
}

class BookPage extends StatefulWidget {
  // final String book; // ORIG
  Book book; // ALT

  // const BookPage({required this.book, super.key}); // ORIG
  BookPage({required this.book, super.key}); // ALT

  @override
  _BookPageState createState() => _BookPageState();
}

class _BookPageState extends State<BookPage> {
  List<String>? files;
  final player = AudioPlayer();
  late final Book book;

  @override
  void initState() {
    super.initState();
    book = widget.book;
    // loadFiles(book);
    loadFiles(book.name);
  }

  Future<void> loadState() async {
    loadFiles(book.name);
  }

  Future<void> loadFiles(String book) async {
    final loadedFiles = await findFiles("$book/*");
    setState(() {
      files = loadedFiles;
    });
  }

  Future<void> loadStatus(String bookId) async {
    var api = ApiService();
    var status = api.status(bookId);
    DatabaseHelper.instance.updateStatus(bookId, status)

    setState(() {});
  }

  List<String> _sort(List<String> strings, {bool ascending = true}) {
    return strings..sort();
  }

  Future<void> downloadNewlyAvailables() async {
    var api = ApiService();
    for (final chapter in book.chapters) {
      var file = await findFiles('${book.name}/${chapter}.*');
      if (file.isEmpty) {
        final status = await api.status(book.name);
        if (status[chapter] == 100) {

        }
      }
    }

  @override
  Widget build(BuildContext context) {
    if (files == null) {
      return const CircularProgressIndicator();
    }

    files = _sort(files!);

    // // DEBUG; DEPR
    // return Column(
    //   children: [Text(book.name), Text(book.inProgress.toString())],
    // );
    // return Text(files!.join("\n "));

    return SizedBox(
        width: double.maxFinite,
        height: 500,
        child: ListView.builder(
          itemCount: book.chapters.length,
          itemBuilder: (context, index) {
            var chapter = book.chapters[index];
            var status = chapter.status;
            return ListTile(
                // title: Text(prettifyFilename(p.basename(files![index]))), // DEPR
                title: Text(prettifyFilename(chapter.name)),
                subtitle: LinearProgressIndicator(
                  value: status / 100,
                ),
                trailing: status == 100
                ? IconButton(
                    icon: const Icon(Icons.play_arrow),
                    onPressed: () {
                      player.setSource(DeviceFileSource(files![index]));
                      player.resume();
                    },
                  )
                : IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () => loadStatus(book.name),
                ));
          },
        ),
      );
    }
  }
}
