import 'package:flutter/material.dart';
import 'package:mobile_app/core/localization/app_localizations.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F4F2),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F4F2),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          context.t('legal.privacyTitle'),
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              /// Sinhala readers get told up front that the body below is
              /// English and that the English text is the binding one.
              if (context.isSinhala) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEDE7F6),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    context.t('legal.englishNotice'),
                    style: const TextStyle(fontSize: 13, height: 1.5),
                  ),
                ),
              ],

              /// HEADER
              Text(
                "Ayu — Mental Health & Cancer Support\n"
                "Effective Date: 1 May 2026",
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  height: 1.5,
                ),
              ),

              SizedBox(height: 16),

              Text(
                "Ayu is a safe space. We built it to support cancer patients "
                "through their journey with a chatbot, mood journaling, "
                "medication reminders, and doctor consultations.\n\n"
                "Because of the sensitive nature of what you share with us, "
                "we want to be fully transparent about how we handle your "
                "information.\n\n"
                "Please read this policy before creating an account. "
                "By signing up, you agree to what is described here.",
                style: TextStyle(
                  fontSize: 14,
                  height: 1.7,
                  color: Colors.black87,
                ),
              ),

              SizedBox(height: 28),

              /// SECTION 1
              SectionTitle(title: context.t('privacyDoc.s1')),

              SectionText(
                text:
                    "Your account details: When you sign up: your name, "
                    "email address and phone number.\n\n"
                    "Your health and personal information: During onboarding, "
                    "you may share your cancer type, stage, and current treatment, "
                    "as well as your gender, date of birth, religion, and the "
                    "types of content you find comforting. This helps us "
                    "personalise your experience.\n\n"
                    "Your chatbot conversations: Every message you send to "
                    "the Ayu chatbot is saved. The app also analyses your "
                    "messages to understand your emotional state and check "
                    "for signs of distress. A short personal summary is built "
                    "up over time from your conversations. This helps Ayu "
                    "remember context and feel more personal to you.\n\n"
                    "Your mood journal entries: Entries you write are saved, "
                    "including what you wrote, your self-reported mood, and "
                    "the date. The app also analyses your writing to assess "
                    "your emotional state.\n\n"
                    "Your daily mood check-ins: Your daily mood selections "
                    "are saved with a date.\n\n"
                    "Your medications: Medications you add, their schedules, "
                    "and your logs of when you took them.\n\n"
                    "Your appointments: Appointment dates, times, notes you "
                    "write before sessions, and any clinical notes or "
                    "prescriptions your doctor adds.",
              ),

              SizedBox(height: 28),

              /// SECTION 2
              SectionTitle(title: context.t('privacyDoc.s2')),

              BulletText(
                text:
                    "To run the app and provide all its features to you.",
              ),

              BulletText(
                text:
                    "To personalise the chatbot and video recommendations "
                    "based on your mood and interests.",
              ),

              BulletText(
                text:
                    "To help your doctor understand your wellbeing over time.",
              ),

              BulletText(
                text:
                    "To detect signs of emotional distress and respond with "
                    "appropriate support.",
              ),

              BulletText(
                text:
                    "To improve Ayu’s AI over time.",
              ),

              SizedBox(height: 14),

              Text(
                "We do not use your information for advertising.\n"
                "We do not sell your data.",
                style: TextStyle(
                  fontSize: 14,
                  height: 1.7,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),

              SizedBox(height: 28),

              /// SECTION 3
              SectionTitle(title: context.t('privacyDoc.s3')),

              SectionText(
                text:
                    "We may use anonymised and aggregated data — meaning "
                    "data that cannot be traced back to you — to train and "
                    "improve the AI models that power Ayu’s chatbot and mood "
                    "analysis. This helps Ayu better support future patients.\n\n"
                    "We will never use your name, personal details, or "
                    "anything that identifies you individually in this "
                    "process. Your privacy is not compromised as part of "
                    "any improvement work.",
              ),

              SizedBox(height: 28),

              /// SECTION 4
              SectionTitle(title: context.t('privacyDoc.s4')),

              SectionText(
                text:
                    "Your Companion on Ayu: Your Companion can see your "
                    "mood statistics, appointments, todo tracking, and any "
                    "prescriptions or documents shared. But you are able "
                    "to choose what to share with them.\n\n"
                    "Third-party services we rely on: To operate Ayu, "
                    "we use a small number of trusted services:\n\n"
                    "• Google — stores your data securely and powers the AI chatbot\n"
                    "• Zoom — handles your video consultations with doctors\n"
                    "• YouTube — provides the recommended videos based on your mood\n"
                    "• Cloudinary — stores your profile photo and any appointment documents\n\n"
                    "Each of these services is bound by their own security "
                    "and privacy standards. We share only what is necessary "
                    "for each service to function.\n\n"
                    "We do not share your information with insurers, "
                    "employers, government agencies, or any marketing companies.",
              ),

              SizedBox(height: 28),

              /// SECTION 5
              SectionTitle(title: context.t('privacyDoc.s5')),

              SectionText(
                text:
                    "Ayu monitors your chatbot messages and journal entries "
                    "for signs of serious distress. If the app detects a "
                    "potential crisis:\n\n"
                    "• The chatbot will respond with immediate support and resources\n"
                    "• A note is made on your session so your care can be informed\n\n"
                    "Ayu is a support tool — it is not a substitute for "
                    "emergency services. If you are in immediate danger, "
                    "please call 1990 (Suwa Seriya — Sri Lanka emergency) "
                    "or the CCCline on 1333 (24/7, free mental health support).",
              ),

              SizedBox(height: 28),

              /// SECTION 6
              SectionTitle(title: context.t('privacyDoc.s6')),

              SectionText(
                text:
                    "Your information is stored on secure, encrypted servers. "
                    "All data transferred between your phone and our servers "
                    "is protected. Only you and your assigned doctor can "
                    "access your personal records.\n\n"
                    "No system is completely risk-free. If you ever suspect "
                    "your account has been compromised, contact us straight away.",
              ),

              SizedBox(height: 28),

              /// SECTION 7
              SectionTitle(title: context.t('privacyDoc.s7')),

              SectionText(
                text:
                    "We keep your data for as long as your account is active. "
                    "If you delete your account, all your personal information "
                    "is permanently removed from our systems within 30 days.",
              ),

              SizedBox(height: 28),

              /// SECTION 8
              SectionTitle(title: context.t('privacyDoc.s8')),

              SectionText(
                text:
                    "You have the right to:\n\n"
                    "• See the data we hold about you\n"
                    "• Correct anything that is inaccurate\n"
                    "• Delete your account and all associated data\n"
                    "• Ask us to stop processing your data in certain situations\n\n"
                    "To make any of these requests, contact us using the "
                    "details below.",
              ),

              SizedBox(height: 28),

              /// SECTION 9
              SectionTitle(title: context.t('privacyDoc.s9')),

              SectionText(
                text:
                    "Ayu is intended for adults. We do not knowingly collect "
                    "information from anyone under the age of 18.\n\n"
                    "If you believe a child has registered, please contact "
                    "us and we will remove the account.",
              ),

              SizedBox(height: 28),

              /// SECTION 10
              SectionTitle(title: context.t('privacyDoc.s10')),

              SectionText(
                text:
                    "If we make significant changes to this policy, we will "
                    "notify you within the app and ask you to review and "
                    "accept the updated version before continuing.",
              ),

              SizedBox(height: 28),

              /// SECTION 11
              SectionTitle(title: context.t('privacyDoc.s11')),

              SectionText(
                text:
                    "For any questions or requests about your privacy:\n\n"
                    "Email: support@ayu.lk\n"
                    "In-app: Use the feedback form under your profile settings\n\n"
                    "We will respond within 14 days.",
              ),

              SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

/// SECTION TITLE
class SectionTitle extends StatelessWidget {
  final String title;

  const SectionTitle({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.bold,
          color: Colors.black,
        ),
      ),
    );
  }
}

/// SECTION TEXT
class SectionText extends StatelessWidget {
  final String text;

  const SectionText({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        height: 1.8,
        color: Colors.black87,
      ),
    );
  }
}

/// BULLET TEXT
class BulletText extends StatelessWidget {
  final String text;

  const BulletText({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "• ",
            style: TextStyle(
              fontSize: 16,
              height: 1.5,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                height: 1.7,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}