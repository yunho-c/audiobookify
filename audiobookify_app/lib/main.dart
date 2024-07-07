import 'package:flutter/material.dart';
import 'database_helper.dart';
import 'book.dart';

void main() {
  runApp(const MyApp());
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
  late Future<List<Item>> _itemsFuture;

  @override
  void initState() {
    super.initState();
    _itemsFuture = DatabaseHelper.instance.fetchItems();
  }

  void _onItemTapped(int index) {
    setState(() {
      _pageIndex = index;
    });
  }

  void _showModal(String item) {
    showDialog<void>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
              title: Text(item),
              // content: const Text('This is a large modal window'),
              content: BookPage(),
              actions: <Widget>[
                TextButton(
                    child: const Text('Close'),
                    onPressed: () {
                      Navigator.of(context).pop();
                    })
              ]);
        });
  }

  void _addItem(String name) async {
    await DatabaseHelper.instance.insertItem(name);
    setState(() {
      _itemsFuture = DatabaseHelper.instance.fetchItems();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: Center(
            child: _pageIndex == 0
                ? FutureBuilder<List<Item>>(
                    future: _itemsFuture,
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
                                onTap: () => _showModal(item.name),
                                child: Container(
                                  color: Colors.brown[100 * (index % 9 + 1)],
                                  child: Center(
                                    child: Text(
                                      item.name,
                                      style: const TextStyle(fontSize: 18),
                                    ),
                                  ),
                                ),
                              );
                            });
                      }
                    })
                : const Center(child: Text('Another Page'))),
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
              TextEditingController _controller = TextEditingController();
              await showDialog<void>(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                        title: const Text('Add Item'),
                        content: TextField(
                          controller: _controller,
                          decoration: const InputDecoration(
                              hintText: 'Enter item name'),
                        ),
                        actions: <Widget>[
                          TextButton(
                            child: const Text('Cancel'),
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                          ),
                          ElevatedButton(
                            child: const Text('Add'),
                            onPressed: () {
                              if (_controller.text.isNotEmpty) {
                                _addItem(_controller.text);
                              }
                              Navigator.of(context).pop();
                            },
                          )
                        ]);
                  });
            }));
  }
}
