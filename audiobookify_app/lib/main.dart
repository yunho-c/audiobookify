import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'files.dart';
import 'book.dart';
import 'database_helper.dart';

void main() {
  // runApp(const MyApp());
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Audiobookify',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.brown),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Audiobookify'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _pageIndex = 0;
  late Future<List<Book>> _booksFuture;

  @override
  void initState() {
    super.initState();
    _booksFuture = DatabaseHelper.instance.fetchBooks();
  }

  void _onItemTapped(int index) {
    setState(() {
      _pageIndex = index;
    });
  }

  // void _showModal(String item) { // ORIG
  void _showModal(Book book) {
    // ALT1
    // void _showModal(String bookname) async { // ALT2
    showDialog<void>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
              // title: Text(item),
              title: Text(prettifyFilename(book.name)), // ALT1
              // title: Text(prettifyFilename(bookname)), // ALT2
              // content: const Text('This is a large modal window'),
              content: BookPage(book: book), // ALT1
              // content: BookPage(book: await DatabaseHelper.instance.getBook(bookname)), // ALT2
              actions: <Widget>[
                TextButton(
                    child: const Text('Close'),
                    onPressed: () {
                      Navigator.of(context).pop();
                    })
              ]);
        });
  }

  // void _addBook(String name) async { // ORIG
  void _addBook(String name, List<String> chapters) async { // ALT1
    await DatabaseHelper.instance.insertBook(name, chapters);
    setState(() {
      _booksFuture = DatabaseHelper.instance.fetchBooks();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Builder(
          builder: (context) {
            if (_pageIndex == 0) {
              return FutureBuilder<List<Book>>(
                future: _booksFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const CircularProgressIndicator();
                  } else if (snapshot.hasError) {
                    return Text('Error: ${snapshot.error}');
                  } else {
                    return GridView.builder(
                      padding: const EdgeInsets.all(16.0),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 10.0,
                        mainAxisSpacing: 10.0,
                      ),
                      itemCount: snapshot.data!.length,
                      itemBuilder: (context, index) {
                        final item = snapshot.data![index];
                        return GestureDetector(
                          // onTap: () => _showModal(item.name), // ORIG
                          onTap: () => _showModal(item), // ALT
                          child: Container(
                            color: Colors.brown[100 * (index % 9 + 1)],
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.all(20.0),
                                child: Text(
                                  item.name,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  }
                },
              );
            } else if (_pageIndex == 1) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Delete all books"),
                    FilledButton(
                      onPressed: () => {
                        DatabaseHelper.instance.resetDatabase(),
                        // setState(() {
                        //   _booksFuture = DatabaseHelper.instance.fetchBooks();
                        // })
                      },
                      style: ButtonStyle(
                          backgroundColor: WidgetStateProperty.all(Colors.orange)),
                      child: const Icon(Icons.delete_outlined),
                    ),
                    const Text("Delete all audio files"),
                    FilledButton(
                      onPressed: () => clearFolders([""]),
                      style: ButtonStyle(
                          backgroundColor: WidgetStateProperty.all(Colors.orange)),
                      child: const Icon(Icons.delete_outlined),
                    )
                  ],
                ),
              );
            } else {
              return const Center(child: Text('Another Page'));
            }
          },
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
          items: const <BottomNavigationBarItem>[
            BottomNavigationBarItem(
                icon: Text(
                  'ABOUT',
                  style: TextStyle(color: Colors.white),
                ),
                label: ''),
            BottomNavigationBarItem(
                icon: Text(
                  'SETTINGS',
                  style: TextStyle(color: Colors.white),
                ),
                label: ''),
            BottomNavigationBarItem(
                icon: Text(
                  'FEEDBACK',
                  style: TextStyle(color: Colors.white),
                ),
                label: ''),
          ],
          currentIndex: _pageIndex,
          selectedItemColor: Colors.brown,
          onTap: _onItemTapped,
          backgroundColor: Theme.of(context).colorScheme.secondary),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () async {
          // TextEditingController _controller = TextEditingController();
          await showDialog<void>(
            context: context,
            // builder: (BuildContext context) {
            //   return AlertDialog(
            //       title: const Text('Add Item'),
            //       content: TextField(
            //         controller: _controller,
            //         decoration: const InputDecoration(
            //             hintText: 'Enter item name'),
            //       ),
            //       actions: <Widget>[
            //         TextButton(
            //           child: const Text('Cancel'),
            //           onPressed: () {
            //             Navigator.of(context).pop();
            //           },
            //         ),
            //         ElevatedButton(
            //           child: const Text('Add'),
            //           onPressed: () {
            //             if (_controller.text.isNotEmpty) {
            //               _addItem(_controller.text);
            //             }
            //             Navigator.of(context).pop();
            //           },
            //         )
            //       ]);
            // }
            builder: (BuildContext context) {
              // return BookCreator(addBook: _addBook);
              return BookCreator(
                addBook: _addBook,
                startModal: _showModal,
              );
            },
          );
        },
      ),
    );
  }
}
