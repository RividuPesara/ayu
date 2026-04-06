"use client";

import Image from "next/image";
import { useState, useRef, useEffect } from "react";
import { createPortal } from "react-dom";
import "../../../../styles/doctor.css";

type Status = "Active" | "Archived" | "Suspended";

type Doctor = {
  id: number;
  name: string;
  email: string;
  specialty: string;
  status: Status;
};

type FormData = {
  fullName: string;
  phone: string;
  address: string;
  slmcNumber: string;
  qualifications: string[];
  specialty: string;
};

const initialDoctors: Doctor[] = [
  { id: 1, name: "Aiden Harris", email: "aiden.harris@example.com", specialty: "Cardiology", status: "Active" },
  { id: 2, name: "Chloe Rivera", email: "chloe.rivera@example.com", specialty: "Neurology", status: "Active" },
];

const emptyForm: FormData = {
  fullName: "", phone: "", address: "", slmcNumber: "", qualifications: [""], specialty: "",
};

const statusClasses: Record<Status, string> = {
  Active: "doctor-badge doctor-badge--active",
  Archived: "doctor-badge doctor-badge--archived",
  Suspended: "doctor-badge doctor-badge--suspended",
};

// Icons

const StethoscopeIcon = () => (
  <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
    <path d="M4.8 2.3A.3.3 0 1 0 5 2H4a2 2 0 0 0-2 2v5a6 6 0 0 0 6 6 6 6 0 0 0 6-6V4a2 2 0 0 0-2-2h-1a.2.2 0 1 0 .3.3" />
    <path d="M8 15v1a6 6 0 0 0 6 6 6 6 0 0 0 6-6v-4" />
    <circle cx="20" cy="10" r="2" />
  </svg>
);

const DotsIcon = () => (
  <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="currentColor">
    <circle cx="5" cy="12" r="1.5" />
    <circle cx="12" cy="12" r="1.5" />
    <circle cx="19" cy="12" r="1.5" />
  </svg>
);

const PlusIcon = () => (
  <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
    <path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2" />
    <circle cx="9" cy="7" r="4" />
    <line x1="19" y1="8" x2="19" y2="14" />
    <line x1="22" y1="11" x2="16" y2="11" />
  </svg>
);

const XIcon = () => (
  <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
    <line x1="18" y1="6" x2="6" y2="18" />
    <line x1="6" y1="6" x2="18" y2="18" />
  </svg>
);

const PlusSmallIcon = () => (
  <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
    <line x1="12" y1="5" x2="12" y2="19" />
    <line x1="5" y1="12" x2="19" y2="12" />
  </svg>
);

const TrashIcon = () => (
  <svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
    <polyline points="3 6 5 6 21 6" />
    <path d="M19 6l-1 14H6L5 6" />
    <path d="M10 11v6M14 11v6" />
    <path d="M9 6V4h6v2" />
  </svg>
);

const SearchIcon = () => (
  <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
    <circle cx="11" cy="11" r="8" />
    <line x1="21" y1="21" x2="16.65" y2="16.65" />
  </svg>
);

// Main Page

