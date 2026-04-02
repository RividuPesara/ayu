"use client";
 
import React, { useState, useRef, useEffect } from "react";
import Image from "next/image";
import defaultAvatar from "@/public/assets/avatar.png";
import { useRouter } from "next/navigation";
import { signOut } from "firebase/auth";
import { auth } from "@/app/lib/firebase";
import { backendRequest } from "@/app/lib/backend-api";
 
interface Profile {
  name: string;
  specialty: string;
  phone: string;
  avatar: string;
}

interface HeaderProps {
  initialProfile?: Partial<Profile>;
}

interface BackendDoctorProfile {
  uid: string;
  full_name: string;
  specialty?: string | null;
  phone?: string | null;
  avatar_url?: string | null;
}

interface AvatarUploadResponse {
  avatar_url: string;
}

const SRI_LANKAN_MOBILE_REGEX = /^07\d{8}$/;

function getErrorMessage(error: unknown): string {
  if (error instanceof Error && error.message) {
    return error.message;
  }
  return "Failed to update profile.";
}

function toSafeAvatarSrc(value: string | null | undefined): string {
  const normalized = value?.trim();
  if (!normalized) {
    return "/assets/avatar.png";
  }

  if (
    normalized.startsWith("/") ||
    normalized.startsWith("http://") ||
    normalized.startsWith("https://") ||
    normalized.startsWith("data:image/")
  ) {
    return normalized;
  }

  return "/assets/avatar.png";
}

function mapProfileFromBackend(data: BackendDoctorProfile): Profile {
  return {
    name: data.full_name || "Doctor",
    specialty: data.specialty || "",
    phone: data.phone || "",
    avatar: toSafeAvatarSrc(data.avatar_url),
  };
}
 
