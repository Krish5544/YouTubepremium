import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';

class VideoSearchDelegate extends SearchDelegate {
  final Function(String) onSearch;
  VideoSearchDelegate(this.onSearch);

  @override
  ThemeData appBarTheme(BuildContext context) => ThemeData.dark().copyWith(
        appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF212121)),
      );

  @override
  List<Widget>? buildActions(BuildContext context) => [
        IconButton(icon: const Icon(Icons.clear), onPressed: () => query = '')
      ];

  @override
  Widget? buildLeading(BuildContext context) => IconButton(
        icon: const Icon(Icons.arrow_back), onPressed: () => close(context, null)
      );

  @override
  Widget buildResults(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      onSearch(query);
      close(context, null);
    });
    return const Center(child: CircularProgressIndicator(color: Colors.red));
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    if (query.trim().isEmpty) {
      return const Center(
        child: Text("यहाँ सर्च करें (जैसे: UKPSC, UP GK)", style: TextStyle(color: Colors.grey, fontSize: 16)),
      );
    }

    return FutureBuilder<List<String>>(
      future: _fetchYouTubeSuggestions(query),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();

        final suggestions = snapshot.data!;
        if (suggestions.isEmpty) return const SizedBox();

        return ListView.builder(
          itemCount: suggestions.length,
          itemBuilder: (context, index) {
            final suggestion = suggestions[index];
            return ListTile(
              leading: const Icon(Icons.search, color: Colors.grey),
              title: Text(suggestion, style: const TextStyle(color: Colors.white, fontSize: 16)),
              onTap: () {
                query = suggestion;
                showResults(context);
              },
            );
          },
        );
      }
    );
  }

  Future<List<String>> _fetchYouTubeSuggestions(String searchKey) async {
    try {
      final client = HttpClient();
      final uri = Uri.parse('https://suggestqueries.google.com/complete/search?client=firefox&ds=yt&q=${Uri.encodeComponent(searchKey)}');
      final request = await client.getUrl(uri);
      final response = await request.close();
      
      if (response.statusCode == 200) {
        final responseBody = await response.transform(utf8.decoder).join();
        final json = jsonDecode(responseBody);
        if (json is List && json.length > 1) {
          final suggestions = json[1];
          if (suggestions is List) {
            return suggestions.map((e) => e.toString()).toList();
          }
        }
      }
    } catch (e) {
      debugPrint("Suggestion error: $e");
    }
    return [];
  }
}
