import 'package:flutter/material.dart';
import 'package:mobile_app/Companion/companion_service.dart';
import 'package:mobile_app/Companion/invitationSentScreen.dart';
import 'package:mobile_app/Companion/sharingPrivacyScreen.dart';

class CompanionInviteScreen extends StatefulWidget {
  const CompanionInviteScreen({super.key});

  @override
  State<CompanionInviteScreen> createState() => _CompanionInviteScreenState();
}

class _CompanionInviteScreenState extends State<CompanionInviteScreen> {
  final _emailController = TextEditingController();
  final _service = CompanionService();

  String? _viewState;
  CompanionInfo? _companion;
  bool _actionLoading = false;

  static const _brown = Color(0xFF4B3425);

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadStatus() async {
    setState(() => _viewState = null);
    try {
      final status = await _service.getStatus();
      if (!mounted) return;
      setState(() {
        if (!status.hasCompanion) {
          _viewState = 'none';
        } else {
          _companion = status.companion;
          _viewState = status.companion?.status ?? 'pending';
        }
      });
    } catch (_) {
      if (mounted) setState(() => _viewState = 'none');
    }
  }

  Future<void> _sendInvite(String email) async {
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid email address.')),
      );
      return;
    }
    setState(() => _actionLoading = true);
    try {
      await _service.sendInvite(email);
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => InvitationSentScreen(email: email),
        ),
      );
      if (!mounted) return;
      await _loadStatus();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _resendInvite() async {
    final email = _companion?.email;
    if (email == null) return;
    setState(() => _actionLoading = true);
    try {
      await _service.sendInvite(email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invite resent successfully.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _unlinkCompanion() async {
    setState(() => _actionLoading = true);
    try {
      await _service.unlinkCompanion();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Companion removed.')));
      await _loadStatus();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  void _showUnlinkDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Companion?'),
        content: const Text(
          'This will unlink your companion. They will no longer have access to your data.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _unlinkCompanion();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_viewState == null) {
      return const Scaffold(
        backgroundColor: Color(0xFFF5F1EF),
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_viewState == 'active') return _buildActive();
    if (_viewState == 'pending') return _buildPending();
    return _buildInviteForm();
  }

  // Invite form no companion

  Widget _buildInviteForm() {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final isKeyboardOpen = keyboardHeight > 0;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: const Color(0xFFF5F1EF),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(bottom: keyboardHeight),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 23),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    InkWell(
                      onTap: () => Navigator.pop(context),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF6B5A4A)),
                        ),
                        child: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 28,
                          color: _brown,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Companion',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2B211C),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: isKeyboardOpen ? 10 : 75),

                Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    height: isKeyboardOpen ? 130 : 260,
                    child: Image.asset(
                      'assets/companioncats.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),

                SizedBox(height: isKeyboardOpen ? 19 : 66),

                const Text(
                  'Build your circle',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1F1A17),
                    height: 1.1,
                  ),
                ),

                const SizedBox(height: 13),

                const Text(
                  'Experience the journey together. Pair\n'
                  'with your partner to share insights and\n'
                  'stay connected effortlessly.',
                  style: TextStyle(
                    fontSize: 21,
                    height: 1.45,
                    color: Color(0xFF6F6660),
                    fontWeight: FontWeight.w500,
                  ),
                ),

                SizedBox(height: isKeyboardOpen ? 18 : 40),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "PARTNER'S EMAIL",
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF5F5650),
                          letterSpacing: 0.4,
                        ),
                      ),

                      const SizedBox(height: 19),

                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          hintText: 'name@example.com',
                          hintStyle: const TextStyle(
                            fontSize: 16,
                            color: Color(0xFF5F5650),
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF5F3EE),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 13,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),

                      const SizedBox(height: 33),

                      SizedBox(
                        width: double.infinity,
                        height: 53,
                        child: ElevatedButton(
                          onPressed: _actionLoading
                              ? null
                              : () => _sendInvite(_emailController.text.trim()),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _brown,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                          ),
                          child: _actionLoading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : const Text(
                                  'Send Invite',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Pending state
  Widget _buildPending() {
    final name = _companion?.name ?? _companion?.email.split('@').first ?? '–';
    final email = _companion?.email ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F1EF),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 23),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Row(
                children: [
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF6B5A4A)),
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 28,
                        color: _brown,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Companion',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2B211C),
                    ),
                  ),
                ],
              ),

              const Spacer(),

              Center(
                child: Column(
                  children: [
                    const CircleAvatar(
                      radius: 48,
                      backgroundColor: Color(0xFFD6CCBF),
                      child: Icon(Icons.person, size: 48, color: _brown),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2B211C),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      email,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Color(0xFF6F6660),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF6C791),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'AWAITING',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: _brown,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Waiting for your partner to join…',
                      style: TextStyle(fontSize: 16, color: Color(0xFF6F6660)),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              _actionButton(label: 'Resend Invite', onPressed: _resendInvite),

              const SizedBox(height: 12),

              // Send to a different email
              SizedBox(
                width: double.infinity,
                height: 53,
                child: OutlinedButton(
                  onPressed: () => setState(() {
                    _viewState = 'none';
                    _emailController.clear();
                  }),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _brown,
                    side: const BorderSide(color: _brown),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  child: const Text(
                    'Send to a different email',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  // Activ/connected state

  Widget _buildActive() {
    final name = _companion?.name ?? _companion?.email.split('@').first ?? '–';
    final email = _companion?.email ?? '';
    final avatar = _companion?.avatar;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F1EF),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 23),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Row(
                children: [
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF6B5A4A)),
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 28,
                        color: _brown,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Companion',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2B211C),
                    ),
                  ),
                ],
              ),

              const Spacer(),

              Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 48,
                      backgroundColor: const Color(0xFFD6CCBF),
                      backgroundImage: avatar != null
                          ? NetworkImage(avatar)
                          : null,
                      child: avatar == null
                          ? const Icon(Icons.person, size: 48, color: _brown)
                          : null,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2B211C),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      email,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Color(0xFF6F6660),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD6E8C8),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'CONNECTED',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF2E5016),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              _actionButton(
                label: 'Privacy Settings',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CompanionPrivacyScreen(),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                height: 53,
                child: OutlinedButton(
                  onPressed: _showUnlinkDialog,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  child: const Text(
                    'Remove Companion',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  // Shared button helper
  Widget _actionButton({
    required String label,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 53,
      child: ElevatedButton(
        onPressed: _actionLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: _brown,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
        ),
        child: _actionLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }
}
