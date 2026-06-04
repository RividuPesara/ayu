import 'package:flutter/material.dart';
import 'package:mobile_app/Community/createImgPost.dart';
import 'package:mobile_app/Community/createPost.dart';
import 'package:mobile_app/Community/community_service.dart';

class CommunityScreen extends StatefulWidget {
  final String? focusPostId;
  const CommunityScreen({super.key, this.focusPostId});

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

  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _postKeys = {};

  List<Map<String, dynamic>> posts = [];
  bool isLoading = true;

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
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    fetchPosts(); // Fetch posts when screen loads
  }

  Future<void> fetchPosts() async {
    try {
      setState(() => isLoading = true);

      final data = showYourPosts
          ? await CommunityApiService.getMyPosts()
          : await CommunityApiService.getPosts();

      _postKeys.clear();
      for (final post in data) {
        final id = post['id']?.toString() ?? '';
        if (id.isNotEmpty) _postKeys[id] = GlobalKey();
      }

      setState(() {
        posts = data;
        isLoading = false;
      });

      // scroll to the post that triggered the notification tap
      final focusId = widget.focusPostId;
      if (focusId != null && _postKeys.containsKey(focusId)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final key = _postKeys[focusId];
          if (key?.currentContext != null) {
            Scrollable.ensureVisible(
              key!.currentContext!,
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOut,
            );
          }
        });
      }
    } catch (e) {
      setState(() => isLoading = false);
      debugPrint("Fetch posts error: $e");
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void toggleFab() {
    setState(() => isFabOpen = !isFabOpen);
    isFabOpen ? _controller.forward() : _controller.reverse();
  }

  void closeFab() {
    if (isFabOpen) {
      setState(() => isFabOpen = false);
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    const bgColor = Color(0xFFF7F4F2);
    const textDark = Color(0xFF4B3425);
    const textMuted = Color(0xFF687684);
    const purple = Color(0xFF64548E);

    return Scaffold(
      backgroundColor: bgColor,
      body: GestureDetector(
        onTap: closeFab,
        child: Stack(
          children: [
            SafeArea(
              // Main content
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
                            onPressed: () => Navigator.pop(context),
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
                                setState(() => showYourPosts = false);
                                fetchPosts();
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
                                setState(() => showYourPosts = true);
                                fetchPosts();
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
                            color: showYourPosts
                                ? Colors.transparent
                                : textDark,
                          ),
                        ),
                        Expanded(
                          child: Container(
                            height: 2,
                            color: showYourPosts
                                ? textDark
                                : Colors.transparent,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : posts.isEmpty
                        ? const Center(
                            child: Text(
                              "No posts found",
                              style: TextStyle(
                                color: textDark,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: fetchPosts,
                            child: ListView.builder(
                              controller: _scrollController,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                              ),
                              itemCount: posts.length,
                              itemBuilder: (context, index) {
                                final postId =
                                    posts[index]['id']?.toString() ?? '';
                                return PostCard(
                                  key: _postKeys[postId],
                                  post: posts[index],
                                  onRefresh: fetchPosts,
                                  showStatusBadge: showYourPosts,
                                );
                              },
                            ),
                          ),
                  ),
                ],
              ),
            ),
            if (isFabOpen)
              Positioned.fill(
                child: Container(color: Colors.black.withOpacity(0.65)),
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
                              onTap: () async {
                                closeFab();
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const CreateImgPostScreen(),
                                  ),
                                );
                                fetchPosts();
                              },
                            ),
                            const SizedBox(height: 16),
                            _buildFabOption(
                              label: "Post",
                              icon: Icons.edit_outlined,
                              onTap: () async {
                                closeFab();
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const CreatePostScreen(),
                                  ),
                                );
                                fetchPosts();
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
            child: Icon(icon, color: iconColor, size: 28),
          ),
        ),
      ],
    );
  }
}

class PostCard extends StatefulWidget {
  final Map<String, dynamic> post;
  final VoidCallback onRefresh;
  final bool showStatusBadge;

