import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:developer';
// import 'package:flutter/foundation.dart';
// import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Movie Ratings',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const MovieRatingsPage(),
    );
  }
}

class Movie {
  final String id;
  final String title;

  Movie({required this.id, required this.title});

  // Movie.fromJson(Map<String, dynamic> json)
  //     : id = json['id'] as String,
  //       title = json['original_title'] as String;

  factory Movie.fromJson(Map<String, dynamic> json) {
    return switch (json) {
      {'id': String id, 'original_title': String title} => Movie(
        id: id,
        title: title,
      ),
      _ => throw const FormatException('Failed to load movie.'),
    };
  }
}

class MovieRatingsPage extends StatefulWidget {
  const MovieRatingsPage({super.key});

  @override
  State<MovieRatingsPage> createState() => _MovieRatingsPageState();
}

class _MovieRatingsPageState extends State<MovieRatingsPage> {
  final List<Movie> _allMovies = List.generate(
    30,
    (i) => Movie(id: 'm$i', title: 'Movie ${i + 1}'),
  );
  List<Movie> _filteredMovies = [];
  String _query = '';
  Map<String, int> _ratings = {}; // movieId -> rating (1..5)
  late SharedPreferences _prefs;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    // start with the full list so the UI doesn't clear unexpectedly
    // _filteredMovies = List.from(_allMovies);
    _fetchMovies();
    _loadPrefs();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadPrefs() async {
    _prefs = await SharedPreferences.getInstance();
    final keys = _prefs.getKeys();
    final Map<String, int> loaded = {};
    for (final k in keys) {
      if (k.startsWith('rating_')) {
        final val = _prefs.getInt(k);
        if (val != null) loaded[k.substring(7)] = val;
      }
    }
    if (!mounted) return;
    setState(() {
      _ratings = loaded;
    });
  }

  Future<void> _setRating(String movieId, int rating) async {
    setState(() {
      _ratings[movieId] = rating;
    });
    await _prefs.setInt('rating_$movieId', rating);
  }

  Future<void> _fetchMovies() async {
    final response = await http.get(
      Uri.parse('https://jsonfakery.com/movies/paginated'),
    );

    log('Fetch movies response.statusCode: ${response.statusCode}');

    if (response.statusCode == 200) {
      // Parse the JSON response
      final List<dynamic> data = jsonDecode(response.body)['data'];

      // Map the data to Movie objects and convert to List
      _filteredMovies = data.map<Movie>((movie) => Movie.fromJson(movie)).toList();

      log('Fetch movies response.data: ${_filteredMovies.length}');
      
      // Update the UI
      if (!mounted) return;
      setState(() {
        // Optionally, you can also update _allMovies if needed
      });
    } else {
      throw Exception('Could not fetch movies');
    }
  }

  void _runFilter(String enteredKeyword) {
    // debounce so we don't rebuild/filter on every keystroke
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      final q = enteredKeyword.trim().toLowerCase();
      List<Movie> results;
      if (q.isEmpty) {
        results = List.from(_filteredMovies);
      } else {
        // always filter from the full source list and use lowercase comparison
        results = _filteredMovies.where((m) => m.title.toLowerCase().contains(q)).toList();
      }

      if (!mounted) return;
      setState(() {
        _filteredMovies = results;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Movie Ratings'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search movies...',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => _runFilter(v),
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: _filteredMovies.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final movie = _filteredMovies[index];
                final rating = _ratings[movie.id] ?? 0;
                return ListTile(
                  title: Text(movie.title),
                  trailing: StarRating(
                    rating: rating,
                    onRatingChanged: (r) => _setRating(movie.id, r),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class StarRating extends StatelessWidget {
  final int rating; // 0..5
  final void Function(int) onRatingChanged;

  const StarRating({super.key, required this.rating, required this.onRatingChanged});

  Widget _buildStar(BuildContext context, int index) {
    final filled = index < rating;
    return IconButton(
      onPressed: () => onRatingChanged(index + 1),
      icon: Icon(
        filled ? Icons.star : Icons.star_border,
        color: filled ? Colors.amber : Colors.grey,
        size: 28,
      ),
      splashRadius: 20,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) => _buildStar(context, i)),
    );
  }
}

