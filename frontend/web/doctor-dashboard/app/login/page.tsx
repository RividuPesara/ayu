"use client";

import { useEffect, useMemo, useRef, useState } from "react";
import { useRouter } from "next/navigation";
import "./LoginPage.css";
import { auth } from "../lib/firebase";
import {
  MultiFactorInfo,
  MultiFactorError,
  MultiFactorResolver,
  PhoneAuthProvider,
  PhoneMultiFactorGenerator,
  RecaptchaVerifier,
  getMultiFactorResolver,
  sendEmailVerification,
  signInWithEmailAndPassword,
  signOut,
  sendPasswordResetEmail,
} from "firebase/auth";
import { backendRequest } from "@/app/lib/backend-api";
import {
  sendPhoneEnrollmentOtp,
  verifyAndEnrollPhoneFactor,
} from "@/app/lib/phone-mfa";
import {
  canAttemptLogin,
  createLoginCooldownKey,
  getLoginCooldownRemainingMs,
  getPersistedLoginCooldownIdentifier,
  registerFailedLoginAttempt,
  registerSuccessfulLoginAttempt,
  setPersistedLoginCooldownIdentifier,
} from "@/app/lib/login-cooldown";

const DASHBOARD_REDIRECT_DELAY_MS = 450;

function getErrorMessage(error: unknown): string {
  if (typeof error === "object" && error !== null) {
    const maybeCode = (error as { code?: unknown }).code;
    if (maybeCode === "auth/operation-not-allowed") {
      return "SMS OTP is blocked by Firebase settings. Enable Phone provider, enable SMS MFA, and allow Sri Lanka (+94) in Authentication -> Settings -> SMS region policy for this same project.";
    }
  }

  if (error instanceof Error) {
    return error.message;
  }

  return "Something went wrong. Please try again.";
}

function hasErrorCode(error: unknown, expectedCode: string): boolean {
  if (typeof error !== "object" || error === null) {
    return false;
  }

  const maybeCode = (error as { code?: unknown }).code;
  return typeof maybeCode === "string" && maybeCode === expectedCode;
}

function readErrorCode(error: unknown): string | null {
  if (typeof error !== "object" || error === null) {
    return null;
  }

  const maybeCode = (error as { code?: unknown }).code;
  return typeof maybeCode === "string" ? maybeCode : null;
}

function readMaskedPhone(hint: MultiFactorInfo): string {
  if ("phoneNumber" in hint && typeof hint.phoneNumber === "string") {
    return hint.phoneNumber;
  }

  return "your phone";
}

function maskLocalPhone(phone: string): string {
  const digits = phone.replace(/\D/g, "");
  if (digits.length < 4) {
    return "your phone";
  }

  return `*******${digits.slice(-3)}`;
}

type OtpFlowType = "sign-in-mfa" | "login-phone-verification";

