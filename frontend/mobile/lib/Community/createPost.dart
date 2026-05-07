import 'package:flutter/material.dart';
import 'package:mobile_app/Community/community_service.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final TextEditingController _controller = TextEditingController();

  bool isEnabled = false;
  bool isPosting = false;

  @override
  void initState() {
    super.initState();

    _controller.addListener(() {
      setState(() {
        isEnabled = _controller.text.trim().isNotEmpty;
      });
    });
  }

  Future<void> _handlePost() async {
    final text = _controller.text.trim();

    if (text.isEmpty || isPosting) return;

    try {
      setState(() {
        isPosting = true;
      });

      await CommunityApiService.createPost(
        type: "story",
        title: "",
        content: text,
      );

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      debugPrint("Create post error: $e");

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Failed to create post"),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isPosting = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const bgColor = Color(0xFFF7F4F2);
    const purple = Color(0xFF64548E);
    const hintColor = Color(0xFF7C8798);

    return Scaffold(
      backgroundColor: bgColor,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: Row(
                children: [
                  //Cancel Button
                  TextButton(
                    onPressed: isPosting ? null : () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(60, 36),
                    ),
                    child: const Text(
                      "Cancel",
                      style: TextStyle(
                        color: purple,
                        fontSize: 19,
                      ),
                    ),
                  ),

                  const Spacer(),

                  // Post Button
                  SizedBox(
                    height: 42,
                    child: ElevatedButton(
                      onPressed: isEnabled && !isPosting ? _handlePost : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: purple,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(22),
                        ),
                      ).copyWith(
                        backgroundColor:
                        WidgetStateProperty.resolveWith((states) {
                          if (states.contains(WidgetState.disabled)) {
                            return purple.withOpacity(0.4);
                          }
                          return purple;
                        }),
                      ),
                      child: isPosting
                          ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                      : const Text(
                        "Post",
                        style: TextStyle(
                          fontSize: 19,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Content Area
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 18, 14, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(
                        color: Colors.black,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.scatter_plot_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),

                    const SizedBox(width: 12),

                    // Text Field
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        enabled: !isPosting,
                        autofocus: true,
                        maxLines: null,
                        keyboardType: TextInputType.multiline,
                        decoration: const InputDecoration(
                          hintText: "What’s happening?",
                          hintStyle: TextStyle(
                            color: hintColor,
                            fontSize: 25,
                          ),
                          border: InputBorder.none,
                        ),
                        style: const TextStyle(
                          fontSize: 25,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}