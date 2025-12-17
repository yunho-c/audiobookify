import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

class FileUploadForm extends StatefulWidget {
  const FileUploadForm({super.key});

  @override
  _FileUploadFormState createState() => _FileUploadFormState();
}

class _FileUploadFormState extends State<FileUploadForm> {
  PlatformFile? _selectedFile;

  void _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();

    if (result != null) {
      setState(() {
        _selectedFile = result.files.first;
      });
    }
  }

  void _submit() {
    if (_selectedFile != null) {
      // Handle file upload logic here
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('File ${_selectedFile!.name} selected')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a file')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Upload File'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ElevatedButton(
            onPressed: _pickFile,
            child: const Text('Choose File'),
          ),
          if (_selectedFile != null)
            Text('Selected file: ${_selectedFile!.name}'),
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
          child: const Text('Upload'),
        ),
      ],
    );
  }
}
