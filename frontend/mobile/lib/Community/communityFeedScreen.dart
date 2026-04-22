import 'package:flutter/material.dart';
import 'package:mobile_app/Community/createImgPost.dart';
import 'package:mobile_app/Community/createPost.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen>
    with SingleTickerProviderStateMixin {
  bool isFabOpen = false;
  bool showYourPosts = false;

  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;

  final List<Map<String, dynamic>> posts = [
    {
      "name": "Mariane",
      "date": "1/21/20",
      "type": "image",
      "caption": "Top Icons Packs and Resources for Web",
      "image":
      "https://images.unsplash.com/photo-1460317442991-0ec209397118?auto=format&fit=crop&w=1200&q=80",
      "commentsCount": 7,
      "likesCount": 3,
      "isMine": true,
      "commentsList": [
        {
          "name": "kiero_d",
          "time": "2d",
          "text":
          "Interesting. Nicely done. Just one reply or tag on this shout out in the 24hrs since your tweet here.",
          "avatar":
          "https://images.unsplash.com/photo-1500648767791-00dcc994a43e?q=80&w=300&auto=format&fit=crop",
        },
        {
          "name": "amanda",
          "handle": "@amanda_ui",
          "time": "1d",
          "text": "This looks really clean and polished.",
          "avatar":
          "https://images.unsplash.com/photo-1494790108377-be9c29b29330?q=80&w=300&auto=format&fit=crop",
        },
      ],
    },
    {
      "name": "Mariane",
      "date": "1/20/20",
      "type": "story",
      "caption":
      "Fragments Android Wireframe Kit UX Wire was just featured in today’s newsletter.",
      "commentsCount": 5,
      "likesCount": 1,
      "isMine": true,
      "commentsList": [
        {
          "name": "jenny",
          "handle": "@jenny_design",
          "time": "3h",
          "text": "Love this update. Super helpful.",
          "avatar":
          "https://images.unsplash.com/photo-1438761681033-6461ffad8d80?q=80&w=300&auto=format&fit=crop",
        },
      ],
    },
    {
      "name": "Ariana",
      "date": "1/19/20",
      "type": "image",
      "caption": "A calm and minimal interior moment.",
      "image":
      "https://images.unsplash.com/photo-1460317442991-0ec209397118?auto=format&fit=crop&w=1200&q=80",
      "commentsCount": 4,
      "likesCount": 2,
      "isMine": false,
      "commentsList": [
        {
          "name": "leo",
          "handle": "@leo_home",
          "time": "5h",
          "text": "So peaceful. I love the color tones here.",
          "avatar":
          "https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?q=80&w=300&auto=format&fit=crop",
        },
        {
          "name": "sara",
          "handle": "@sara_space",
          "time": "1h",
          "text": "Beautiful composition.",
          "avatar":
          "https://images.unsplash.com/photo-1544005313-94ddf0286df2?q=80&w=300&auto=format&fit=crop",
        },
      ],
    },
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.85,
      end: 1,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void toggleFab() {
    setState(() {
      isFabOpen = !isFabOpen;
    });

    if (isFabOpen) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  void closeFab() {
    if (isFabOpen) {
      setState(() {
        isFabOpen = false;
      });
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    const bgColor = Color(0xFFF7F4F2);
    const textDark = Color(0xFF4B3425);
    const textMuted = Color(0xFF687684);
    const purple = Color(0xFF64548E);

    final filteredPosts = showYourPosts
        ? posts.where((post) => post["isMine"] == true).toList()
        : posts;

    return Scaffold(
      backgroundColor: bgColor,
      body: GestureDetector(
        onTap: closeFab,
        child: Stack(
          children: [
            SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: textDark.withOpacity(0.8),
                              width: 1.2,
                            ),
                          ),
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            iconSize: 32,
                            icon: const Icon(
                              Icons.chevron_left,
                              color: textDark,
                            ),
                            onPressed: () {},
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          "Community",
                          style: TextStyle(
                            color: textDark,
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: SizedBox(
                      height: 42,
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  showYourPosts = false;
                                });
                              },
                              child: Center(
                                child: Text(
                                  "All",
                                  style: TextStyle(
                                    color: showYourPosts ? textMuted : textDark,
                                    fontSize: 19,
                                    fontWeight: showYourPosts
                                        ? FontWeight.w500
                                        : FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  showYourPosts = true;
                                });
                              },
                              child: Center(
                                child: Text(
                                  "Your Posts",
                                  style: TextStyle(
                                    color: showYourPosts ? textDark : textMuted,
                                    fontSize: 19,
                                    fontWeight: showYourPosts
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 2,
                            color: showYourPosts ? Colors.transparent : textDark,
                          ),
                        ),
                        Expanded(
                          child: Container(
                            height: 2,
                            color: showYourPosts ? textDark : Colors.transparent,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      itemCount: filteredPosts.length,
                      itemBuilder: (context, index) {
                        final post = filteredPosts[index];
                        return PostCard(post: post);
                      },
                    ),
                  ),
                ],
              ),
            ),

            if (isFabOpen)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(0.65),
                ),
              ),

            Positioned(
              right: 20,
              bottom: 48,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IgnorePointer(
                    ignoring: !isFabOpen,
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: ScaleTransition(
                        scale: _scaleAnimation,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            _buildFabOption(
                              label: "Photos",
                              icon: Icons.image_outlined,
                              onTap: () {
                                closeFab();
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const CreateImgPostScreen()),
                                );
                              },
                            ),
                            const SizedBox(height: 16),
                            _buildFabOption(
                              label: "Post",
                              icon: Icons.edit_outlined,
                              onTap: () {
                                closeFab();
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const CreatePostScreen()),
                                );
                              },
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: toggleFab,
                    child: Container(
                      width: 62,
                      height: 62,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: purple,
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x337E57C2),
                            blurRadius: 14,
                            offset: Offset(0, 6),
                          ),
                        ],
                      ),
                      child: AnimatedRotation(
                        turns: isFabOpen ? 0.125 : 0,
                        duration: const Duration(milliseconds: 220),
                        child: const Icon(
                          Icons.add,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFabOption({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    const textColor = Colors.white;
    const iconColor = Color(0xFF5B4C87);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: textColor,
            fontSize: 22,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 58,
            height: 58,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 28,
            ),
          ),
        ),
      ],
    );
  }
}