export default function DoctorManagement() {
  const [doctors, setDoctors] = useState<Doctor[]>(initialDoctors);
  const [openMenu, setOpenMenu] = useState<number | null>(null);
  const [dropdownPos, setDropdownPos] = useState<{ top: number; left: number } | null>(null);
  const [dialogOpen, setDialogOpen] = useState(false);
  const [search, setSearch] = useState("");
  const rowRefs = useRef<Record<number, HTMLDivElement | null>>({});

  const filteredDoctors = doctors.filter(
    (d) =>
      d.name.toLowerCase().includes(search.toLowerCase()) ||
      d.email.toLowerCase().includes(search.toLowerCase()) ||
      d.specialty.toLowerCase().includes(search.toLowerCase())
  );

  const toggleMenu = (id: number) => {
    if (openMenu === id) {
      setOpenMenu(null);
      setDropdownPos(null);
    } else {
      const el = rowRefs.current[id];
      if (el) {
        const rect = el.getBoundingClientRect();
        setDropdownPos({ top: rect.bottom + 4, left: rect.right - 160 });
      }
      setOpenMenu(id);
    }
  };

  useEffect(() => {
    const handler = () => { setOpenMenu(null); setDropdownPos(null); };
    if (openMenu !== null) window.addEventListener("click", handler);
    return () => window.removeEventListener("click", handler);
  }, [openMenu]);

  const updateStatus = (id: number, status: Status) => {
    setDoctors((prev) => prev.map((doc) => (doc.id === id ? { ...doc, status } : doc)));
    setOpenMenu(null);
    setDropdownPos(null);
  };

  const handleCreateDoctor = (data: FormData) => {
    const newDoctor: Doctor = {
      id: doctors.length ? Math.max(...doctors.map((d) => d.id)) + 1 : 1,
      name: data.fullName,
      email: `${data.fullName.toLowerCase().replace(/\s+/g, ".")}@example.com`,
      specialty: data.specialty,
      status: "Active",
    };
    setDoctors((prev) => [...prev, newDoctor]);
  };

  return (
    <div>

      {/* Header */}
      <div className="doctor-header">
        <div className="doctor-header__text">
          <h1 className="doctor-title">Doctor Management</h1>
          <p className="doctor-subtitle">View and manage all doctor accounts.</p>
        </div>

        {/* Right side: search + create */}
        <div className="doctor-header__actions">
          <div className="doctor-search-wrapper">
            <span className="doctor-search-icon"><SearchIcon /></span>
            <input
              type="text"
              className="doctor-search-input"
              placeholder="Search doctors..."
              value={search}
              onChange={(e) => setSearch(e.target.value)}
            />
          </div>
          <button onClick={() => setDialogOpen(true)} className="doctor-create-btn">
            <PlusIcon /> Create Doctor
          </button>
        </div>
      </div>

      {/* Table */}
      <div className="doctor-table-wrapper">
        <div className="doctor-table-header">
          <span className="doctor-table-header-cell">Name</span>
          <span className="doctor-table-header-cell">Specialty</span>
          <span className="doctor-table-header-cell">Status</span>
          <span className="doctor-table-header-cell text-right">Actions</span>
        </div>

        {filteredDoctors.length === 0 ? (
          <div className="doctor-empty-state">No doctors match your search.</div>
        ) : (
          filteredDoctors.map((doctor) => (
            <div key={doctor.id} className="doctor-table-row">

              {/* Name + Avatar */}
              <div className="doctor-cell">
                <div className="doctor-avatar">
                  <Image src="/assets/avatar.png" alt={doctor.name} fill className="object-cover" />
                </div>
                <div>
                  <p className="doctor-name">{doctor.name}</p>
                  <p className="doctor-email">{doctor.email}</p>
                </div>
              </div>

              {/* Specialty */}
              <div className="doctor-specialty">
                <StethoscopeIcon />
                <span>{doctor.specialty}</span>
              </div>

              {/* Status */}
              <div>
                <span className={statusClasses[doctor.status]}>{doctor.status}</span>
              </div>

              {/* Actions */}
              <div
                className="doctor-actions-cell"
                ref={(el) => { rowRefs.current[doctor.id] = el; }}
              >
                <button
                  onClick={(e) => { e.stopPropagation(); toggleMenu(doctor.id); }}
                  className="doctor-dots-btn"
                >
                  <DotsIcon />
                </button>
              </div>

            </div>
          ))
        )}
      </div>

      {/* Dropdown Portal */}
      {openMenu !== null && dropdownPos &&
        createPortal(
          <div
            className="doctor-dropdown"
            style={{ position: "fixed", top: dropdownPos.top, left: dropdownPos.left, zIndex: 9999 }}
            onClick={(e) => e.stopPropagation()}
          >
            <button onClick={() => updateStatus(openMenu, "Active")} className="doctor-dropdown__item">Active</button>
            <button onClick={() => updateStatus(openMenu, "Archived")} className="doctor-dropdown__item">Archive</button>
            <button onClick={() => updateStatus(openMenu, "Suspended")} className="doctor-dropdown__item doctor-dropdown__item--danger">Suspend</button>
          </div>,
          document.body
        )
      }

      {/* Create Doctor Dialog */}
      <CreateDoctorDialog
        open={dialogOpen}
        onClose={() => setDialogOpen(false)}
        onSubmit={handleCreateDoctor}
      />

    </div>
  );
}

// Field Helper

function Field({
  label,
  required,
  error,
  children,
}: {
  label: string;
  required?: boolean;
  error?: string;
  children: React.ReactNode;
}) {
  return (
    <div className="doctor-field">
      <label className="doctor-field__label">
        {label} {required && <span className="doctor-field__required">*</span>}
      </label>
      {children}
      {error && <p className="doctor-field__error">{error}</p>}
    </div>
  );
}

// Create Doctor Dialog

