import 'package:flutter/material.dart';
import 'package:mobile_app/core/localization/app_localizations.dart';

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
        title: Text(
          context.t('legal.termsTitle'),
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
              SectionTitle(title: context.t('terms.s1')),

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
              SectionTitle(title: context.t('terms.s2')),

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
              SectionTitle(title: context.t('terms.s3')),

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
              SectionTitle(title: context.t('terms.s4')),

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
              SectionTitle(title: context.t('terms.s5')),

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
              SectionTitle(title: context.t('terms.s6')),

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
              SectionTitle(title: context.t('terms.s7')),

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
              SectionTitle(title: context.t('terms.s8')),

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
              SectionTitle(title: context.t('terms.s9')),

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
              SectionTitle(title: context.t('terms.s10')),

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
              SectionTitle(title: context.t('terms.s11')),

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
              SectionTitle(title: context.t('terms.s12')),

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
              SectionTitle(title: context.t('terms.s13')),

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
              SectionTitle(title: context.t('terms.s14')),

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
              SectionTitle(title: context.t('terms.s15')),

              SectionText(
                text:
                    "• All content and branding belong to the Ayu development team.\n\n"
                    "• You are granted a limited personal license to use the App.\n\n"
                    "• You may not reproduce or distribute any part of the App "
                    "without written permission.",
              ),

              SizedBox(height: 28),

              /// SECTION 16
              SectionTitle(title: context.t('terms.s16')),

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
              SectionTitle(title: context.t('terms.s17')),

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
              SectionTitle(title: context.t('terms.s18')),

              SectionText(
                text:
                    "• We may update these Terms periodically.\n\n"
                    "• Significant changes will be communicated through the "
                    "App or email.\n\n"
                    "• Continued use of the App means acceptance of updated Terms.",
              ),

              SizedBox(height: 28),

              /// SECTION 19
              SectionTitle(title: context.t('terms.s19')),

              SectionText(
                text:
                    "These Terms are governed by the laws of the "
                    "Democratic Socialist Republic of Sri Lanka.\n\n"
                    "Any disputes shall be subject to the jurisdiction "
                    "of the courts of Sri Lanka.",
              ),

              SizedBox(height: 28),

              /// SECTION 20
              SectionTitle(title: context.t('terms.s20')),

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


