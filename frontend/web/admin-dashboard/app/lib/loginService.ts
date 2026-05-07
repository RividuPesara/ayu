import { auth } from "./firebase";
import {
  signInWithEmailAndPassword,
  sendPasswordResetEmail,
} from "firebase/auth";

const BASE_URL = `http://localhost:8000/api/login`;

export async function loginWithEmail(email: string, password: string) {
  return signInWithEmailAndPassword(auth, email, password);
}

export async function sendResetEmail(email: string) {
  return sendPasswordResetEmail(auth, email);
}

// not used anymore as otp is now handled by phone ma on client side now
export async function sendOtp(email: string, password: string) {
  const res = await fetch(`${BASE_URL}/send-otp`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ email, password }),
  });

  if (!res.ok) {
    const errorText = await res.text();
    throw new Error(errorText || "Failed to send OTP");
  }

  return res.json();
}

export async function verifyOtp(uid: string, verification_id: string, otp_code: string) {
  const res = await fetch(`${BASE_URL}/verify-otp`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ uid, verification_id, otp_code }),
  });

  if (!res.ok) {
    const errorText = await res.text();
    throw new Error(errorText || "OTP verification failed");
  }

  return res.json();
}

export async function verifyAdmin(uid: string) {
  const res = await fetch(`${BASE_URL}/verify-admin`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ uid }),
  });

  if (!res.ok) {
    throw new Error(await res.text());
  }

  return res.json();
}