class PostCard extends StatefulWidget {
  final Map<String, dynamic> post;

  const PostCard({super.key, required this.post});

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard>
    with SingleTickerProviderStateMixin {
  static const Color textDark = Color(0xFF3E2E24);
  static const Color pink = Color(0xFFE65B8D);
  static const Color purple = Color(0xFF64548E);

  late bool isLiked;
  late int likesCount;
  bool showComments = false;
  bool showBigHeart = false;

  late final TextEditingController _commentController;
  late List<Map<String, dynamic>> comments;

  late AnimationController _likeController;
  late Animation<double> _likeScaleAnimation;

  @override
  void initState() {
    super.initState();
    isLiked = false;
    likesCount = widget.post["likesCount"] as int;
    comments = List<Map<String, dynamic>>.from(widget.post["commentsList"] ?? []);
    _commentController = TextEditingController();

    _likeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );

    _likeScaleAnimation = Tween<double>(
      begin: 0.7,
      end: 1.25,
    ).animate(
      CurvedAnimation(
        parent: _likeController,
        curve: Curves.easeOutBack,
      ),
    );
  }

  @override
  void dispose() {
    _likeController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  void _toggleLike() {
    setState(() {
      if (isLiked) {
        isLiked = false;
        likesCount--;
      } else {
        isLiked = true;
        likesCount++;
      }
    });

    _likeController.forward(from: 0);
  }

  void _doubleTapLike() {
    if (!isLiked) {
      setState(() {
        isLiked = true;
        likesCount++;
        showBigHeart = true;
      });
      _likeController.forward(from: 0);

      Future.delayed(const Duration(milliseconds: 700), () {
        if (mounted) {
          setState(() {
            showBigHeart = false;
          });
        }
      });
    } else {
      setState(() {
        showBigHeart = true;
      });

      Future.delayed(const Duration(milliseconds: 700), () {
        if (mounted) {
          setState(() {
            showBigHeart = false;
          });
        }
      });
    }
  }

  void _addComment() {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      comments.add({
        "name": "You",
        "time": "now",
        "text": text,
        "avatar":
        "https://images.unsplash.com/photo-1494790108377-be9c29b29330?q=80&w=300&auto=format&fit=crop",
      });
      widget.post["commentsCount"] = (widget.post["commentsCount"] as int) + 1;
      _commentController.clear();
    });

    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final isImagePost = widget.post["type"] == "image";

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CircleAvatar(
            radius: 20,
            backgroundImage: NetworkImage(
              "https://images.unsplash.com/photo-1494790108377-be9c29b29330?q=80&w=300&auto=format&fit=crop",
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      widget.post["name"] as String,
                      style: const TextStyle(
                        color: Color(0xFF141619),
                        fontWeight: FontWeight.w700,
                        fontSize: 19.5,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      "· ${widget.post["date"]}",
                      style: const TextStyle(
                        color: Color(0xFF141619),
                        fontSize: 17,

                      ),
                    ),
                    const Spacer(),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  widget.post["caption"] as String,
                  style: const TextStyle(
                    color: Color(0xFF141619),
                    fontWeight: FontWeight.w500,
                    fontSize: 19,
                    height: 1.4,
                  ),
                ),
                if (isImagePost) ...[
                  const SizedBox(height: 10),
                  GestureDetector(
                    onDoubleTap: _doubleTapLike,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.network(
                            widget.post["image"] as String,
                            height: 180,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                        AnimatedOpacity(
                          opacity: showBigHeart ? 1 : 0,
                          duration: const Duration(milliseconds: 220),
                          child: TweenAnimationBuilder<double>(
                            tween: Tween<double>(
                              begin: showBigHeart ? 0.7 : 1,
                              end: showBigHeart ? 1.2 : 1,
                            ),
                            duration: const Duration(milliseconds: 300),
                            builder: (context, value, child) {
                              return Transform.scale(
                                scale: value,
                                child: child,
                              );
                            },
                            child: const Icon(
                              Icons.favorite,
                              color: Colors.white,
                              size: 82,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () {
                        setState(() {
                          showComments = !showComments;
                        });
                      },
                      child: Row(
                        children: [
                          Icon(
                            showComments
                                ? Icons.chat_bubble
                                : Icons.chat_bubble_outline,
                            size: 19.5,
                            color: Color(0xFF687684),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "${widget.post["commentsCount"]}",
                            style: const TextStyle(
                              color: Color(0xFF687684),
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: _toggleLike,
                      child: Row(
                        children: [
                          AnimatedBuilder(
                            animation: _likeScaleAnimation,
                            builder: (context, child) {
                              final scale = _likeController.isAnimating
                                  ? _likeScaleAnimation.value
                                  : 1.0;
                              return Transform.scale(
                                scale: scale,
                                child: Icon(
                                  isLiked
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  size: 19.5,
                                  color: isLiked ? pink : Color(0xFF687684),
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "$likesCount",
                            style: TextStyle(
                              color: isLiked ? pink : Color(0xFF687684),
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                AnimatedCrossFade(
                  firstChild: const SizedBox.shrink(),
                  secondChild: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Column(
                      children: [
                        ...comments.map(
                              (comment) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _buildCommentTile(comment),
                          ),
                        ),
                        const SizedBox(height: 4),
                        _buildCommentInput(),
                      ],
                    ),
                  ),
                  crossFadeState: showComments
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  duration: const Duration(milliseconds: 240),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentTile(Map<String, dynamic> comment) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 17,
          backgroundImage: NetworkImage(comment["avatar"] as String),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    comment["name"] as String,
                    style: const TextStyle(
                      color: textDark,
                      fontSize: 15.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    "· ${comment["time"]}",
                    style: const TextStyle(
                      color: Color(0xFF9AA3AD),
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                comment["text"] as String,
                style: const TextStyle(
                  color: Color(0xFF2E2E2E),
                  fontSize: 15.5,
                  height: 1.35,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCommentInput() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const CircleAvatar(
          radius: 16,
          backgroundImage: NetworkImage(
            "https://images.unsplash.com/photo-1494790108377-be9c29b29330?q=80&w=300&auto=format&fit=crop",
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: const Color(0xFFE3DDD8),
              ),
            ),
            child: TextField(
              controller: _commentController,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _addComment(),
              decoration: InputDecoration(
                hintText: "Add a comment...",
                hintStyle: const TextStyle(
                  color: Color(0xFF9AA3AD),
                  fontSize: 15,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                suffixIcon: IconButton(
                  onPressed: _addComment,
                  icon: const Icon(
                    Icons.send_rounded,
                    size: 18,
                    color: purple,
                  ),
                ),
              ),
              style: const TextStyle(
                color: textDark,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ],
    );
  }
}