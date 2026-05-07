import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_app/Community/community_service.dart';

class CreateImgPostScreen extends StatefulWidget {
  const CreateImgPostScreen({super.key});

  @override
  State<CreateImgPostScreen> createState() => _CreateImgPostScreenState();
}

class _CreateImgPostScreenState extends State<CreateImgPostScreen> {
  final TextEditingController _controller = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  File? _image;

  bool isEnabled = false;
  bool isPosting = false;

  @override
  void initState() {
    super.initState();

    _controller.addListener(() {
      setState(() {
        isEnabled = _controller.text.trim().isNotEmpty || _image != null;
      });
    });
  }

  Future<void> _pickImage() async {
    final XFile? picked = await _picker.pickImage(source: ImageSource.gallery);

    if (picked != null) {
      setState(() {
        _image = File(picked.path);
        isEnabled = true;
      });
    }
  }

  Future<void> _handlePost() async {
    if (_image == null || isPosting) return;

    try {
      setState(() {
        isPosting = true;
      });

      final imageUrl = await CommunityApiService.uploadImage(_image!.path);

      await CommunityApiService.createPost(
        type: "photo",
        caption: _controller.text.trim(),
        imageURL: imageUrl,
      );

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      debugPrint("Create image post error: $e");
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

            const SizedBox(height: 30),

            // Image Upload Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 19),
              child: GestureDetector(
                onTap: isPosting ? null : _pickImage,
                child: Container(
                  height: 220,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: _image == null
                      ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.add_photo_alternate_outlined,
                          size: 40, color: Colors.grey),
                      SizedBox(height: 8),
                      Text(
                        "Add Photo",
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 20,
                        ),
                      )
                    ],
                  )
                      : ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      _image!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Caption Section
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
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

                    Expanded(
                      child: TextField(
                        controller: _controller,
                        enabled: !isPosting,
                        maxLines: null,
                        keyboardType: TextInputType.multiline,
                        decoration: const InputDecoration(
                          hintText: "Write a caption...",
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