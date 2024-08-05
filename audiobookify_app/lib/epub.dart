import 'dart:io';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';
// // test
// import 'package:path_provider/path_provider.dart';

Map<String, String> epubInfo(String filePath) {
  File file = File(filePath);
  List<int> bytes = file.readAsBytesSync();
  Archive archive = ZipDecoder().decodeBytes(bytes);

  String xpath(XmlElement element, String path) {
    List<String> parts = path.split('/');
    XmlElement current = element;
    for (String part in parts) {
      if (part.startsWith('@')) {
        return current.getAttribute(part.substring(1)) ?? '';
      } else if (part == 'text()') {
        return current.innerText;
      } else {
        // current = current.findElements(part).first;
        current = current.findElements(part, namespace: '*').first;
      }
    }
    return '';
  }

  // Find the contents metafile
  ArchiveFile containerFile = archive.findFile('META-INF/container.xml')!;
  String containerContent = String.fromCharCodes(containerFile.content);
  XmlDocument containerXml = XmlDocument.parse(containerContent);
  String cfname =
      xpath(containerXml.rootElement, 'rootfiles/rootfile/@full-path');

  // Grab the metadata block from the contents metafile
  ArchiveFile contentFile = archive.findFile(cfname)!;
  String contentFileContent = String.fromCharCodes(contentFile.content);
  XmlDocument contentXml = XmlDocument.parse(contentFileContent);
  XmlElement metadata = contentXml.findAllElements('metadata').first;

  // Repackage the data
  Map<String, String> result = {};
  for (String s in ['title', 'language', 'creator', 'date', 'identifier']) {
    result[s] = xpath(metadata, '$s/text()');
  }

  return result;
}

// void test() async {
//   final directory = await getApplicationDocumentsDirectory();
//   print(directory); // DEBUG
//   final filename = 'asdf';
//   String filePath = 'directory.path/$filename.epub';
//   Map<String, String> info = epubInfo(filePath);
//   print(info);
// }
