"use client";

import { useEffect, useMemo, useRef, useState } from "react";
import { useRouter } from "next/navigation";
import "../../styles/LoginPage.css";
import { auth, db } from "../lib/firebase";
import {
  MultiFactorError,
  MultiFactorInfo,
  MultiFactorResolver,
  PhoneAuthProvider,
  PhoneMultiFactorGenerator,
  RecaptchaVerifier,
  getMultiFactorResolver,
  sendEmailVerification,
  signOut,
} from "firebase/auth";
import { doc, getDoc } from "firebase/firestore";
import { loginWithEmail, sendResetEmail, verifyAdmin } from "../lib/loginService";
import { sendPhoneEnrollmentOtp, verifyAndEnrollPhoneFactor } from "../lib/phone-mfa";
import {
  canAttemptLogin,
  createLoginCooldownKey,
  getLoginCooldownRemainingMs,
  getPersistedLoginCooldownIdentifier,
  registerFailedLoginAttempt,
  registerSuccessfulLoginAttempt,
  setPersistedLoginCooldownIdentifier,
} from "../lib/login-cooldown";

type OtpFlowType = "sign-in-mfa" | "login-phone-verification";

export default function LoginPage() {
  const router = useRouter();
  const recaptchaVerifierRef = useRef<RecaptchaVerifier | null>(null);

  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [showPassword, setShowPassword] = useState(false);

  const [isLoading, setIsLoading] = useState(false);
  const [cooldownRemainingMs, setCooldownRemainingMs] = useState(0);
  const [persistedLoginIdentifier, setPersistedLoginIdentifier] = useState<string | null>(null);

  const [forgotMode, setForgotMode] = useState(false);
  const [forgotEmail, setForgotEmail] = useState("");
  const [forgotSent, setForgotSent] = useState(false);

  const [otpMode, setOtpMode] = useState(false);
  const [otp, setOtp] = useState("");
  const [otpDestination, setOtpDestination] = useState("");
  const [verificationId, setVerificationId] = useState("");
  const [otpFlowType, setOtpFlowType] = useState<OtpFlowType | null>(null);
  const [mfaResolver, setMfaResolver] = useState<MultiFactorResolver | null>(null);

  const [emailError, setEmailError] = useState("");
  const [passwordError, setPasswordError] = useState("");
  const [otpError, setOtpError] = useState("");
  const [forgotEmailError, setForgotEmailError] = useState("");

  const loginIdentifier = useMemo(
    () => email.trim() || persistedLoginIdentifier || "anonymous",
    [email, persistedLoginIdentifier],
  );

  const loginCooldownKey = useMemo(
    () => createLoginCooldownKey("admin-email-password", loginIdentifier),
    [loginIdentifier],
  );

  const cooldownRemainingSeconds = Math.ceil(cooldownRemainingMs / 1000);

  useEffect(() => {
    return () => {
      try { recaptchaVerifierRef.current?.clear(); } catch { /* ignore teardown races */ }
      recaptchaVerifierRef.current = null;
    };
  }, []);

  useEffect(() => {
    const storedIdentifier = getPersistedLoginCooldownIdentifier("admin-email-password");
    if (storedIdentifier) {
      setPersistedLoginIdentifier(storedIdentifier);
    }
  }, []);

  useEffect(() => {
    setCooldownRemainingMs(getLoginCooldownRemainingMs(loginCooldownKey));
  }, [loginCooldownKey]);

  useEffect(() => {
    if (cooldownRemainingMs <= 0) return;

    const intervalId = window.setInterval(() => {
      const remainingMs = getLoginCooldownRemainingMs(loginCooldownKey);
      setCooldownRemainingMs(remainingMs);
      if (remainingMs <= 0) window.clearInterval(intervalId);
    }, 1000);

    return () => window.clearInterval(intervalId);
  }, [cooldownRemainingMs, loginCooldownKey]);

  function getOrCreateRecaptchaVerifier(): RecaptchaVerifier {
    if (recaptchaVerifierRef.current) return recaptchaVerifierRef.current;
    const verifier = new RecaptchaVerifier(auth, "admin-login-recaptcha", { size: "invisible" });
    recaptchaVerifierRef.current = verifier;
    return verifier;
  }

  function resetOtpState() {
    setOtpMode(false);
    setOtp("");
    setVerificationId("");
    setOtpDestination("");
    setOtpError("");
    setOtpFlowType(null);
    setMfaResolver(null);
  }

  // LOGIN
  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault();

    let hasError = false;

    if (!email.trim()) {
      setEmailError("Please enter the email");
      hasError = true;
    } else {
      setEmailError("");
    }

    if (!password.trim()) {
      setPasswordError("Please enter the password");
      hasError = true;
    } else {
      setPasswordError("");
    }

    if (hasError) return;

    const availability = canAttemptLogin(loginCooldownKey);
    if (!availability.allowed) {
      setCooldownRemainingMs(availability.remainingMs);
      alert(`Too many failed attempts. Try again in ${Math.ceil(availability.remainingMs / 1000)} seconds.`);
      return;
    }

    setIsLoading(true);

    try {
      const userCredential = await loginWithEmail(email, password);

      // Check if email is verified
      if (!userCredential.user.emailVerified) {
        try {
          await sendEmailVerification(userCredential.user);
        } catch (emailError: unknown) {
          console.error("Email verification error:", emailError);
        }

        await signOut(auth);
        alert("Please verify your email first. We sent a verification link to your email.");
        return;
      }

      const uid = userCredential.user.uid;

      await verifyAdmin(uid);

      registerSuccessfulLoginAttempt(loginCooldownKey);
      setCooldownRemainingMs(0);

      const userSnap = await getDoc(doc(db, "users", uid));
      const loginPhone = (userSnap.data()?.phone || "").trim();
      if (!loginPhone) {
        await signOut(auth);
        alert("No phone number found in your profile. Please contact admin to set your phone number.");
        return;
      }

      const recaptchaVerifier = getOrCreateRecaptchaVerifier();
      const nextVerificationId = await sendPhoneEnrollmentOtp(
        auth,
        userCredential.user,
        loginPhone,
        recaptchaVerifier,
      );

      setVerificationId(nextVerificationId);
      setOtpFlowType("login-phone-verification");
      setOtpDestination(`*******${loginPhone.slice(-3)}`);
      setOtp("");
      setOtpMode(true);
    } catch (error: unknown) {
      const code = (error as { code?: string })?.code;

      if (code === "auth/multi-factor-auth-required") {
        registerSuccessfulLoginAttempt(loginCooldownKey);
        setCooldownRemainingMs(0);
        try {
          const resolver = getMultiFactorResolver(auth, error as MultiFactorError);
          const phoneHint = resolver.hints.find(
            (h: MultiFactorInfo) => h.factorId === PhoneMultiFactorGenerator.FACTOR_ID,
          );
          if (!phoneHint) {
            alert("No phone-based second factor is available for this account.");
            return;
          }

          const recaptchaVerifier = getOrCreateRecaptchaVerifier();
          const phoneAuthProvider = new PhoneAuthProvider(auth);
          const nextVerificationId = await phoneAuthProvider.verifyPhoneNumber(
            { multiFactorHint: phoneHint, session: resolver.session },
            recaptchaVerifier,
          );

          setVerificationId(nextVerificationId);
          setMfaResolver(resolver);
          setOtpFlowType("sign-in-mfa");
          setOtpDestination(
            "phoneNumber" in phoneHint
              ? (phoneHint as { phoneNumber?: string }).phoneNumber ?? "your phone"
              : "your phone",
          );
          setOtp("");
          setOtpMode(true);
        } catch {
          setEmailError("Invalid email");
          setPasswordError("Invalid password");
        }
        return;
      }

      if (code && code.startsWith("auth/")) {
        setPersistedLoginCooldownIdentifier("admin-email-password", email.trim() || loginIdentifier);
        const failedAttemptState = registerFailedLoginAttempt(loginCooldownKey);
        if (failedAttemptState.isCoolingDown) {
          setCooldownRemainingMs(failedAttemptState.remainingMs);
          alert(`Too many failed attempts. Try again in ${Math.ceil(failedAttemptState.remainingMs / 1000)} seconds.`);
          return;
        }
      }

      setEmailError("Invalid email");
      setPasswordError("Invalid password");
    } finally {
      setIsLoading(false);
    }
  };

  // Reset Password
  const handleForgot = async (e: React.FormEvent) => {
    e.preventDefault();

    if (!forgotEmail.trim()) {
      setForgotEmailError("Please enter the email");
      return;
    } else {
      setForgotEmailError("");
    }

    setIsLoading(true);

    try {
      await sendResetEmail(forgotEmail);
      setForgotSent(true);
    } catch (error: any) {
      setForgotEmailError("Invalid email");
    }

    setIsLoading(false);
  };

  // OTP Verification
  const handleVerifyOtp = async (e: React.FormEvent) => {
    e.preventDefault();

    if (otp.trim().length === 0) {
      setOtpError("Please enter the OTP");
      return;
    }

    const trimmedOtp = otp.trim();
    if (!/^\d{6}$/.test(trimmedOtp)) {
      setOtpError("Please enter a valid 6-digit OTP code.");
      return;
    }

    if (!verificationId || !otpFlowType) {
      alert("Verification session expired. Please log in again.");
      resetOtpState();
      return;
    }

    setIsLoading(true);

    try {
      if (otpFlowType === "sign-in-mfa") {
        if (!mfaResolver) {
          alert("Verification session expired. Please log in again.");
          resetOtpState();
          return;
        }
        const credential = PhoneAuthProvider.credential(verificationId, trimmedOtp);
        const assertion = PhoneMultiFactorGenerator.assertion(credential);
        await mfaResolver.resolveSignIn(assertion);
      } else {
        const currentUser = auth.currentUser;
        if (!currentUser) {
          alert("User not found. Please log in again.");
          resetOtpState();
          return;
        }
        await verifyAndEnrollPhoneFactor(currentUser, verificationId, trimmedOtp, "Login phone");
      }

      const uid = auth.currentUser?.uid;
      if (!uid) {
        alert("User not found. Please log in again.");
        resetOtpState();
        return;
      }
      router.push(`/user/${uid}`);
    } catch (error: any) {
      let seconds = 4;

      setOtpError(`Invalid OTP. Please re-enter in ${seconds}s`);

      const countdown = setInterval(() => {
        seconds--;

        if (seconds > 0) {
          setOtpError(`Invalid OTP. Please re-enter in ${seconds}s`);
        } else {
          clearInterval(countdown);
          setOtp("");
          setOtpError("");
        }
      }, 1000);
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="page">
      <div className="login-panel">
        <div className="card">

          {otpMode ? (
            <>
              <button
                className="back-btn"
                onClick={resetOtpState}
              >
                ← Back to Login
              </button>

              <div className="card-header">

                <div className="card-logo">
                  <img src="/assets/logo.png" alt="AYU Logo" />
                </div>

                <div className="card-title">Enter OTP</div>
                <div className="card-sub">
                  We sent a 6-digit code to {otpDestination || "your phone"}
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
                        if (otpError) setOtpError("");

                        if (e.target.value && e.target.nextSibling) {
                          (e.target.nextSibling as HTMLInputElement).focus();
                        }
                      }}
                    />
                  ))}
                </div>
                {otpError && <span className="error-msg">{otpError}</span>}

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
                    className={`input ${emailError ? "input-error" : ""}`}
                    type="email"
                    placeholder="you@gmail.com"
                    value={email}
                    onChange={(e) => {
                      setEmail(e.target.value);
                      if (emailError) setEmailError("");
                    }}
                  />
                  {emailError && <span className="error-msg">{emailError}</span>}
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

                  <div className={`input-wrap ${passwordError ? "input-error" : ""}`}>
                    <input
                      className="input"
                      type={showPassword ? "text" : "password"}
                      placeholder="••••••••"
                      value={password}
                      onChange={(e) => {
                        setPassword(e.target.value);
                        if (passwordError) setPasswordError("");
                      }}
                    />

                    <button
                      type="button"
                      className="eye-btn"
                      onClick={() => setShowPassword(!showPassword)}
                    >
                      👁
                    </button>
                  </div>
                  {passwordError && <span className="error-msg">{passwordError}</span>}
                </div>

                <button className="btn-primary" disabled={isLoading || cooldownRemainingMs > 0}>
                  {isLoading
                    ? "Signing in..."
                    : cooldownRemainingMs > 0
                    ? `Try again in ${cooldownRemainingSeconds}s`
                    : "Sign In"}
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
                  setForgotEmailError("");
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
                    className={`input ${forgotEmailError ? "input-error" : ""}`}
                    type="email"
                    placeholder="you@gmail.com"
                    value={forgotEmail}
                    onChange={(e) => {
                      setForgotEmail(e.target.value)
                      if (forgotEmailError) setForgotEmailError("");
                    }}
                  />
                  {forgotEmailError && <span className="error-msg">{forgotEmailError}</span>}
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

      {/* invisible recaptcha anchor required by Firebase Phone MFA */}
      <div id="admin-login-recaptcha" style={{ display: "none" }} />
    </div>
  );
}