export default function Header({ initialProfile }: HeaderProps) {
  const router = useRouter();
  const [dropdownOpen, setDropdownOpen] = useState(false);
  const [editOpen, setEditOpen] = useState(false);
  const [showLogoutTooltip, setShowLogoutTooltip] = useState(false);
  const [toast, setToast] = useState<{ message: string; type: "success" | "error" } | null>(null);
  const dropdownRef = useRef<HTMLDivElement>(null);
 
  const [profile, setProfile] = useState<Profile>({
    name: initialProfile?.name || "",
    specialty: initialProfile?.specialty || "",
    phone: initialProfile?.phone || "",
    avatar: toSafeAvatarSrc(initialProfile?.avatar),
  });
 
  // Edit profile form state
  const [editName, setEditName] = useState(profile.name);
  const [editSpecialty, setEditSpecialty] = useState(profile.specialty);
  const [editPhone, setEditPhone] = useState(profile.phone);
  const [editAvatar, setEditAvatar] = useState(profile.avatar);
  const [avatarPreview, setAvatarPreview] = useState<string | null>(null);
  const [avatarFile, setAvatarFile] = useState<File | null>(null);
  const avatarInputRef = useRef<HTMLInputElement>(null);

  const displayName = profile.name || "Doctor";
  const displaySpecialty = profile.specialty || "";
  const displayAvatar = toSafeAvatarSrc(profile.avatar);
 
  useEffect(() => {
    function handleClickOutside(e: MouseEvent) {
      if (dropdownRef.current && !dropdownRef.current.contains(e.target as Node)) {
        setDropdownOpen(false);
      }
    }
    document.addEventListener("mousedown", handleClickOutside);
    return () => document.removeEventListener("mousedown", handleClickOutside);
  }, []);

  useEffect(() => {
    async function loadProfile() {
      try {
        const data = await backendRequest<BackendDoctorProfile>("/api/doctor/profile");
        const mapped = mapProfileFromBackend(data);
        setProfile(mapped);
        setEditName(mapped.name);
        setEditSpecialty(mapped.specialty);
        setEditPhone(mapped.phone);
        setEditAvatar(mapped.avatar);
      } catch (error) {
        console.error(error);
      }
    }

    loadProfile();
  }, []);
 
  // Auto-dismiss toast
  useEffect(() => {
    if (toast) {
      const t = setTimeout(() => setToast(null), 3000);
      return () => clearTimeout(t);
    }
  }, [toast]);
 
  async function handleLogout() {
    setDropdownOpen(false);

    try {
      await signOut(auth);
      setToast({ message: "Logged out successfully.", type: "success" });
      setTimeout(() => router.push("/login"), 1500);
    } catch {
      setToast({ message: "Logout failed. Please try again.", type: "error" });
    }
  }
 
  function handleAvatarChange(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    if (!file) return;

    if (!file.type.startsWith("image/")) {
      setToast({ message: "Please select a valid image file.", type: "error" });
      return;
    }

    if (file.size > 5 * 1024 * 1024) {
      setToast({ message: "Image must be smaller than 5MB.", type: "error" });
      return;
    }

    setAvatarFile(file);
    const reader = new FileReader();
    reader.onload = (ev) => setAvatarPreview(ev.target?.result as string);
    reader.readAsDataURL(file);
  }
 
  async function handleSaveProfile() {
    try {
      const phone = editPhone.trim();
      if (phone && !SRI_LANKAN_MOBILE_REGEX.test(phone)) {
        setToast({ message: "Phone must be a valid Sri Lankan mobile number (e.g. 0775455266).", type: "error" });
        return;
      }

      let avatar = editAvatar;

      if (avatarFile) {
        const formData = new FormData();
        formData.append("avatar", avatarFile);

        const uploadResult = await backendRequest<AvatarUploadResponse>("/api/doctor/profile/avatar", {
          method: "POST",
          body: formData,
        });
        avatar = uploadResult.avatar_url;
      }

      const updated = await backendRequest<BackendDoctorProfile>("/api/doctor/profile", {
        method: "PATCH",
        body: JSON.stringify({
          full_name: editName,
          specialty: editSpecialty,
          phone: phone || null,
          avatar_url: avatar,
        }),
      });

      const mapped = mapProfileFromBackend(updated);
      setProfile(mapped);
      setEditName(mapped.name);
      setEditSpecialty(mapped.specialty);
      setEditPhone(mapped.phone);
      setEditAvatar(mapped.avatar);
      setEditOpen(false);
      setAvatarPreview(null);
      setAvatarFile(null);
      setToast({ message: "Profile updated successfully.", type: "success" });
    } catch (error: unknown) {
      setToast({ message: getErrorMessage(error), type: "error" });
    }
  }
 
  function openEditProfile() {
    setEditName(profile.name);
    setEditSpecialty(profile.specialty);
    setEditPhone(profile.phone);
    setEditAvatar(profile.avatar);
    setAvatarPreview(null);
    setAvatarFile(null);
    setEditOpen(true);
    setDropdownOpen(false);
  }
 
  return (
    <>
      <header className="bg-transparent max-w-7xl mx-auto flex items-center justify-between">
        {/* Logo */}
        <div className="flex items-center gap-2">
          <Image
            src="/assets/logo.png"
            alt="AYU Logo"
            width={65}
            height={65}
            className="object-contain"
            onError={(e) => {
              (e.target as HTMLImageElement).style.display = "none";
            }}
          />
        </div>
 
        {/* Right side — profile */}
        <div className="flex items-center gap-3 relative" ref={dropdownRef}>
          <div className="text-right mr-1">
            <p className="text-sm font-semibold text-white leading-tight">{displayName}</p>
            <p className="text-xs text-gray-300">{displaySpecialty}</p>
          </div>
 
          {/* Avatar button */}
          <button
            onClick={() => setDropdownOpen((v) => !v)}
            className="relative w-10 h-10 rounded-full overflow-hidden border-2 border-[gray] focus:outline-none focus:ring-2 focus:ring-[#7C3AED] focus:ring-offset-2 transition-transform hover:scale-105 cursor-pointer"
            aria-label="Open profile menu"
          >
            <Image
              src={displayAvatar}
              alt="Profile"
              fill
              className="object-cover"
              onError={(e) => {
                const imgElement = e.target as HTMLImageElement;
                imgElement.src = defaultAvatar.src;
              }}
            />
          </button>
 
          {/* Logout button with tooltip */}
          <div className="relative">
            <button
              onMouseEnter={() => setShowLogoutTooltip(true)}
              onMouseLeave={() => setShowLogoutTooltip(false)}
              onClick={() => {
                void handleLogout();
              }}
              className="w-9 h-9 flex items-center justify-center rounded-full hover:bg-red-50 text-gray-400 hover:text-red-500 transition-colors cursor-pointer"
              aria-label="Logout"
            >
              <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round">
                <path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4" />
                <polyline points="16 17 21 12 16 7" />
                <line x1="21" y1="12" x2="9" y2="12" />
              </svg>
            </button>
            {showLogoutTooltip && (
              <div className="absolute right-0 top-full mt-1 bg-gray-800 text-white text-xs px-2 py-1 rounded whitespace-nowrap z-50">
                Sign out of your account
              </div>
            )}
          </div>
 
          {/* Dropdown menu */}
          {dropdownOpen && (
            <div className="absolute right-0 top-full mt-2 w-52 bg-white rounded-xl shadow-xl border border-gray-100 z-50 overflow-hidden">
              <div className="px-4 py-3 border-b border-gray-50">
                <p className="text-xs text-gray-400 font-medium">Signed in as</p>
                <p className="text-sm font-semibold text-[#1A1A2E] truncate">{displayName}</p>
              </div>
              <button
                className="w-full flex items-center gap-3 px-4 py-3 text-sm text-gray-700 hover:bg-[#F4F6FB] transition-colors"
                onClick={openEditProfile}
              >
                <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                  <path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7" />
                  <path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z" />
                </svg>
                Edit Profile
              </button>
            </div>
          )}
        </div>
      </header>
 
      {/* Edit Profile Dialog */}
      {editOpen && (
        <div className="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4">
          <div className="bg-white rounded-2xl w-full max-w-md overflow-hidden shadow-2xl">
            {/* Dialog header */}
            <div className="bg-[#694EBC] px-6 py-5 flex items-center justify-between">
              <div>
                <h3 className="text-white font-bold text-lg">Edit Profile</h3>
                <p className="text-white/60 text-sm mt-0.5">Update your professional information</p>
              </div>
              <button
                onClick={() => setEditOpen(false)}
                className="text-white/70 hover:text-white w-8 h-8 flex items-center justify-center rounded-lg hover:bg-white/10 transition-colors"
              >
                ✕
              </button>
            </div>
 
            <div className="p-6">
              {/* Avatar upload */}
              <div className="flex flex-col items-center mb-6">
                <div
                  className="relative w-24 h-24 rounded-full overflow-hidden border-4 border-purple-100 cursor-pointer group"
                  onClick={() => avatarInputRef.current?.click()}
                >
                  <Image
                    src={avatarPreview || toSafeAvatarSrc(editAvatar)}
                    alt="Avatar preview"
                    fill
                    className="object-cover"
                    onError={(e) => {
                      const imgElement = e.target as HTMLImageElement;
                      imgElement.src = defaultAvatar.src;
                    }}
                  />
                  {/* Camera overlay */}
                  <div className="absolute inset-0 bg-black/40 opacity-0 group-hover:opacity-100 transition-opacity flex items-center justify-center">
                    <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="white" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                      <path d="M23 19a2 2 0 0 1-2 2H3a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h4l2-3h6l2 3h4a2 2 0 0 1 2 2z" />
                      <circle cx="12" cy="13" r="4" />
                    </svg>
                  </div>
                </div>
                <input
                  ref={avatarInputRef}
                  type="file"
                  accept="image/*"
                  onChange={handleAvatarChange}
                  className="hidden"
                />
                <p
                  className="text-[#7C3AED] text-xs mt-2 cursor-pointer hover:underline"
                  onClick={() => avatarInputRef.current?.click()}
                >
                  Click to change photo
                </p>
              </div>
 
              {/* Form fields */}
              <div className="flex flex-col gap-4">
                <div>
                  <label className="text-xs font-semibold text-gray-500 uppercase tracking-wide block mb-1.5">
                    Full Name
                  </label>
                  <input
                    value={editName}
                    onChange={(e) => setEditName(e.target.value)}
                    className="w-full border border-gray-200 rounded-xl px-4 py-2.5 text-sm text-gray-800 outline-none focus:border-[#7C3AED] transition-colors"
                  />
                </div>
                <div>
                  <label className="text-xs font-semibold text-gray-500 uppercase tracking-wide block mb-1.5">
                    Specialty
                  </label>
                  <input
                    value={editSpecialty}
                    onChange={(e) => setEditSpecialty(e.target.value)}
                    className="w-full border border-gray-200 rounded-xl px-4 py-2.5 text-sm text-gray-800 outline-none focus:border-[#7C3AED] transition-colors"
                  />
                </div>
                <div>
                  <label className="text-xs font-semibold text-gray-500 uppercase tracking-wide block mb-1.5">
                    Phone Number
                  </label>
                  <input
                    value={editPhone}
                    onChange={(e) => setEditPhone(e.target.value.replace(/\D/g, "").slice(0, 10))}
                    placeholder="0775455266"
                    className="w-full border border-gray-200 rounded-xl px-4 py-2.5 text-sm text-gray-800 outline-none focus:border-[#7C3AED] transition-colors"
                  />
                </div>
              </div>
 
              {/* Action buttons */}
              <div className="flex gap-3 mt-6">
                <button
                  onClick={() => setEditOpen(false)}
                  className="flex-1 py-2.5 rounded-xl border border-gray-200 text-gray-600 text-sm font-semibold hover:bg-gray-50 transition-colors"
                >
                  Cancel
                </button>
                <button
                  onClick={() => {
                    void handleSaveProfile();
                  }}
                  className="flex-2 py-2.5 rounded-xl bg-[#694EBC] text-white text-sm font-semibold hover:opacity-90 transition-opacity"
                >
                  Save Changes
                </button>
              </div>
            </div>
          </div>
        </div>
      )}
 
      {/* Toast notification */}
      {toast && (
        <div className={`fixed bottom-6 right-6 z-50 flex items-center gap-3 px-4 py-3 rounded-xl shadow-lg text-white text-sm font-medium ${toast.type === "success" ? "bg-green-500" : "bg-red-500"}`}>
          <span>{toast.type === "success" ? "✓" : "✕"}</span>
          <span>{toast.message}</span>
        </div>
      )}
    </>
  );
}