function CreateDoctorDialog({
  open,
  onClose,
  onSubmit,
}: {
  open: boolean;
  onClose: () => void;
  onSubmit: (data: FormData) => void;
}) {
  const [form, setForm] = useState<FormData>(emptyForm);
  const [errors, setErrors] = useState<Partial<Record<keyof FormData | "qualifications_0", string>>>({});
  const dialogRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (open) { setForm(emptyForm); setErrors({}); }
  }, [open]);

  useEffect(() => {
    const handler = (e: KeyboardEvent) => { if (e.key === "Escape") onClose(); };
    window.addEventListener("keydown", handler);
    return () => window.removeEventListener("keydown", handler);
  }, [onClose]);

  const handleBackdropClick = (e: React.MouseEvent<HTMLDivElement>) => {
    if (dialogRef.current && !dialogRef.current.contains(e.target as Node)) onClose();
  };

  const set = (field: keyof FormData, value: string) => {
    setForm((prev) => ({ ...prev, [field]: value }));
    setErrors((prev) => ({ ...prev, [field]: undefined }));
  };

  const setQualification = (index: number, value: string) => {
    setForm((prev) => {
      const updated = [...prev.qualifications];
      updated[index] = value;
      return { ...prev, qualifications: updated };
    });
  };

  const addQualification = () =>
    setForm((prev) => ({ ...prev, qualifications: [...prev.qualifications, ""] }));

  const removeQualification = (index: number) =>
    setForm((prev) => ({ ...prev, qualifications: prev.qualifications.filter((_, i) => i !== index) }));

  const validate = (): boolean => {
    const newErrors: typeof errors = {};
    if (!form.fullName.trim()) newErrors.fullName = "Full name is required.";
    if (!form.phone.trim()) newErrors.phone = "Phone number is required.";
    else if (!/^\+?[\d\s\-()]{7,15}$/.test(form.phone.trim())) newErrors.phone = "Enter a valid phone number.";
    if (!form.address.trim()) newErrors.address = "Address is required.";
    if (!form.slmcNumber.trim()) newErrors.slmcNumber = "SLMC number is required.";
    if (!form.specialty.trim()) newErrors.specialty = "Specialty is required.";
    if (form.qualifications.every((q) => !q.trim())) newErrors.qualifications_0 = "At least one qualification is required.";
    setErrors(newErrors);
    return Object.keys(newErrors).length === 0;
  };

  const handleSubmit = () => {
    if (!validate()) return;
    onSubmit({ ...form, qualifications: form.qualifications.filter((q) => q.trim()) });
    onClose();
  };

  if (!open) return null;

  return (
    <div className="doctor-dialog-overlay" onClick={handleBackdropClick}>
      <div ref={dialogRef} className="doctor-dialog">

        {/* Header */}
        <div className="doctor-dialog__header">
          <div>
            <h2 className="doctor-dialog__title">Create New Doctor</h2>
            <p className="doctor-dialog__subtitle">Fill in the details to register a new doctor account.</p>
          </div>
          <button onClick={onClose} className="doctor-dialog__close"><XIcon /></button>
        </div>

        {/* Body */}
        <div className="doctor-dialog__body">

          <Field label="Full Name" required error={errors.fullName}>
            <input type="text" placeholder="e.g. Dr. John Perera" value={form.fullName}
              onChange={(e) => set("fullName", e.target.value)}
              className={`doctor-field__input${errors.fullName ? " doctor-field__input--error" : ""}`} />
          </Field>

          <Field label="Phone Number" required error={errors.phone}>
            <input type="tel" placeholder="e.g. +94 77 123 4567" value={form.phone}
              onChange={(e) => set("phone", e.target.value)}
              className={`doctor-field__input${errors.phone ? " doctor-field__input--error" : ""}`} />
          </Field>

          <Field label="Address" required error={errors.address}>
            <textarea placeholder="Clinic or hospital address" value={form.address}
              onChange={(e) => set("address", e.target.value)} rows={2}
              className={`doctor-field__textarea${errors.address ? " doctor-field__textarea--error" : ""}`} />
          </Field>

          <Field label="Specialty" required error={errors.specialty}>
            <input type="text" placeholder="e.g. Cardiology" value={form.specialty}
              onChange={(e) => set("specialty", e.target.value)}
              className={`doctor-field__input${errors.specialty ? " doctor-field__input--error" : ""}`} />
          </Field>

          <Field label="SLMC Registration Number" required error={errors.slmcNumber}>
            <input type="text" placeholder="e.g. SLMC/2024/001234" value={form.slmcNumber}
              onChange={(e) => set("slmcNumber", e.target.value)}
              className={`doctor-field__input${errors.slmcNumber ? " doctor-field__input--error" : ""}`} />
          </Field>

          <div className="doctor-field">
            <label className="doctor-field__label">
              Qualifications <span className="doctor-field__required">*</span>
            </label>
            <div style={{ display: "flex", flexDirection: "column", gap: "8px" }}>
              {form.qualifications.map((q, i) => (
                <div key={i} className="doctor-qual-row">
                  <input type="text"
                    placeholder={`e.g. ${i === 0 ? "MBBS" : i === 1 ? "MD (Cardiology)" : "Fellowship"}`}
                    value={q}
                    onChange={(e) => setQualification(i, e.target.value)}
                    className={`doctor-field__input${i === 0 && errors.qualifications_0 ? " doctor-field__input--error" : ""}`} />
                  {form.qualifications.length > 1 && (
                    <button onClick={() => removeQualification(i)} className="doctor-qual-remove">
                      <TrashIcon />
                    </button>
                  )}
                </div>
              ))}
            </div>
            {errors.qualifications_0 && <p className="doctor-field__error">{errors.qualifications_0}</p>}
            <button onClick={addQualification} className="doctor-qual-add">
              <PlusSmallIcon /> Add qualification
            </button>
          </div>

        </div>

        {/* Footer */}
        <div className="doctor-dialog__footer">
          <button onClick={onClose} className="doctor-dialog__cancel">Cancel</button>
          <button onClick={handleSubmit} className="doctor-dialog__submit">
            <PlusSmallIcon /> Create Doctor
          </button>
        </div>

      </div>
    </div>
  );
}