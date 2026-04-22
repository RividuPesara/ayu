// Ensures the phone number starts with '07' and is exactly 10 digits long
final RegExp _sriLankanMobileRegex = RegExp(r'^07\d{8}$');

// Cleans input and converts various formats into a standard 10-digit local format
String normalizeSriLankanPhone(String value) {
  // Removes all non-digit characters from the string
  final digits = value.replaceAll(RegExp(r'\D'), '');
  // Handles international format starting with 94
  if (digits.startsWith('94') && digits.length == 11) {
    return '0${digits.substring(2)}';
  }

  // Handles short format starting with 7
  if (digits.startsWith('7') && digits.length == 9) {
    return '0$digits';
  }

  // Handles standard local format starting with 0
  if (digits.startsWith('0') && digits.length == 10) {
    return digits;
  }

  return digits;
}

// Validates the number and converts it to the international E.164 format (+94...)
String toSriLankanE164(String localPhone) {
  final normalized = normalizeSriLankanPhone(localPhone);

  // Checks if the cleaned number matches the required Sri Lankan mobile pattern
  if (!_sriLankanMobileRegex.hasMatch(normalized)) {
    throw StateError(
      'Phone must be a valid Sri Lankan mobile number (e.g. 0775455266).',
    );
  }

  // Replaces the leading '0' with the '+94' country code
  return '+94${normalized.substring(1)}';
}

// Hides most of the phone number for privacy, showing only the last 3 digits
String maskLocalPhone(String phone) {
  final digits = phone.replaceAll(RegExp(r'\D'), '');
  // Fallback text if the input is too short to mask properly
  if (digits.length < 4) {
    return 'your phone';
  }

  // Returns a string of stars followed by the last three numbers
  return '*******${digits.substring(digits.length - 3)}';
}
