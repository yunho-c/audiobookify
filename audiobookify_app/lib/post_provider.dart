import 'package:flutter/material.dart';
import 'post.dart';
import 'api_service.dart';

class PostProvider with ChangeNotifier {
  List<Post> _posts = [];
  bool _isLoading = true;

  List<Post> get posts => _posts;
  bool get isLoading => _isLoading;

  PostProvider() {
    fetchPosts();
  }

  Future<void> fetchPosts() async {
    _isLoading = true;
    notifyListeners();

    try {
      _posts = await ApiService().getPosts();
    } catch (error) {
      _posts = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