export default function LoginPage() {
  const router = useRouter();
  const recaptchaVerifierRef = useRef<RecaptchaVerifier | null>(null);

  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [showPassword, setShowPassword] = useState(false);

  const [isLoading, setIsLoading] = useState(false);
  const [cooldownRemainingMs, setCooldownRemainingMs] = useState(0);
  // Store the last login identifier from a failed attempt so a page refresh doesn't make the browser forget the active cooldown.
  const [persistedLoginIdentifier, setPersistedLoginIdentifier] = useState<string | null>(null);

  const [forgotMode, setForgotMode] = useState(false);
  const [forgotEmail, setForgotEmail] = useState("");
  const [forgotSent, setForgotSent] = useState(false);

  const [otpMode, setOtpMode] = useState(false);
  const [otp, setOtp] = useState("");
  const [otpDestination, setOtpDestination] = useState("your phone");
  const [mfaResolver, setMfaResolver] = useState<MultiFactorResolver | null>(null);
  const [verificationId, setVerificationId] = useState("");
  const [otpFlowType, setOtpFlowType] = useState<OtpFlowType | null>(null);

  const loginIdentifier = useMemo(
    () => email.trim() || persistedLoginIdentifier || "anonymous",
    [email, persistedLoginIdentifier],
  );

  const loginCooldownKey = useMemo(
    () => createLoginCooldownKey("email-password", loginIdentifier),
    [loginIdentifier],
  );

  const cooldownRemainingSeconds = Math.ceil(cooldownRemainingMs / 1000);

  useEffect(() => {
    return () => {
      try {
        recaptchaVerifierRef.current?.clear();
      } catch {
        // Ignore recaptcha teardown race conditions on unmount.
      }
      recaptchaVerifierRef.current = null;
    };
  }, []);

  useEffect(() => {
    // When the page loads, restore the last identifier used for login cooldown. this helps keep the same cooldown active after a browser refresh
    const storedIdentifier = getPersistedLoginCooldownIdentifier("email-password");
    if (storedIdentifier) {
      setPersistedLoginIdentifier(storedIdentifier);
    }
  }, []);

  useEffect(() => {
    setCooldownRemainingMs(getLoginCooldownRemainingMs(loginCooldownKey));
  }, [loginCooldownKey]);

  useEffect(() => {
    if (cooldownRemainingMs <= 0) {
      return;
    }

    const intervalId = window.setInterval(() => {
      const remainingMs = getLoginCooldownRemainingMs(loginCooldownKey);
      setCooldownRemainingMs(remainingMs);
      if (remainingMs <= 0) {
        window.clearInterval(intervalId);
      }
    }, 1000);

    return () => window.clearInterval(intervalId);
  }, [cooldownRemainingMs, loginCooldownKey]);

  function getOrCreateRecaptchaVerifier(): RecaptchaVerifier {
    if (recaptchaVerifierRef.current) {
      return recaptchaVerifierRef.current;
    }

    const verifier = new RecaptchaVerifier(auth, "doctor-login-recaptcha", {
      size: "invisible",
    });

    recaptchaVerifierRef.current = verifier;
    return verifier;
  }

  async function verifyDoctorRoleAndRedirect(): Promise<void> {
    await new Promise((resolve) => setTimeout(resolve, DASHBOARD_REDIRECT_DELAY_MS));
    router.replace("/dashboard");
  }

  function resetOtpState(): void {
    setOtpMode(false);
    setOtp("");
    setVerificationId("");
    setMfaResolver(null);
    setOtpFlowType(null);
    setOtpDestination("your phone");
  }

  // LOGIN
  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault();

    const availability = canAttemptLogin(loginCooldownKey);
    if (!availability.allowed) {
      setCooldownRemainingMs(availability.remainingMs);
      alert(
        `Too many failed attempts. Try again in ${Math.ceil(availability.remainingMs / 1000)} seconds.`,
      );
      return;
    }

    setIsLoading(true);

    try {
      const userCredential = await signInWithEmailAndPassword(auth, email, password);
      registerSuccessfulLoginAttempt(loginCooldownKey);
      setCooldownRemainingMs(0);

      if (!userCredential.user.emailVerified) {
        await sendEmailVerification(userCredential.user);
        await signOut(auth);
        alert("Please verify your email first. We sent a verification link to your email.");
        return;
      }

      const [authStatus, profile] = await Promise.all([
        backendRequest<{ uid: string; role: string }>("/api/auth/me"),
        backendRequest<{ phone?: string | null }>("/api/doctor/profile"),
      ]);

      if (authStatus.role !== "doctor") {
        await signOut(auth);
        alert("Access denied: you are not a doctor.");
        return;
      }

      const loginPhone = (profile.phone || "").trim();
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
      setMfaResolver(null);
      setOtpFlowType("login-phone-verification");
      setOtpDestination(maskLocalPhone(loginPhone));
      setOtp("");
      setOtpMode(true);
      return;
    } catch (error: unknown) {
      if (hasErrorCode(error, "auth/multi-factor-auth-required")) {
        registerSuccessfulLoginAttempt(loginCooldownKey);
        setCooldownRemainingMs(0);
        try {
          const resolver = getMultiFactorResolver(auth, error as MultiFactorError);
          const phoneHint = resolver.hints.find(
            (hint: MultiFactorInfo) => hint.factorId === PhoneMultiFactorGenerator.FACTOR_ID,
          );

          if (!phoneHint) {
            alert("No phone-based second factor is available for this account.");
            return;
          }

          const recaptchaVerifier = getOrCreateRecaptchaVerifier();
          const phoneInfoOptions = {
            multiFactorHint: phoneHint,
            session: resolver.session,
          };

          const phoneAuthProvider = new PhoneAuthProvider(auth);
          const nextVerificationId = await phoneAuthProvider.verifyPhoneNumber(
            phoneInfoOptions,
            recaptchaVerifier,
          );

          setVerificationId(nextVerificationId);
          setMfaResolver(resolver);
          setOtpFlowType("sign-in-mfa");
          setOtpDestination(readMaskedPhone(phoneHint));
          setOtp("");
          setOtpMode(true);
          return;
        } catch (mfaError: unknown) {
          alert(getErrorMessage(mfaError));
          return;
        }
      }

      const errorCode = readErrorCode(error);
      if (errorCode && errorCode.startsWith("auth/")) {
        // Remember this identifier so the same browser session still sees the cooldown even after a refresh is done
        setPersistedLoginCooldownIdentifier("email-password", email.trim() || loginIdentifier);
        const failedAttemptState = registerFailedLoginAttempt(loginCooldownKey);
        if (failedAttemptState.isCoolingDown) {
          setCooldownRemainingMs(failedAttemptState.remainingMs);
          alert(
            `Too many failed attempts. Try again in ${Math.ceil(failedAttemptState.remainingMs / 1000)} seconds.`,
          );
          return;
        }
      }

      alert(getErrorMessage(error));
    } finally {
      setIsLoading(false);
    }
  };

  // Reset Password
  const handleForgot = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsLoading(true);

    try {
      await sendPasswordResetEmail(auth, forgotEmail);
      setForgotSent(true);
    } catch (error: unknown) {
      alert(getErrorMessage(error));
    }

    setIsLoading(false);
  };

  // OTP Verification  
  const handleVerifyOtp = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsLoading(true);

    try {
      if (!verificationId || !otpFlowType) {
        alert("Verification session expired. Please log in again.");
        resetOtpState();
        return;
      }

      const trimmedOtp = otp.trim();
      if (!/^\d{6}$/.test(trimmedOtp)) {
        alert("Please enter a valid 6-digit OTP code.");
        return;
      }

      if (otpFlowType === "sign-in-mfa") {
        if (!mfaResolver) {
          alert("Verification session expired. Please log in again.");
          resetOtpState();
          return;
        }

        const credential = PhoneAuthProvider.credential(verificationId, trimmedOtp);
        const multiFactorAssertion = PhoneMultiFactorGenerator.assertion(credential);
        await mfaResolver.resolveSignIn(multiFactorAssertion);
      } else {
        const currentUser = auth.currentUser;
        if (!currentUser) {
          alert("Session expired. Please log in again.");
          resetOtpState();
          return;
        }

        await verifyAndEnrollPhoneFactor(
          currentUser,
          verificationId,
          trimmedOtp,
          "Login phone",
        );
      }

      resetOtpState();

      await verifyDoctorRoleAndRedirect();
      return;
    } catch (error: unknown) {
      alert(getErrorMessage(error));
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
                onClick={() => {
                  resetOtpState();
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
                  We sent a 6-digit code to {otpDestination}
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

      <div id="doctor-login-recaptcha" style={{ display: "none" }} />
    </div>
  );
}