  const PostCard({
    super.key,
    required this.post,
    required this.onRefresh,
    required this.showStatusBadge,
  });

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
    isLiked = widget.post["isLiked"] == true;
    likesCount = widget.post["likeCount"] ?? 0;
    comments = [];
    _commentController = TextEditingController();

    _likeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );

    _likeScaleAnimation = Tween<double>(begin: 0.7, end: 1.25).animate(
      CurvedAnimation(parent: _likeController, curve: Curves.easeOutBack),
    );
  }

  @override
  void dispose() {
    _likeController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  String _formatCreatedAt(dynamic createdAt) {
    if (createdAt == null) return "";

    try {
      if (createdAt is Map && createdAt["seconds"] != null) {
        final seconds = createdAt["seconds"];
        final date = DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
        return "${date.day}/${date.month}/${date.year}";
      }
    } catch (_) {
      return "";
    }

    return "";
  }

  Widget _buildPostContent({
    required String type,
    required String text,
    required String caption,
    required String title,
    required String content,
    required String imageURL,
  }) {
    final hasImage = imageURL.trim().isNotEmpty;

    if (type == "status") {
      if (hasImage) {
        return _buildPostImage(imageURL, isStatusImage: true);
      }

      if (text.trim().isNotEmpty) {
        return _buildPostParagraph(text);
      }

      return const SizedBox.shrink();
    }

    if (type == "photo" || type == "image") {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasImage) _buildPostImage(imageURL),
          if (caption.trim().isNotEmpty && text.trim().isEmpty) ...[
            const SizedBox(height: 8),
            _buildPostParagraph(caption),
          ],
          if (!hasImage && text.trim().isNotEmpty) _buildPostParagraph(text),
        ],
      );
    }

    if (type == "story") {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title.trim().isNotEmpty)
            Text(
              title,
              style: const TextStyle(
                color: Color(0xFF141619),
                fontSize: 15,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          if (title.trim().isNotEmpty && content.trim().isNotEmpty)
            const SizedBox(height: 5),
          if (content.trim().isNotEmpty) _buildPostParagraph(content),
        ],
      );
    }

    final fallback = caption.isNotEmpty
        ? caption
        : text.isNotEmpty
        ? text
        : content;

    return fallback.trim().isNotEmpty
        ? _buildPostParagraph(fallback)
        : const SizedBox.shrink();
  }

  Widget _buildPostParagraph(String value) {
    return Text(
      value,
      style: const TextStyle(
        color: Color(0xFF141619),
        fontWeight: FontWeight.w400,
        fontSize: 13,
        height: 1.35,
      ),
    );
  }

  Widget _buildPostImage(String imageUrl, {bool isStatusImage = false}) {
    final imageHeight = isStatusImage ? 280.0 : 260.0;

    return GestureDetector(
      onDoubleTap: _doubleTapLike,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            height: imageHeight,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Color(0xFFF7F4F2),
              borderRadius: BorderRadius.circular(24),
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.network(
              imageUrl,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return const Center(
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: Color(0xFF64548E),
                  ),
                );
              },
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
                return Transform.scale(scale: value, child: child);
              },
              child: const Icon(Icons.favorite, color: Colors.white, size: 82),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleLike() async {
    final oldLiked = isLiked;
    final oldCount = likesCount;

    setState(() {
      isLiked = !isLiked;
      likesCount += isLiked ? 1 : -1;
    });

    _likeController.forward(from: 0);

    try {
      final result = await CommunityApiService.toggleLike(widget.post["id"]);

      setState(() {
        isLiked = result["liked"] == true;
        likesCount = result["likeCount"] ?? likesCount;
      });
    } catch (e) {
      setState(() {
        isLiked = oldLiked;
        likesCount = oldCount;
      });

      debugPrint("Like error: $e");
    }
  }

  Future<void> _doubleTapLike() async {
    setState(() => showBigHeart = true);

    if (!isLiked) {
      await _toggleLike();
    }

    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) {
        setState(() => showBigHeart = false);
      }
    });
  }

  Future<void> _loadComments() async {
    try {
      final data = await CommunityApiService.getComments(widget.post["id"]);

      setState(() {
        comments = data;
      });
    } catch (e) {
      debugPrint("Comment load error: $e");
    }
  }

  Future<void> _addComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    try {
      await CommunityApiService.addComment(
        postId: widget.post["id"],
        text: text,
      );

      _commentController.clear();
      FocusScope.of(context).unfocus();

      await _loadComments();

      setState(() {
        widget.post["commentCount"] = (widget.post["commentCount"] ?? 0) + 1;
      });
    } catch (e) {
      debugPrint("Add comment error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final type = widget.post["type"]?.toString() ?? "";
    final avatar = widget.post["authorAvatar"]?.toString() ?? "";
    final imageURL = widget.post["imageURL"]?.toString() ?? "";
    final authorName = widget.post["authorName"]?.toString() ?? "User";
    final authorHandle = widget.post["authorHandle"]?.toString() ?? "";
    final dateText = _formatCreatedAt(widget.post["createdAt"]);

    final text = widget.post["text"]?.toString() ?? "";
    final caption = widget.post["caption"]?.toString() ?? "";
    final title = widget.post["title"]?.toString() ?? "";
    final content = widget.post["content"]?.toString() ?? "";
    final status = widget.post["status"]?.toString().toLowerCase() ?? "";

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
            child: avatar.isEmpty ? const Icon(Icons.person, size: 20) : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            authorName,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF141619),
                              fontWeight: FontWeight.w700,
                              fontSize: 17,
                            ),
                          ),
                        ),
                        if (authorHandle.isNotEmpty) ...[
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              "@$authorHandle",
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF687684),
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(width: 4),
                        Text(
                          dateText.isNotEmpty ? "· $dateText" : "",
                          style: const TextStyle(
                            color: Color(0xFF687684),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    _buildPostContent(
                      type: type,
                      text: text,
                      caption: caption,
                      title: title,
                      content: content,
                      imageURL: imageURL,
                    ),

                    const SizedBox(height: 10),

                    Row(
                      children: [
                        InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () async {
                            setState(() => showComments = !showComments);

                            if (showComments) {
                              await _loadComments();
                            }
                          },
                          child: Row(
                            children: [
                              Icon(
                                showComments
                                    ? Icons.chat_bubble
                                    : Icons.chat_bubble_outline,
                                size: 19.5,
                                color: const Color(0xFF687684),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                "${widget.post["commentCount"] ?? 0}",
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
                                      color: isLiked
                                          ? pink
                                          : const Color(0xFF687684),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(width: 4),
                              Text(
                                "$likesCount",
                                style: TextStyle(
                                  color: isLiked
                                      ? pink
                                      : const Color(0xFF687684),
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

                // ✅ STATUS LABEL (TOP RIGHT)
                if (widget.showStatusBadge &&
                    (status == "approved" ||
                        status == "rejected" ||
                        status == "pending"))
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: status == "approved"
                            ? Colors.green
                            : status == "rejected"
                            ? Colors.red
                            : Color(0xFFCC8B2C),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentTile(Map<String, dynamic> comment) {
    final avatar = comment["authorAvatar"]?.toString() ?? "";
    final authorName = comment["authorName"]?.toString() ?? "User";
    final createdAt = _formatCreatedAt(comment["createdAt"]);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 17,
          backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
          child: avatar.isEmpty ? const Icon(Icons.person, size: 17) : null,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      authorName,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: textDark,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    createdAt.isNotEmpty ? "· $createdAt" : "",
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
                comment["text"]?.toString() ?? "",
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
        const CircleAvatar(radius: 16, child: Icon(Icons.person, size: 16)),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFE3DDD8)),
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
                  icon: const Icon(Icons.send_rounded, size: 18, color: purple),
                ),
              ),
              style: const TextStyle(color: textDark, fontSize: 13),
            ),
          ),
        ),
      ],
    );
  }
}
