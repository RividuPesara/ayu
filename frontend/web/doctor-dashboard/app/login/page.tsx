"use client";

import { useState } from "react";
import "./LoginPage.css"; // import CSS for styling
import { auth } from "../lib/firebase"; // import Firebase auth instance
import {
  signInWithEmailAndPassword,
  sendPasswordResetEmail,
} from "firebase/auth";

export default function LoginPage() { // Main component for the login page
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [showPassword, setShowPassword] = useState(false);
  const [isLoading, setIsLoading] = useState(false);
  const [forgotMode, setForgotMode] = useState(false);
  const [forgotEmail, setForgotEmail] = useState("");
  const [forgotSent, setForgotSent] = useState(false);
  const [otpMode, setOtpMode] = useState(false);
  const [otp, setOtp] = useState("");

   // Login handler
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

  // Reset Password handler
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

  const handleVerifyOtp = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsLoading(true);

    try {
        if (otp === "123456") {

        // Redirect after OTP success
        window.location.href = "/dashboard";
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
     {/* LEFT SIDE OF THE SCREEN: Video Panel */}
      <div className="video-panel"> 
        <video 
            autoPlay 
            muted 
            loop 
            playsInline>
          <source src="/assets/login.mp4" type="video/mp4" />
        </video>
      </div>

      {/* RIGHT SIDE OF THE SCREEN: Login Panel */}
      <div className="login-panel">
          <div className="logo-section">
            <div className="logo-mark">
                {/* Logo image */}
                <img src="/assets/logo.png" alt="AYU Logo" className="logo-img" />
            </div>
          </div>
          {/* Card */}
          <div className="card">
            {otpMode ? (
            // OTP UI
            <>
              <button
                className="back-btn"
                onClick={() => {
                  setOtpMode(false);
                  setOtp("");
                }}
              >
                <svg
                  width="16"
                  height="16"
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="currentColor"
                  strokeWidth="2.5"
                  strokeLinecap="round"
                  strokeLinejoin="round"
                >
                  <path d="M19 12H5M12 5l-7 7 7 7" />
                </svg>
                Back to Login
              </button>

              <div className="card-header">
                <div className="card-title">Enter OTP</div>
                <div className="card-sub">We sent a 6-digit code to your email</div>
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

                        // auto focus next
                        if (e.target.value && e.target.nextSibling) {
                          (e.target.nextSibling as HTMLInputElement).focus();
                        }
                      }}
                    />
                  ))}
                </div>

                <button className="btn-primary" type="submit" disabled={isLoading}>
                  {isLoading ? (
                    <>
                      <span className="spinner" /> Verifying…
                    </>
                  ) : (
                    "Verify OTP"
                  )}
                </button>
              </form>
            </>
            ) : !forgotMode ? (
              <>
                <div className="card-header">
                  <div className="card-title">Welcome Back</div>
                  <div className="card-sub">Log in to your clinical workspace</div>
                </div>

                <form className="form" onSubmit={handleLogin}>
                  <div className="field">
                    <label className="label">Email</label>
                    <div className="input-wrap">
                      <svg className="input-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                        <rect width="20" height="16" x="2" y="4" rx="2" />
                        <path d="m22 7-8.97 5.7a1.94 1.94 0 0 1-2.06 0L2 7" />
                      </svg>
                      <input
                        className="input"
                        type="email"
                        placeholder="you@gmail.com"
                        value={email}
                        onChange={(e) => setEmail(e.target.value)}
                        required
                        autoComplete="email"
                      />
                    </div>
                  </div>

                  <div className="field">
                    <div className="field-header">
                      <label className="label">Password</label>
                      <button
                        type="button"
                        className="forgot-link"
                        onClick={() => { setForgotMode(true); setForgotSent(false); }}
                      >
                        Forgot password?
                      </button>
                    </div>
                    <div className="input-wrap">
                      <svg className="input-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                        <rect width="18" height="11" x="3" y="11" rx="2" ry="2" />
                        <path d="M7 11V7a5 5 0 0 1 10 0v4" />
                      </svg>
                      <input
                        className="input"
                        type={showPassword ? "text" : "password"}
                        placeholder="••••••••"
                        value={password}
                        onChange={(e) => setPassword(e.target.value)}
                        required
                        autoComplete="current-password"
                        style={{ paddingRight: "2.8rem" }}
                      />
                      <button
                        type="button"
                        className="eye-btn"
                        onClick={() => setShowPassword(!showPassword)}
                        aria-label="Toggle password visibility"
                      >
                        {showPassword ? (
                          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                            <path d="M17.94 17.94A10.07 10.07 0 0 1 12 20c-7 0-11-8-11-8a18.45 18.45 0 0 1 5.06-5.94M9.9 4.24A9.12 9.12 0 0 1 12 4c7 0 11 8 11 8a18.5 18.5 0 0 1-2.16 3.19m-6.72-1.07a3 3 0 1 1-4.24-4.24" />
                            <line x1="1" y1="1" x2="23" y2="23" />
                          </svg>
                        ) : (
                          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                            <path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z" />
                            <circle cx="12" cy="12" r="3" />
                          </svg>
                        )}
                      </button>
                    </div>
                  </div>

                  <button className="btn-primary" type="submit" disabled={isLoading}>
                    {isLoading ? <><span className="spinner" /> Signing in…</> : "Sign In"}
                  </button>
                </form>
              </>
            ) : (
              <>
                <button className="back-btn" onClick={() => { setForgotMode(false); setForgotSent(false); }}>
                  <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
                    <path d="M19 12H5M12 5l-7 7 7 7" />
                  </svg>
                  Back to Login
                </button>

                <div className="card-header">
                  <div className="card-title">Reset Password</div>
                  <div className="card-sub">Enter your email to receive a reset link.</div>
                </div>

                {forgotSent && (
                  <div className="success-box">
                    <p>✅ Reset link sent! Check your inbox and follow the instructions.</p>
                  </div>
                )}

                <form className="form" onSubmit={handleForgot}>
                  <div className="field">
                    <label className="label">Email</label>
                    <div className="input-wrap">
                      <svg className="input-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                        <rect width="20" height="16" x="2" y="4" rx="2" />
                        <path d="m22 7-8.97 5.7a1.94 1.94 0 0 1-2.06 0L2 7" />
                      </svg>
                      <input
                        className="input"
                        type="email"
                        placeholder="you@gmail.com"
                        value={forgotEmail}
                        onChange={(e) => setForgotEmail(e.target.value)}
                        required
                      />
                    </div>
                  </div>

                  <button className="btn-primary" type="submit" disabled={isLoading || forgotSent}>
                    {isLoading ? <><span className="spinner" /> Sending…</> : forgotSent ? "Link Sent ✓" : "Send Reset Link"}
                  </button>
                </form>
              </>
            )}
          </div>
        </div>
      </div>
  );
}