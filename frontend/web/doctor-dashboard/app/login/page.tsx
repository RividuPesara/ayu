"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { doc, getDoc } from "firebase/firestore";
import "./LoginPage.css";
import { auth, db } from "../lib/firebase";
import {
  signInWithEmailAndPassword,
  sendPasswordResetEmail,
} from "firebase/auth";

export default function LoginPage() {
  const router = useRouter();

  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [showPassword, setShowPassword] = useState(false);

  const [isLoading, setIsLoading] = useState(false);

  const [forgotMode, setForgotMode] = useState(false);
  const [forgotEmail, setForgotEmail] = useState("");
  const [forgotSent, setForgotSent] = useState(false);

  const [otpMode, setOtpMode] = useState(false);
  const [otp, setOtp] = useState("");

  // LOGIN
  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsLoading(true);

    try {
      await signInWithEmailAndPassword(auth, email, password);
      setOtpMode(true);
    } catch (error: any) {
      alert(error.message);
    }

    setIsLoading(false);
  };

  // Reset Password
  const handleForgot = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsLoading(true);

    try {
      await sendPasswordResetEmail(auth, forgotEmail);
      setForgotSent(true);
    } catch (error: any) {
      alert(error.message);
    }

    setIsLoading(false);
  };

  // OTP Verification  
  const handleVerifyOtp = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsLoading(true);

    try {
      if (otp === "123456") {
        const currentUser = auth.currentUser;

        if (currentUser) {
          const userDoc = await getDoc(doc(db, "doctors", currentUser.uid));

          if (userDoc.exists()) {
            const userData = userDoc.data();

            // Check if role is doctor
            if (userData.role === "doctor") {
              router.push(`/user/${currentUser.uid}`);
            } else {
              alert("Access denied: you are not a doctor.");
              setOtpMode(false);
            }
          } else {
            alert("User not found in doctors collection.");
            setOtpMode(false);
          }
        } else {
          alert("User not found. Please log in again.");
          setOtpMode(false);
        }
      } else {
        alert("Invalid OTP");
      }
    } catch (error: any) {
      alert(error.message);
    }

    setIsLoading(false);
  };

  return (
    <div className="page">
      <div className="login-panel">
        <div className="card">

          {otpMode ? (
            <>
              <button
                className="back-btn"
                onClick={() => {
                  setOtpMode(false);
                  setOtp("");
                }}
              >
                ← Back to Login
              </button>

              <div className="card-header">

                <div className="card-logo">
                  <img src="/assets/logo.png" alt="AYU Logo" />
                </div>

                <div className="card-title">Enter OTP</div>
                <div className="card-sub">
                  We sent a 6-digit code to your email
                </div>
              </div>

              <form className="form" onSubmit={handleVerifyOtp}>
                <div className="otp-container">
                  {[...Array(6)].map((_, i) => (
                    <input
                      key={i}
                      type="text"
                      maxLength={1}
                      className="otp-input"
                      value={otp[i] || ""}
                      onChange={(e) => {
                        const newOtp = otp.split("");
                        newOtp[i] = e.target.value.replace(/[^0-9]/g, "");
                        setOtp(newOtp.join(""));

                        if (e.target.value && e.target.nextSibling) {
                          (e.target.nextSibling as HTMLInputElement).focus();
                        }
                      }}
                    />
                  ))}
                </div>

                <button className="btn-primary" disabled={isLoading}>
                  {isLoading ? "Verifying..." : "Verify OTP"}
                </button>
              </form>
            </>
          ) : !forgotMode ? (
            <>
              <div className="card-header">

                {/* LOGO INSIDE CARD */}
                <div className="card-logo">
                  <img src="/assets/logo.png" alt="AYU Logo" />
                </div>

                <div className="card-title">Welcome Back</div>
                <div className="card-sub">
                  Access Your Dashboard to Manage Your Work 
                </div>
              </div>

              <form className="form" onSubmit={handleLogin}>
                <div className="field">
                  <label className="label">Email</label>

                  <input
                    className="input"
                    type="email"
                    placeholder="you@gmail.com"
                    value={email}
                    onChange={(e) => setEmail(e.target.value)}
                    required
                  />
                </div>

                <div className="field">
                  <div className="field-header">
                    <label className="label">Password</label>

                    <button
                      type="button"
                      className="forgot-link"
                      onClick={() => {
                        setForgotMode(true);
                        setForgotSent(false);
                      }}
                    >
                      Forgot password?
                    </button>
                  </div>

                  <div className="input-wrap">
                    <input
                      className="input"
                      type={showPassword ? "text" : "password"}
                      placeholder="••••••••"
                      value={password}
                      onChange={(e) => setPassword(e.target.value)}
                      required
                    />

                    <button
                      type="button"
                      className="eye-btn"
                      onClick={() => setShowPassword(!showPassword)}
                    >
                      👁
                    </button>
                  </div>
                </div>

                <button className="btn-primary" disabled={isLoading}>
                  {isLoading ? "Signing in..." : "Sign In"}
                </button>
              </form>
            </>
          ) : (
            <>
              <button
                className="back-btn"
                onClick={() => {
                  setForgotMode(false);
                  setForgotSent(false);
                }}
              >
                ← Back to Login
              </button>

              <div className="card-header">

                <div className="card-logo">
                  <img src="/assets/logo.png" alt="AYU Logo" />
                </div>

                <div className="card-title">Reset Password</div>
                <div className="card-sub">
                  Enter your email to receive a reset link.
                </div>
              </div>

              {forgotSent && (
                <div className="success-box">
                  Reset link sent! Check your email.
                </div>
              )}

              <form className="form" onSubmit={handleForgot}>
                <div className="field">
                  <label className="label">Email</label>

                  <input
                    className="input"
                    type="email"
                    placeholder="you@gmail.com"
                    value={forgotEmail}
                    onChange={(e) => setForgotEmail(e.target.value)}
                    required
                  />
                </div>

                <button
                  className="btn-primary"
                  disabled={isLoading || forgotSent}
                >
                  {isLoading
                    ? "Sending..."
                    : forgotSent
                    ? "Link Sent"
                    : "Send Reset Link"}
                </button>
              </form>
            </>
          )}
        </div>
      </div>
    </div>
  );
}