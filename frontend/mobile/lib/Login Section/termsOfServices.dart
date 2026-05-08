import 'package:flutter/material.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

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
        title: const Text(
          "Terms of Service",
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
            children: const [

              /// HEADER
              Text(
                "Ayu — Mental Health & Cancer Support Platform\n"
                "Effective Date: May 4, 2026\n"
                "Last Updated: May 4, 2026",
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  height: 1.5,
                ),
              ),

              SizedBox(height: 24),

              /// SECTION 1
              SectionTitle(title: "1. Acceptance of Terms"),

              SectionText(
                text:
                    "By downloading, installing, or using the Ayu mobile "
                    "application (“App”), you (“User”) agree to be bound by "
                    "these Terms and Conditions (“Terms”). If you do not "
                    "agree, please do not use the App.\n\n"
                    "These Terms apply to all users of the App, including "
                    "patients, caregivers (Companions), and registered "
                    "medical professionals (Doctors).",
              ),

              SizedBox(height: 28),

              /// SECTION 2
              SectionTitle(title: "2. About Ayu"),

              SectionText(
                text:
                    "Ayu is a digital mental health and cancer support "
                    "platform designed for patients in Sri Lanka.\n\n"
                    "The App provides:\n\n"
                    "• AI-powered emotional support chatbot\n"
                    "• Mood journal with AI sentiment analysis\n"
                    "• Daily mood check-ins\n"
                    "• Medication & treatment tracker\n"
                    "• Video consultations via Zoom\n"
                    "• Curated video recommendations from YouTube\n"
                    "• Companion access for caregivers\n"
                    "• Articles & community support features",
              ),

              SizedBox(height: 28),

              /// SECTION 3
              SectionTitle(title: "3. Medical Disclaimer"),

              SectionText(
                text:
                    "IMPORTANT: Ayu is NOT a substitute for professional "
                    "medical advice, diagnosis, or treatment.\n\n"
                    "• The AI chatbot, mood analysis, and sentiment scoring "
                    "features are support tools only and do not constitute "
                    "clinical advice.\n\n"
                    "• Always consult a qualified healthcare provider "
                    "regarding any medical condition or treatment decision.\n\n"
                    "• The chatbot automatically monitors messages for crisis "
                    "indicators. Crisis detection is not guaranteed and "
                    "must never be relied upon as a primary safety measure.\n\n"
                    "Emergency Contacts:\n"
                    "• Sri Lanka Emergency: 1990\n"
                    "• Sumithrayo Suicide Hotline: 0112 696 666",
              ),

              SizedBox(height: 28),

              /// SECTION 4
              SectionTitle(title: "4. Eligibility"),

              SectionText(
                text:
                    "• You must be 18 years of age or older to create an "
                    "account independently.\n\n"
                    "• Users under 18 may only use the App under the "
                    "supervision of a parent or legal guardian.\n\n"
                    "• The App is intended for use within Sri Lanka.",
              ),

              SizedBox(height: 28),

              /// SECTION 5
              SectionTitle(title: "5. User Accounts & Registration"),

              SectionText(
                text:
                    "• You agree to provide accurate and truthful information "
                    "during registration.\n\n"
                    "• You are responsible for maintaining the confidentiality "
                    "of your login credentials.\n\n"
                    "• Notify us immediately of any unauthorized access.\n\n"
                    "• One account per user is permitted.\n\n"
                    "• Accounts are personal and non-transferable.",
              ),

              SizedBox(height: 28),

              /// SECTION 6
              SectionTitle(title: "6. Onboarding & Health Data"),

              SectionText(
                text:
                    "During onboarding, you may provide:\n\n"
                    "• Date of birth, gender, and religion\n"
                    "• Cancer type, stage, and treatment details\n"
                    "• Mood preferences and content interests\n\n"
                    "This data is stored securely and used only to "
                    "personalise your experience.",
              ),

              SizedBox(height: 28),

              /// SECTION 7
              SectionTitle(title: "7. Data We Collect and How We Use It"),

              SectionText(
                text:
                    "We collect and use:\n\n"
                    "• Account details for authentication\n"
                    "• Health profile information for personalised support\n"
                    "• Mood journals and mood check-ins for emotional tracking\n"
                    "• AI chat messages to improve conversations\n"
                    "• Medication schedules and logs\n"
                    "• Companion-shared data\n\n"
                    "Data is stored using Firebase, Cloudinary, and Redis.",
              ),

              SizedBox(height: 28),

              /// SECTION 8
              SectionTitle(title: "8. Privacy & Data Security"),

              SectionText(
                text:
                    "• Your health data is treated as sensitive information.\n\n"
                    "• Firebase Authentication is used for secure identity verification.\n\n"
                    "• AI-generated memory summaries are private unless you "
                    "explicitly share them.\n\n"
                    "• Doctors can access only the data of patients with "
                    "active appointments.\n\n"
                    "• We do not sell or trade your personal data.\n\n"
                    "• Aggregated anonymous data may be used for research "
                    "and platform improvement.",
              ),

              SizedBox(height: 28),

              /// SECTION 9
              SectionTitle(title: "9. Companion (Caregiver) Access"),

              SectionText(
                text:
                    "The Companion feature allows you to invite one trusted "
                    "person to view selected parts of your health data.\n\n"
                    "You can choose to share:\n"
                    "• Mood Journal\n"
                    "• To-Do List\n"
                    "• Health Tracking\n"
                    "• Doctor Appointments\n\n"
                    "Companions have read-only access and cannot modify "
                    "your data.",
              ),

              SizedBox(height: 28),

              /// SECTION 10
              SectionTitle(title: "10. AI Chatbot"),

              SectionText(
                text:
                    "• The chatbot is powered by Google Gemini and a "
                    "cancer-specific knowledge base.\n\n"
                    "• Responses may occasionally contain inaccuracies.\n\n"
                    "• The chatbot is for emotional support and general "
                    "information only.\n\n"
                    "• Conversations may be summarised into long-term memory "
                    "to personalise future sessions.\n\n"
                    "• You may request deletion of your conversation history "
                    "at any time.",
              ),

              SizedBox(height: 28),

              /// SECTION 11
              SectionTitle(title: "11. Mood Journal & Sentiment Analysis"),

              SectionText(
                text:
                    "• Journal entries are analysed using machine learning "
                    "models.\n\n"
                    "• AI-detected mood may differ from self-reported mood.\n\n"
                    "• Crisis flags may trigger supportive messaging.\n\n"
                    "• This feature does not replace professional "
                    "intervention.",
              ),

              SizedBox(height: 28),

              /// SECTION 12
              SectionTitle(title: "12. Doctor Consultations"),

              SectionText(
                text:
                    "• Video consultations are conducted via Zoom.\n\n"
                    "• Appointment records and uploaded documents are stored securely.\n\n"
                    "• Doctors are independent licensed professionals.\n\n"
                    "• Ayu is not responsible for medical advice or "
                    "treatment decisions made by doctors.\n\n"
                    "• Consultation sessions are not automatically recorded.",
              ),

              SizedBox(height: 28),

              /// SECTION 13
              SectionTitle(title: "13. Video Recommendations"),

              SectionText(
                text:
                    "• Video content is sourced from YouTube.\n\n"
                    "• Recommendations are based on mood trends and interests.\n\n"
                    "• Content is intended for general wellbeing purposes.\n\n"
                    "• Ayu does not guarantee the accuracy or availability "
                    "of recommended content.",
              ),

              SizedBox(height: 28),

              /// SECTION 14
              SectionTitle(title: "14. Acceptable Use"),

              SectionText(
                text:
                    "You agree NOT to:\n\n"
                    "• Use the App unlawfully\n"
                    "• Provide false health information\n"
                    "• Attempt unauthorized access to systems\n"
                    "• Reverse engineer or tamper with the App\n"
                    "• Use bots or automated scripts\n"
                    "• Upload harmful or abusive content\n"
                    "• Impersonate another person or medical professional",
              ),

              SizedBox(height: 28),

              /// SECTION 15
              SectionTitle(title: "15. Intellectual Property"),

              SectionText(
                text:
                    "• All content and branding belong to the Ayu development team.\n\n"
                    "• You are granted a limited personal license to use the App.\n\n"
                    "• You may not reproduce or distribute any part of the App "
                    "without written permission.",
              ),

              SizedBox(height: 28),

              /// SECTION 16
              SectionTitle(title: "16. Account Termination"),

              SectionText(
                text:
                    "• We may suspend or terminate accounts that violate these Terms.\n\n"
                    "• You may delete your account at any time.\n\n"
                    "Upon deletion:\n"
                    "• Personal data will be removed from active systems\n"
                    "• Companion access will be revoked\n"
                    "• Anonymous aggregated data may be retained",
              ),

              SizedBox(height: 28),

              /// SECTION 17
              SectionTitle(title: "17. Limitation of Liability"),

              SectionText(
                text:
                    "• Ayu is not liable for indirect or consequential damages.\n\n"
                    "• We are not responsible for decisions made using "
                    "AI-generated content.\n\n"
                    "• We are not liable for the advice of doctors using "
                    "the platform.\n\n"
                    "• We do not guarantee uninterrupted App operation.",
              ),

              SizedBox(height: 28),

              /// SECTION 18
              SectionTitle(title: "18. Changes to These Terms"),

              SectionText(
                text:
                    "• We may update these Terms periodically.\n\n"
                    "• Significant changes will be communicated through the "
                    "App or email.\n\n"
                    "• Continued use of the App means acceptance of updated Terms.",
              ),

              SizedBox(height: 28),

              /// SECTION 19
              SectionTitle(title: "19. Governing Law"),

              SectionText(
                text:
                    "These Terms are governed by the laws of the "
                    "Democratic Socialist Republic of Sri Lanka.\n\n"
                    "Any disputes shall be subject to the jurisdiction "
                    "of the courts of Sri Lanka.",
              ),

              SizedBox(height: 28),

              /// SECTION 20
              SectionTitle(title: "20. Contact"),

              SectionText(
                text:
                    "If you have questions, concerns, or data deletion requests:\n\n"
                    "Email: support@ayuhealth.lk\n\n"
                    "By using the Ayu app, you acknowledge that you have "
                    "read, understood, and agreed to these Terms and Conditions.",
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


