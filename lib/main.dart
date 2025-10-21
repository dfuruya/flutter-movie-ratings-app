import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  Movie(this.id, this.title);
}

class MovieRatingsPage extends StatefulWidget {
  const MovieRatingsPage({super.key});

  @override
  State<MovieRatingsPage> createState() => _MovieRatingsPageState();
}

class _MovieRatingsPageState extends State<MovieRatingsPage> {
  final List<Movie> _allMovies = List.generate(
    30,
    (i) => Movie('m$i', 'Movie ${i + 1}'),
  );

  String _query = '';
  Map<String, int> _ratings = {}; // movieId -> rating (1..5)
  late SharedPreferences _prefs;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
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

  List<Movie> get _filteredMovies {
    if (_query.isEmpty) return _allMovies;
    final q = _query.toLowerCase();
    return _allMovies.where((m) => m.title.toLowerCase().contains(q)).toList();
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
              onChanged: (v) => setState(() => _query = v),
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

