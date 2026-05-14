import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:mobile_app/Connect%20Doctor/appointment_service.dart';
import 'package:mobile_app/Connect Doctor/mySessions.dart';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({
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
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  String selectedMethod = "visa";
  bool _isSubmitting = false;
  final AppointmentService _appointmentService = AppointmentService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F1EF),
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF4B3425).withOpacity(0.8),
                  ),
                ),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: const Icon(
                    Icons.arrow_back_ios_new,
                    size: 16,
                    color: Color(0xFF4B3425),
                  ),
                  onPressed: () {
                    if (Navigator.canPop(context)) {
                      Navigator.pop(context);
                    }
                  },
                ),
              ),

              const SizedBox(height: 25),

              const Text(
                'Check Out',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF4B3425),
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

              const SizedBox(height: 35),

              const Text(
                "Select Payment Method",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 15),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  paymentOption("visa", "assets/visa.svg", size: 60),
                  paymentOption(
                    "mastercard",
                    "assets/mastercard.svg",
                    size: 60,
                  ),
                  paymentOption("amex", "assets/amex.svg", size: 60),
                ],
              ),

              const SizedBox(height: 35),

              const Text("Cardholder name", style: TextStyle(fontSize: 14)),
              const SizedBox(height: 5),
              inputField(
                hint: "Jannet Klein",
                keyboardType: TextInputType.text,
              ),

              const SizedBox(height: 15),

              const Text("Card number", style: TextStyle(fontSize: 14)),
              const SizedBox(height: 5),
              inputField(
                hint: "7236 xxxx xxxx 2345",
                keyboardType: TextInputType.number,
              ),

              const SizedBox(height: 15),

              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Exp. Date", style: TextStyle(fontSize: 14)),
                        const SizedBox(height: 5),
                        inputField(
                          hint: "MM/YY",
                          keyboardType: TextInputType.number,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("CVV", style: TextStyle(fontSize: 14)),
                        const SizedBox(height: 5),
                        inputField(
                          hint: "123",
                          keyboardType: TextInputType.number,
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 40),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting
                      ? null
                      : () async {
                          setState(() {
                            _isSubmitting = true;
                          });

                          try {
                            await _appointmentService.bookAppointment(
                              BookAppointmentRequest(
                                dateKey: widget.dateKey,
                                time: widget.timeValue,
                                doctorUid: widget.doctorUid,
                                doctorName: widget.doctorName,
                                doctorSpecialty: widget.doctorSpecialty,
                              ),
                            );

                            if (!mounted) return;
                            int _popCount = 0;
                            Navigator.of(context).popUntil(
                              (_) => _popCount++ == 3,
                            );
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const MyAppointmentScreen(),
                              ),
                            );
                          } catch (error) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(error.toString())),
                            );
                          } finally {
                            if (!mounted) return;
                            setState(() {
                              _isSubmitting = false;
                            });
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    backgroundColor: const Color(0xFF4B3425),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: const Text(
                    "Pay",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget inputField({
    required String hint,
    required TextInputType keyboardType,
  }) {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        borderRadius: BorderRadius.circular(10),
      ),
      child: TextField(
        keyboardType: keyboardType,
        decoration: InputDecoration(
          hintText: hint,
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget paymentOption(String method, String imagePath, {double size = 30}) {
    final isSelected = selectedMethod == method;

    return GestureDetector(
      onTap: () {
        setState(() {
          selectedMethod = method;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.black.withOpacity(0.05)
              : Colors.transparent,
          border: Border.all(
            color: isSelected ? Colors.black : Colors.grey.shade300,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: SizedBox(
          width: size,
          height: size,
          child: SvgPicture.asset(imagePath, fit: BoxFit.contain),
        ),
      ),
    );
  }
}
