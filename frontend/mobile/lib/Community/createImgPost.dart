import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

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
                    onPressed: () => Navigator.pop(context),
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
                      onPressed: isEnabled
                          ? () {
                        print("Post: ${_controller.text}");
                      }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: purple,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(22),
                        ),
                      ).copyWith(
                        backgroundColor:
                        MaterialStateProperty.resolveWith((states) {
                          if (states.contains(MaterialState.disabled)) {
                            return purple.withOpacity(0.4);
                          }
                          return purple;
                        }),
                      ),
                      child: const Text(
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
                onTap: _pickImage,
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