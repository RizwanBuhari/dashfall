import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ShimmeringWidget extends StatefulWidget {
  final Widget child;
  const ShimmeringWidget({required this.child, super.key});

  @override
  State<ShimmeringWidget> createState() => _ShimmeringWidgetState();
}

class _ShimmeringWidgetState extends State<ShimmeringWidget> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  )..repeat(reverse: true);

  late final Animation<double> _animation = Tween(begin: 0.6, end: 1.0).animate(
    CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: ScaleTransition(
        scale: _animation,
        child: widget.child,
      ),
    );
  }
}

class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

  // Badge widget for top 3 with shimmer
  Widget _buildBadge(int rank) {
    switch (rank) {
      case 1:
        return Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFFFFD700), Color(0xFFFFB700)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: ShimmeringWidget(
            child: const Icon(Icons.emoji_events, color: Colors.white, size: 28),
          ),
        );
      case 2:
        return Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFFC0C0C0), Color(0xFFA9A9A9)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: ShimmeringWidget(
            child: const Icon(Icons.emoji_events, color: Colors.white, size: 26),
          ),
        );
      case 3:
        return Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFFCD7F32), Color(0xFFB87333)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: ShimmeringWidget(
            child: const Icon(Icons.emoji_events, color: Colors.white, size: 24),
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  // Gradient background for cards
  BoxDecoration _cardDecoration(int index) {
    final bool isEven = index % 2 == 0;
    return BoxDecoration(
      gradient: LinearGradient(
        colors: isEven
            ? [Color(0xFF007AFF).withOpacity(0.15), Colors.white]
            : [Colors.white, Color(0xFF007AFF).withOpacity(0.1)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(16),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE6F0FF), // Very light blue background
      appBar: AppBar(
        title: const Text(
          'Global Leaderboard',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            fontSize: 22,
          ),
        ),
        backgroundColor: const Color(0xFF007AFF),
        elevation: 8,
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('high_scores')
            .orderBy('score', descending: true)
            .limit(50)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: Color(0xFF007AFF)));
          }
          if (snapshot.hasError) {
            return Center(
                child: Text(
                  'Error loading leaderboard: ${snapshot.error}',
                  style: const TextStyle(color: Colors.redAccent),
                ));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'No scores yet. Be the first!',
                style: TextStyle(
                  color: Color(0xFF007AFF),
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            );
          }

          final scores = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            itemCount: scores.length,
            itemBuilder: (context, index) {
              Map<String, dynamic> scoreData =
              scores[index].data() as Map<String, dynamic>;

              String username = scoreData['original_username'] ?? 'Anonymous';
              int scoreValue = scoreData['score'] ?? 0;

              final cardDecoration = _cardDecoration(index);

              return Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                decoration: cardDecoration,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  leading: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const RadialGradient(
                            colors: [
                              Color(0xFF007AFF),
                              Colors.transparent,
                            ],
                            radius: 0.7,
                          ),
                        ),
                      ),
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: Colors.white,
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                            color: Color(0xFF007AFF),
                          ),
                        ),
                      ),
                    ],
                  ),
                  title: Row(
                    children: [
                      if (index < 3) _buildBadge(index + 1),
                      if (index < 3) const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          username,
                          style: const TextStyle(
                            color: Color(0xFF0047B3), // deeper blue for text
                            fontWeight: FontWeight.w700,
                            fontSize: 20,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  trailing: Text(
                    scoreValue.toString(),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                      color: Color(0xFF007AFF),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
