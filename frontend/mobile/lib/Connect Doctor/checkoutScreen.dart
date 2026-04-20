import 'package:flutter/material.dart';
import 'package:mobile_app/Connect%20Doctor/paymentScreen.dart';

class CheckoutPage extends StatelessWidget {
  const CheckoutPage({
    super.key,
    required this.doctorName,
    required this.doctorSpecialty,
    required this.doctorUid,
    required this.dateKey,
    required this.dateLabel,
    required this.timeValue,
    required this.timeLabel,
  });

  final String doctorName;
  final String doctorSpecialty;
  final String doctorUid;
  final String dateKey;
  final String dateLabel;
  final String timeValue;
  final String timeLabel;

  @override
  Widget build(BuildContext context) {
    const Color bgColor = Color(0xFFF3F1EF);
    const Color brown = Color(0xFF5A3826);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 50),

              // Back button
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Color(0xFF4B3425).withOpacity(0.8),
                    width: 1,
                  ),
                ),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: const Icon(
                    Icons.arrow_back_ios_new,
                    size: 16,
                    color: brown,
                  ),
                  onPressed: () {
                    Navigator.of(context).maybePop();
                  },
                ),
              ),

              const SizedBox(height: 25),

              // Title
              const Text(
                'Check Out',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF4B3425),
                  height: 1,
                ),
              ),

              const SizedBox(height: 18),

              const Text(
                'Please check the details before proceeding to the payment',
                style: TextStyle(
                  fontSize: 18,
                  color: Color(0xFF3F3F3F),
                  height: 1.5,
                  fontWeight: FontWeight.w500,
                ),
              ),

              const SizedBox(height: 22),

              Divider(color: Colors.grey.shade300, thickness: 1),

              const SizedBox(height: 14),

              _DetailRow(label: 'Doctor', value: doctorName, boldValue: true),
              const SizedBox(height: 18),

              _DetailRow(label: 'Speciality', value: doctorSpecialty),
              const SizedBox(height: 18),

              _DetailRow(label: 'Date', value: dateLabel),
              const SizedBox(height: 18),

              _DetailRow(label: 'Time', value: timeLabel),
              const SizedBox(height: 58),

              const Text(
                "Payment Details",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 18),

              const _DetailRow(
                label: 'Doctor Fee',
                value: 'LKR 1000.00',
                boldValue: true,
              ),

              const SizedBox(height: 18),

              const _DetailRow(
                label: 'Booking Fee',
                value: 'LKR 300.00',
                boldValue: true,
              ),

              const SizedBox(height: 9),

              Divider(color: Colors.grey.shade400, thickness: 1.5),

              const SizedBox(height: 8),

              Row(
                children: [
                  const SizedBox(
                    width: 110,
                    child: Text(
                      'Total Fee',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF7A7A7A),
                      ),
                    ),
                  ),
                  const Spacer(),
                  const Text(
                    'LKR 1300.00',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF4A3328),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              Column(
                children: [
                  Divider(color: Colors.grey.shade400, thickness: 1, height: 0),
                  Divider(color: Colors.grey.shade400, thickness: 1),
                ],
              ),

              const Spacer(),

              // Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PaymentScreen(
                          doctorName: doctorName,
                          doctorSpecialty: doctorSpecialty,
                          doctorUid: doctorUid,
                          dateKey: dateKey,
                          dateLabel: dateLabel,
                          timeValue: timeValue,
                          timeLabel: timeLabel,
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF4B3425),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  child: const Text(
                    'Continue to Payment',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 75),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool boldValue;

  const _DetailRow({
    required this.label,
    required this.value,
    this.boldValue = false,
  });

  @override
  Widget build(BuildContext context) {
    const Color textGrey = Color(0xFF7A7A7A);
    const Color darkText = Color(0xFF4B3425);

    return Row(
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 18,
              color: textGrey,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: boldValue ? FontWeight.w700 : FontWeight.w400,
            color: darkText,
          ),
        ),
      ],
    );
  }
}
