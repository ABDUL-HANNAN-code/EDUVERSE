import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';

class PosterModel {
  String id;
  String imageBase64;
  String title;
  String description;
  String link;
  bool active;

  PosterModel({
    required this.id,
    required this.imageBase64,
    this.title = '',
    this.description = '',
    this.link = '',
    this.active = true,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'imageBase64': imageBase64,
        'title': title,
        'description': description,
        'link': link,
        'active': active,
      };

  factory PosterModel.fromJson(Map<String, dynamic> json) => PosterModel(
        id: json['id'],
        imageBase64: json['imageBase64'],
        title: json['title'] ?? '',
        description: json['description'] ?? '',
        link: json['link'] ?? '',
        active: json['active'] ?? true,
      );
}

class MarketplacePosterSlideshow extends StatefulWidget {
  const MarketplacePosterSlideshow({Key? key}) : super(key: key);

  @override
  State<MarketplacePosterSlideshow> createState() =>
      _MarketplacePosterSlideshowState();
}

class _MarketplacePosterSlideshowState
    extends State<MarketplacePosterSlideshow> {
  List<PosterModel> posters = [];
  int currentSlide = 0;
  bool isAutoPlaying = true;
  Timer? _autoPlayTimer;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadPosters();
  }

  @override
  void dispose() {
    _autoPlayTimer?.cancel();
    super.dispose();
  }

  Future<void> loadPosters() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final postersJson = prefs.getString('marketplace_posters');

      if (postersJson != null) {
        final List<dynamic> decoded = json.decode(postersJson);
        final allPosters = decoded.map((e) => PosterModel.fromJson(e)).toList();

        setState(() {
          posters = allPosters.where((p) => p.active).toList();
          isLoading = false;
        });

        if (posters.length > 1) {
          startAutoPlay();
        }
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      debugPrint('Error loading posters: $e');
      setState(() => isLoading = false);
    }
  }

  void startAutoPlay() {
    _autoPlayTimer?.cancel();
    if (isAutoPlaying && posters.length > 1) {
      _autoPlayTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
        if (mounted && isAutoPlaying) {
          setState(() {
            currentSlide = (currentSlide + 1) % posters.length;
          });
        }
      });
    }
  }

  void nextSlide() {
    setState(() {
      currentSlide = (currentSlide + 1) % posters.length;
      isAutoPlaying = false;
    });
    _autoPlayTimer?.cancel();
    Future.delayed(const Duration(seconds: 10), () {
      if (mounted) {
        setState(() => isAutoPlaying = true);
        startAutoPlay();
      }
    });
  }

  void prevSlide() {
    setState(() {
      currentSlide = currentSlide > 0 ? currentSlide - 1 : posters.length - 1;
      isAutoPlaying = false;
    });
    _autoPlayTimer?.cancel();
    Future.delayed(const Duration(seconds: 10), () {
      if (mounted) {
        setState(() => isAutoPlaying = true);
        startAutoPlay();
      }
    });
  }

  void goToSlide(int index) {
    setState(() {
      currentSlide = index;
      isAutoPlaying = false;
    });
    _autoPlayTimer?.cancel();
    Future.delayed(const Duration(seconds: 10), () {
      if (mounted) {
        setState(() => isAutoPlaying = true);
        startAutoPlay();
      }
    });
  }

  Future<void> handlePosterTap() async {
    final poster = posters[currentSlide];
    if (poster.link.isNotEmpty) {
      final uri = Uri.parse(poster.link);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const SizedBox(
        height: 300,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (posters.isEmpty) {
      return const SizedBox.shrink(); // Don't show anything if no posters
    }

    return Container(
      margin: const EdgeInsets.all(16),
      constraints: const BoxConstraints(maxWidth: 1200),
      child: Column(
        children: [
          _buildSlideshow(),
          if (posters.length > 1) ...[
            const SizedBox(height: 8),
            Text(
              '${currentSlide + 1} / ${posters.length}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSlideshow() {
    final poster = posters[currentSlide];

    return GestureDetector(
      onTap: poster.link.isNotEmpty ? handlePosterTap : null,
      child: Card(
        elevation: 8,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Stack(
          children: [
            // Main Image with Animation
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              child: Container(
                key: ValueKey(currentSlide),
                height: 320,
                width: double.infinity,
                child: Image.memory(
                  base64Decode(poster.imageBase64),
                  fit: BoxFit.cover,
                ),
              ),
            ),

            // Gradient Overlay
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 200,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.7),
                    ],
                  ),
                ),
              ),
            ),

            // Text Content
            if (poster.title.isNotEmpty || poster.description.isNotEmpty)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (poster.title.isNotEmpty)
                        Text(
                          poster.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(
                                offset: Offset(0, 1),
                                blurRadius: 3,
                                color: Colors.black45,
                              ),
                            ],
                          ),
                        ),
                      if (poster.description.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          poster.description,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            shadows: [
                              Shadow(
                                offset: Offset(0, 1),
                                blurRadius: 3,
                                color: Colors.black45,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

            // Navigation Arrows
            if (posters.length > 1) ...[
              Positioned(
                left: 16,
                top: 0,
                bottom: 0,
                child: Center(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.chevron_left, size: 28),
                      onPressed: prevSlide,
                      color: Colors.grey[800],
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 16,
                top: 0,
                bottom: 0,
                child: Center(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.chevron_right, size: 28),
                      onPressed: nextSlide,
                      color: Colors.grey[800],
                    ),
                  ),
                ),
              ),
            ],

            // Dot Indicators
            if (posters.length > 1)
              Positioned(
                bottom: 16,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    posters.length,
                    (index) => GestureDetector(
                      onTap: () => goToSlide(index),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: index == currentSlide ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: index == currentSlide
                              ? Colors.white
                              : Colors.white.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
