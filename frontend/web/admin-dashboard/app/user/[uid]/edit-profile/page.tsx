"use client";

import { useEffect, useRef, useState } from "react";
import { useParams, useRouter } from "next/navigation";
import "../../../../styles/edit-profile.css";
import { getProfile, updateProfile } from "../../../lib/profileService";
import { uploadImage } from "../../../lib/cloudinaryUpload";
import Lottie from "lottie-react";
import successAnimation from "../../../../public/assets/success.json";

const UserIcon = () => (
  <svg viewBox="0 0 24 24" fill="currentColor">
    <path d="M12 12c2.7 0 4.8-2.1 4.8-4.8S14.7 2.4 12 2.4 7.2 4.5 7.2 7.2 9.3 12 12 12zm0 2.4c-3.2 0-9.6 1.6-9.6 4.8v2.4h19.2v-2.4c0-3.2-6.4-4.8-9.6-4.8z"/>
  </svg>
);

export default function EditProfilePage() {
  const router = useRouter();
  const params = useParams();
  const uid = params?.uid as string;

  const fileInputRef = useRef<HTMLInputElement | null>(null);

  const [isLoading, setIsLoading] = useState(true);
  const [isSaving, setIsSaving] = useState(false);
  const [isUploading, setIsUploading] = useState(false);
  const [showSuccessDialog, setShowSuccessDialog] = useState(false);

  const [firstName, setFirstName] = useState("");
  const [lastName, setLastName] = useState("");
  const [email, setEmail] = useState("");
  const [phone, setPhone] = useState("");
  const [avatar, setAvatar] = useState<string | null>(null);

  const [newPassword, setNewPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");

  useEffect(() => {
    if (!uid) return;

    const loadProfile = async () => {
      try {
        setIsLoading(true);
        const data = await getProfile(uid);

        setFirstName(data.firstName || "");
        setLastName(data.lastName || "");
        setEmail(data.email || "");
        setPhone(data.phone || "");
        setAvatar(data.avatar || null);
      } catch (error: any) {
        alert(error.message || "Failed to load profile");
      } finally {
        setIsLoading(false);
      }
    };

    loadProfile();
  }, [uid]);

  const handleFileChange = async (
    e: React.ChangeEvent<HTMLInputElement>
  ) => {
    const file = e.target.files?.[0];
    if (!file) return;

    try {
      setIsUploading(true);

      const imageUrl = await uploadImage(file);

      setAvatar(imageUrl);
    } catch (error: any) {
      alert(error.message || "Image upload failed");
    } finally {
      setIsUploading(false);
    }
  };

  const handleRemovePhoto = () => {
    setAvatar(null);

    if (fileInputRef.current) {
      fileInputRef.current.value = "";
    }
  };

  const handleSave = async () => {
    if (!uid) {
      alert("User ID not found");
      return;
    }

    if (!firstName.trim() || !lastName.trim() || !email.trim()) {
      alert("Please fill in all required fields.");
      return;
    }

    if (newPassword || confirmPassword) {
      if (newPassword !== confirmPassword) {
        alert("Passwords do not match.");
        return;
      }

      if (newPassword.length < 6) {
        alert("Password must be at least 6 characters.");
        return;
      }
    }

    try {
      setIsSaving(true);

      await updateProfile({
        uid,
        firstName,
        lastName,
        email,
        phone: phone || undefined,
        avatar: avatar || "",
        newPassword: newPassword || undefined,
      });

      setShowSuccessDialog(true);

      setNewPassword("");
      setConfirmPassword("");
    } catch (error: any) {
      alert(error.message || "Update failed");
    } finally {
      setIsSaving(false);
    }
  };

  const handleCancel = () => {
    router.back();
  };

  return (
    <div className="edit-profile-page">
      <div className="edit-profile-card">
        <div className="edit-profile-header">
          <h1>Edit Profile</h1>
          <p>Update your personal information below.</p>
        </div>

        <div className="profile-picture-section">
          <div className="profile-picture-wrapper">
            {avatar ? (
              <img
                src={avatar}
                alt="Profile"
                className="profile-picture"
              />
            ) : (
              <div className="avatar-icon">
                <UserIcon />
              </div>
            )}
          </div>

          <div className="profile-picture-actions">
            <h3>Profile Picture</h3>
            <div className="picture-buttons">
              <button
                type="button"
                className="upload-btn"
                onClick={() => fileInputRef.current?.click()}
                disabled={isUploading || isSaving || isLoading}
              >
                {isUploading ? "Uploading..." : "Upload new photo"}
              </button>

              <button
                type="button"
                className="remove-btn"
                onClick={handleRemovePhoto}
                disabled={isUploading || isSaving || isLoading}
              >
                Remove
              </button>
            </div>

            <input
              ref={fileInputRef}
              type="file"
              accept="image/*"
              className="hidden-file-input"
              onChange={handleFileChange}
            />
          </div>
        </div>

        <div className="form-grid">
          <div className="form-group">
            <label htmlFor="firstName">First Name</label>
            <input
              id="firstName"
              type="text"
              placeholder="Admin"
              value={firstName}
              onChange={(e) => setFirstName(e.target.value)}
              disabled={isLoading || isSaving}
            />
          </div>

          <div className="form-group">
            <label htmlFor="lastName">Last Name</label>
            <input
              id="lastName"
              type="text"
              placeholder="User"
              value={lastName}
              onChange={(e) => setLastName(e.target.value)}
              disabled={isLoading || isSaving}
            />
          </div>
        </div>

        <div className="form-group full-width">
          <label htmlFor="email">Email Address</label>
          <input
            id="email"
            type="email"
            placeholder="admin@ayu.com"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            disabled={isLoading || isSaving}
          />
        </div>

        <div className="form-group full-width">
          <label htmlFor="phone">Phone Number</label>
          <input
            id="phone"
            type="tel"
            placeholder="0771234567"
            value={phone}
            onChange={(e) => setPhone(e.target.value)}
            disabled={isLoading || isSaving}
          />
        </div>

        <div className="section-divider" />

        <div className="password-section">
          <h2>Change Password</h2>
          <p>Leave blank to keep your current password.</p>
        </div>

        <div className="form-grid">
          <div className="form-group">
            <label htmlFor="newPassword">New Password</label>
            <input
              id="newPassword"
              type="password"
              placeholder="••••••••"
              value={newPassword}
              onChange={(e) => setNewPassword(e.target.value)}
              disabled={isLoading || isSaving}
            />
          </div>

          <div className="form-group">
            <label htmlFor="confirmPassword">Confirm New Password</label>
            <input
              id="confirmPassword"
              type="password"
              placeholder="••••••••"
              value={confirmPassword}
              onChange={(e) => setConfirmPassword(e.target.value)}
              disabled={isLoading || isSaving}
            />
          </div>
        </div>

        <div className="form-actions">
          <button
            type="button"
            className="cancel-btn"
            onClick={handleCancel}
            disabled={isSaving || isUploading}
          >
            Cancel
          </button>

          <button
            type="button"
            className="save-btn"
            onClick={handleSave}
            disabled={isSaving || isUploading || isLoading}
          >
            <span className="save-icon">🖫</span>
            {isSaving ? "Saving..." : "Save Changes"}
          </button>
        </div>
      </div>

      {showSuccessDialog && (
        <div className="dialog-overlay">
          <div className="dialog-box">
            <div className="lottie-wrapper">
              <Lottie
                animationData={successAnimation}
                loop={false}
                style={{ width: 100, height: 100 }}
              />
            </div>

            <h3>Your changes have been saved successfully</h3>

            <button
              type="button"
              className="dialog-btn"
              onClick={() => setShowSuccessDialog(false)}
            >
              OK
            </button>
          </div>
        </div>
      )}
    </div>
  );
}