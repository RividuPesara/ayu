import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

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

  bool _isSaved = false;
  bool _isPasswordVisible = false;

  final FocusNode _firstNameFocus = FocusNode();
  final FocusNode _lastNameFocus = FocusNode();
  final FocusNode _mobileFocus = FocusNode();
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();

  @override
  void dispose() {
    _firstNameFocus.dispose();
    _lastNameFocus.dispose();
    _mobileFocus.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      body: _isSaved ? _buildSuccessUI() : _buildFormUI(),
    );
  }

  Widget _buildSuccessUI() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Lottie.asset(
              'assets/success.json',
              width: 140,
              repeat: false,
            ),
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
                onPressed: () {
                  Navigator.pop(context);
                },
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
                    const Icon(Icons.logout, color: Colors.white),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              Container(
                width: 165,
                height: 165,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 4),
                  image: const DecorationImage(
                    image: NetworkImage(
                      '',
                    ),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                "Shinomiya Kaguya",
                style: TextStyle(
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
                      _buildField(_firstNameFocus, "Shinomiya"),

                      const SizedBox(height: 12),
                      _buildLabel("Last Name"),
                      const SizedBox(height: 8),
                      _buildField(_lastNameFocus, "Kaguya"),

                      const SizedBox(height: 12),
                      _buildLabel("Mobile Number"),
                      const SizedBox(height: 8),
                      _buildField(_mobileFocus, "0775455167",
                          keyboardType: TextInputType.number),

                      const SizedBox(height: 12),
                      _buildLabel("Email Address"),
                      const SizedBox(height: 8),
                      _buildField(
                        _emailFocus,
                        "email@gmail.com",
                        prefixIcon: Icons.email_outlined,
                      ),

                      const SizedBox(height: 12),
                      _buildLabel("Password"),
                      const SizedBox(height: 8),
                      _buildField(
                        _passwordFocus,
                        "********",
                        obscureText: !_isPasswordVisible,
                        prefixIcon: Icons.lock_outline,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isPasswordVisible
                                ? Icons.visibility
                                : Icons.visibility_off,
                            color: iconGrey,
                          ),
                          onPressed: () {
                            setState(() {
                              _isPasswordVisible = !_isPasswordVisible;
                            });
                          },
                        ),
                      ),

                      const SizedBox(height: 50),

                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _isSaved = true;
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: brown,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                          ),
                          child: const Text(
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
      String hint, {
        bool obscureText = false,
        TextInputType keyboardType = TextInputType.text,
        IconData? prefixIcon,
        Widget? suffixIcon,
      }) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: fieldBg,
        borderRadius: BorderRadius.circular(24),
      ),
      child: TextField(
        focusNode: focus,
        obscureText: obscureText,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          hintText: hint,
          border: InputBorder.none,
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          prefixIcon: prefixIcon != null
              ? Icon(prefixIcon, color: iconGrey)
              : null,
          suffixIcon: suffixIcon,
        ),
      ),
    );
  }
}