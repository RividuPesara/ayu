import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lottie/lottie.dart';
import 'package:mobile_app/Login Section/loginScreen.dart';
import 'package:mobile_app/patient_service.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  static const brown = Color(0xFF573725);
  static const bg = Color(0xFFF3EFEC);
  static const fieldBg = Color(0xFFF9F9F9);
  static const textDark = Color(0xFF5A3B2B);
  static const iconGrey = Color(0xFFAAA29B);

  final _service = PatientService();
  final _picker = ImagePicker();

  bool _loading = true;
  bool _saving = false;
  bool _isSaved = false;
  String? _error;

  PatientProfile? _profile;
  XFile? _pendingAvatar;
  Uint8List? _pendingAvatarBytes;

  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  final FocusNode _firstNameFocus = FocusNode();
  final FocusNode _lastNameFocus = FocusNode();
  final FocusNode _mobileFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();

  bool _isPasswordVisible = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _mobileCtrl.dispose();
    _passwordCtrl.dispose();
    _firstNameFocus.dispose();
    _lastNameFocus.dispose();
    _mobileFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await _service.fetchProfile();
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _firstNameCtrl.text = profile.firstName;
        _lastNameCtrl.text = profile.lastName;
        _mobileCtrl.text = profile.phone;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _pickAvatar() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;
    final bytes = await picked.readAsBytes();
    setState(() {
      _pendingAvatar = picked;
      _pendingAvatarBytes = bytes;
    });
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  Future<void> _saveChanges() async {
    if (_saving) return;
    setState(() => _saving = true);

    try {
      String? uploadedAvatarUrl;

      if (_pendingAvatar != null) {
        uploadedAvatarUrl = await _service.uploadAvatar(_pendingAvatar!);
      }

      await _service.updateProfile(
        firstName: _firstNameCtrl.text.trim(),
        lastName: _lastNameCtrl.text.trim(),
        phone: _mobileCtrl.text.trim().isEmpty ? null : _mobileCtrl.text.trim(),
        avatarUrl: uploadedAvatarUrl,
      );

      final newPassword = _passwordCtrl.text.trim();
      if (newPassword.isNotEmpty) {
        await FirebaseAuth.instance.currentUser?.updatePassword(newPassword);
      }

      if (!mounted) return;
      setState(() {
        _isSaved = true;
        _saving = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      body: _isSaved ? _buildSuccessUI() : _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: brown));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: brown, size: 48),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: textDark, fontSize: 15),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _loading = true;
                    _error = null;
                  });
                  _loadProfile();
                },
                style: ElevatedButton.styleFrom(backgroundColor: brown),
                child: const Text(
                  'Retry',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return _buildFormUI();
  }

  Widget _buildSuccessUI() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Lottie.asset('assets/success.json', width: 140, repeat: false),
            const SizedBox(height: 40),
            const Text(
              "Your changes saved successfully",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: textDark,
                fontSize: 23,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: brown,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                child: const Text(
                  "Back to Dashboard",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormUI() {
    return Stack(
      children: [
        Container(
          height: 250,
          width: double.infinity,
          decoration: const BoxDecoration(
            color: brown,
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.elliptical(290, 150),
              bottomRight: Radius.elliptical(290, 150),
            ),
          ),
        ),
        SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    _backButton(),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Text(
                        "Edit Profile",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.logout, color: Colors.white),
                      onPressed: _logout,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              _buildAvatar(),
              const SizedBox(height: 12),
              Text(
                _profile?.fullName ?? '',
                style: const TextStyle(
                  color: textDark,
                  fontSize: 25,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 18),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      _buildLabel("First Name"),
                      const SizedBox(height: 8),
                      _buildField(
                        _firstNameFocus,
                        _firstNameCtrl,
                        "First Name",
                      ),

                      const SizedBox(height: 12),
                      _buildLabel("Last Name"),
                      const SizedBox(height: 8),
                      _buildField(_lastNameFocus, _lastNameCtrl, "Last Name"),

                      const SizedBox(height: 12),
                      _buildLabel("Mobile Number"),
                      const SizedBox(height: 8),
                      _buildField(
                        _mobileFocus,
                        _mobileCtrl,
                        "07XXXXXXXX",
                        keyboardType: TextInputType.number,
                      ),

                      const SizedBox(height: 12),
                      _buildLabel("Email Address"),
                      const SizedBox(height: 8),
                      _buildReadOnlyField(
                        _profile?.email ?? '',
                        prefixIcon: Icons.email_outlined,
                      ),

                      const SizedBox(height: 12),
                      _buildLabel("Password"),
                      const SizedBox(height: 8),
                      _buildPasswordField(),

                      const SizedBox(height: 50),

                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _saving ? null : _saveChanges,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: brown,
                            disabledBackgroundColor: brown.withOpacity(0.6),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                          ),
                          child: _saving
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : const Text(
                                  "Save Changes",
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAvatar() {
    final avatarUrl = _profile?.avatarUrl ?? '';
    ImageProvider? imageProvider;

    if (_pendingAvatarBytes != null) {
      imageProvider = MemoryImage(_pendingAvatarBytes!);
    } else if (avatarUrl.isNotEmpty) {
      imageProvider = NetworkImage(avatarUrl);
    }

    return GestureDetector(
      onTap: _pickAvatar,
      child: Stack(
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              color: const Color(0xFFD4C4BC),
              image: imageProvider != null
                  ? DecorationImage(image: imageProvider, fit: BoxFit.cover)
                  : null,
            ),
            child: imageProvider == null
                ? const Icon(Icons.person, size: 48, color: Colors.white)
                : null,
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: 28,
              height: 28,
              decoration: const BoxDecoration(
                color: brown,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.camera_alt,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _backButton() {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white),
      ),
      child: IconButton(
        icon: const Icon(Icons.chevron_left, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
    );
  }

  static Widget _buildLabel(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: const TextStyle(
          color: textDark,
          fontSize: 15.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildField(
    FocusNode focus,
    TextEditingController controller,
    String hint, {
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: fieldBg,
        borderRadius: BorderRadius.circular(24),
      ),
      child: TextField(
        focusNode: focus,
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          hintText: hint,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 10,
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordField() {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: fieldBg,
        borderRadius: BorderRadius.circular(24),
      ),
      child: TextField(
        focusNode: _passwordFocus,
        controller: _passwordCtrl,
        obscureText: !_isPasswordVisible,
        decoration: InputDecoration(
          hintText: "Leave blank to keep current",
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 13,
          ),
          suffixIcon: IconButton(
            icon: Icon(
              _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
              color: iconGrey,
              size: 20,
            ),
            onPressed: () =>
                setState(() => _isPasswordVisible = !_isPasswordVisible),
          ),
        ),
      ),
    );
  }

  Widget _buildReadOnlyField(String value, {IconData? prefixIcon}) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: fieldBg.withOpacity(0.7),
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(
        children: [
          if (prefixIcon != null) ...[
            Icon(prefixIcon, color: iconGrey, size: 20),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              style: const TextStyle(color: iconGrey, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }
}
