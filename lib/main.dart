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
      title: 'Product Ratings',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const ProductRatingsPage(),
    );
  }
}

class Product {
  final String id;
  final String title;
  final double price;
  final String thumbnail;

  Product({required this.id, required this.title, required this.price, required this.thumbnail});

  // Product.fromJson(Map<String, dynamic> json)
  //     : id = json['id'] as String,
  //       title = json['title'] as String,
  //       price = json['price'] as double?;

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'].toString(),
      title: json['title'],
      price: json['price'],
      thumbnail: json['thumbnail'] ?? '',
    );
    // return switch (json) {
    //   {
    //     'id': int id, 
    //     'title': String title, 
    //     'price': double price,
    //     'thumbnail': String thumbnail,
    //   } => Product(
    //     id: id.toString(),
    //     title: title,
    //     price: price,
    //     thumbnail: thumbnail,
    //   ),
    //   _ => throw const FormatException('Failed to load Product.'),
    // };
  }
}

class ProductRatingsPage extends StatefulWidget {
  const ProductRatingsPage({super.key});

  @override
  State<ProductRatingsPage> createState() => _ProductRatingsPageState();
}

class _ProductRatingsPageState extends State<ProductRatingsPage> {
  final List<Product> _allProducts = [];
  List<Product> _filteredProducts = [];
  String _query = '';
  Map<String, int> _ratings = {}; // productId -> rating (1..5)
  late SharedPreferences _prefs;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    // start with the full list so the UI doesn't clear unexpectedly
    // _filteredProducts = List.from(_allProducts);
    _fetchProducts();
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

  Future<void> _setRating(String productId, int rating) async {
    setState(() {
      _ratings[productId] = rating;
    });
    await _prefs.setInt('rating_$productId', rating);
  }

  Future<void> _fetchProducts([String? keywords]) async {
    final url = 'https://dummyjson.com/products${keywords != null ? '/search?q=$keywords&' : '?'}limit=10&select=title,price';

    if (_allProducts.isNotEmpty && keywords == null) {
      _filteredProducts = List.from(_allProducts);
      log('Using cached all products');
      return;
    }

    final response = await http.get(Uri.parse(url));

    log('Fetch products response.statusCode: ${response.statusCode}');

    if (response.statusCode == 200) {
      // Parse the JSON response
      final List<dynamic> data = jsonDecode(response.body)['products'];

      // Map the data to Product objects and convert to List
      _filteredProducts = data.map<Product>((product) => Product.fromJson(product)).toList();

      log('Fetch products response.data: ${_filteredProducts.length}');

      // Update the UI
      if (!mounted) return;
      setState(() {
        _filteredProducts = List.from(_filteredProducts);
      });
    } else {
      throw Exception('Could not fetch products');
    }
  }

  void _runFilter(String enteredKeyword) {
    // debounce so we don't rebuild/filter on every keystroke
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      final q = enteredKeyword.trim().toLowerCase();
      log('entered keyword: ' + q);

      _fetchProducts(q);

      if (!mounted) return;
      // setState(() {
      //   _filteredProducts = results;
      // });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Ratings'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search Products...',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => _runFilter(v),
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: _filteredProducts.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final product = _filteredProducts[index];
                final rating = _ratings[product.id] ?? 0;
                return ListTile(
                  leading: product.thumbnail.isNotEmpty
                      ? Image.network(
                          product.thumbnail,
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                        )
                      : const Icon(Icons.shopping_bag),
                  title: Text(product.title),
                  trailing: StarRating(
                    rating: rating,
                    onRatingChanged: (r) => _setRating(product.id, r),
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

