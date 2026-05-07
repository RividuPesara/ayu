import {
  Auth,
  PhoneAuthProvider,
  PhoneMultiFactorGenerator,
  RecaptchaVerifier,
  User,
  multiFactor,
} from "firebase/auth";

const SRI_LANKAN_MOBILE_REGEX = /^07\d{8}$/;

export function normalizeSriLankanPhone(value: string): string {
  const digits = value.replace(/\D/g, "");
  if (digits.startsWith("94") && digits.length === 11) return `0${digits.slice(2)}`;
  if (digits.startsWith("7") && digits.length === 9) return `0${digits}`;
  if (digits.startsWith("0") && digits.length === 10) return digits;
  return digits;
}

export function toSriLankanE164(localPhone: string): string {
  const normalized = normalizeSriLankanPhone(localPhone);
  if (!SRI_LANKAN_MOBILE_REGEX.test(normalized)) {
    throw new Error("Phone must be a valid Sri Lankan mobile number (e.g. 0775455266).");
  }
  return `+94${normalized.slice(1)}`;
}

export async function sendPhoneEnrollmentOtp(
  auth: Auth,
  user: User,
  localPhone: string,
  recaptchaVerifier: RecaptchaVerifier,
): Promise<string> {
  const phoneNumber = toSriLankanE164(localPhone);
  const multiFactorSession = await multiFactor(user).getSession();
  const phoneAuthProvider = new PhoneAuthProvider(auth);
  return phoneAuthProvider.verifyPhoneNumber(
    { phoneNumber, session: multiFactorSession },
    recaptchaVerifier,
  );
}

export async function verifyAndEnrollPhoneFactor(
  user: User,
  verificationId: string,
  verificationCode: string,
  displayName: string,
): Promise<void> {
  const code = verificationCode.trim();
  if (!/^\d{6}$/.test(code)) {
    throw new Error("Please enter a valid 6-digit verification code.");
  }

  const credential = PhoneAuthProvider.credential(verificationId, code);
  const assertion = PhoneMultiFactorGenerator.assertion(credential);
  const userMultiFactor = multiFactor(user);

  const existingPhoneFactorIds = userMultiFactor.enrolledFactors
    .filter((f) => f.factorId === PhoneMultiFactorGenerator.FACTOR_ID)
    .map((f) => f.uid);

  await userMultiFactor.enroll(assertion, displayName);

  for (const id of existingPhoneFactorIds) {
    await userMultiFactor.unenroll(id);
  }

  await user.getIdToken(true);
}
