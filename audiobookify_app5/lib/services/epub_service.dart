import '../src/rust/api/epub.dart' as rust_epub;

class EpubService {
  const EpubService();

  Future<rust_epub.EpubBook> openEpub(String path) {
    return rust_epub.openEpub(path: path);
  }
}
