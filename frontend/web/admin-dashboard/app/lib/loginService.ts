import { auth } from "./firebase";
import {
  signInWithEmailAndPassword,
  sendPasswordResetEmail,
} from "firebase/auth";

const BASE_URL = `${process.env.NEXT_PUBLIC_API_URL}/api/login`;

export async function loginWithEmail(email: string, password: string) {
  return signInWithEmailAndPassword(auth, email, password);
}

export async function sendResetEmail(email: string) {
  return sendPasswordResetEmail(auth, email);
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