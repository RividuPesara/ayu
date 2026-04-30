"use client";

import { useState, useRef, useEffect } from "react";
import { createPortal } from "react-dom";
import "../../../../styles/patient.css";
import {
  fetchPatients,
  updatePatientStatus,
  Patient,
  Status,
} from "../../../lib/patientService";

const statusClasses: Record<Status, string> = {
  Active:    "badge badge-active",
  Suspended: "badge badge-suspended",
  Archived:  "badge badge-archived",
};

const DotsIcon = () => (
  <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="currentColor">
    <circle cx="5" cy="12" r="1.5" />
    <circle cx="12" cy="12" r="1.5" />
    <circle cx="19" cy="12" r="1.5" />
  </svg>
);

const UserIcon = () => (
  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor">
    <path d="M12 12c2.7 0 4.8-2.1 4.8-4.8S14.7 2.4 12 2.4 7.2 4.5 7.2 7.2 9.3 12 12 12zm0 2.4c-3.2 0-9.6 1.6-9.6 4.8v2.4h19.2v-2.4c0-3.2-6.4-4.8-9.6-4.8z" />
  </svg>
);

const SearchIcon = () => (
  <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
    <circle cx="11" cy="11" r="8" />
    <line x1="21" y1="21" x2="16.65" y2="16.65" />
  </svg>
);

const ViewProfileIcon = () => (
  <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
    <path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2" />
    <circle cx="12" cy="7" r="4" />
  </svg>
);

const ActiveIcon = () => (
  <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
    <circle cx="12" cy="12" r="10" />
    <path d="m9 12 2 2 4-4" />
  </svg>
);

const SuspendIcon = () => (
  <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
    <circle cx="12" cy="12" r="10" />
    <line x1="10" y1="9" x2="10" y2="15" />
    <line x1="14" y1="9" x2="14" y2="15" />
  </svg>
);

const ArchiveIcon = () => (
  <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
    <polyline points="3 6 5 6 21 6" />
    <path d="M19 6l-1 14H6L5 6" />
    <path d="M10 11v6M14 11v6" />
    <path d="M9 6V4h6v2" />
  </svg>
);

export default function PatientManagement() {
  const [patients, setPatients] = useState<Patient[]>([]);
  const [openMenu, setOpenMenu] = useState<string | null>(null);
  const [dropdownPos, setDropdownPos] = useState<{ top: number; left: number } | null>(null);
  const [search, setSearch] = useState("");
  const [loading, setLoading] = useState(true);
  const [savingId, setSavingId] = useState<string | null>(null);
  const rowRefs = useRef<Record<string, HTMLDivElement | null>>({});
  const [selectedPatient, setSelectedPatient] = useState<Patient | null>(null);
  const [viewDialogOpen, setViewDialogOpen] = useState(false);

  useEffect(() => {
    loadPatients();
  }, []);

  const loadPatients = async () => {
    try {
      setLoading(true);
      const data = await fetchPatients();
      setPatients(data);
    } catch (err) {
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  const filteredPatients = patients.filter(
    (p) =>
      (p.name ?? "").toLowerCase().includes(search.toLowerCase()) ||
      (p.email ?? "").toLowerCase().includes(search.toLowerCase())
  );

  const toggleMenu = (id: string) => {
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

  const updateStatus = async (id: string, status: Status) => {
    try {
      setSavingId(id);
      await updatePatientStatus(id, status);

      setPatients((prev) =>
        prev.map((p) => (p.id === id ? { ...p, status } : p))
      );

      setSelectedPatient((prev) =>
        prev && prev.id === id ? { ...prev, status } : prev
      );
    } catch (err) {
      console.error(err);
    } finally {
      setSavingId(null);
      setOpenMenu(null);
      setDropdownPos(null);
    }
  };

  const handleViewProfile = (id: string) => {
    const patient = patients.find((p) => p.id === id) || null;
    setSelectedPatient(patient);
    setViewDialogOpen(true);
    setOpenMenu(null);
    setDropdownPos(null);
  };

  return (
    <div>

      {/* Header */}
      <div className="page-header">
        <div className="title-section">
          <h1 className="page-title">Patient Management</h1>
          <p className="page-subtitle">View and manage all patient accounts.</p>
        </div>

        {/* Search Bar */}
        <div className="search-wrapper">
          <span className="search-icon"><SearchIcon /></span>
          <input
            type="text"
            className="search-input"
            placeholder="Search patients..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
          />
        </div>
      </div>

      {/* Content below header */}
      {loading ? (
        <div className="patient-page-loader">
          <div className="patient-page-loader__spinner" />
          <p className="patient-page-loader__text">Loading patients...</p>
        </div>
      ) : (
      <div className="table-wrapper">
        <div className="table-header">
          <span className="table-header-cell">Patient's Name</span>
          <span className="table-header-cell">Account Status</span>
          <span className="table-header-cell">Donation</span>
          <span className="table-header-cell text-right">Actions</span>
        </div>

        {filteredPatients.length === 0 ? (
          <div className="empty-state">No patients match your search.</div>
        ) : (
          filteredPatients.map((patient) => (
            <div key={patient.id} className="table-row">

              {/* Name + Avatar */}
              <div className="patient-cell">
                <div className="patient-avatar">
                  {patient.avatar ? (
                    <img src={patient.avatar} alt={patient.name} className="patient-avatar-img" />
                  ) : (
                    <UserIcon />
                  )}
                </div>
                <div>
                  <p className="patient-name">{patient.name}</p>
                  <p className="patient-email">{patient.email}</p>
                </div>
              </div>

              {/* Status Badge */}
              <div>
                <span className={statusClasses[patient.status]}>
                  {patient.status}
                </span>
              </div>

              {/* Donation Toggle — read-only */}
              <div className="donation-cell">
                <button
                  className={`donation-toggle ${patient.donationApproved ? "approved" : "not-approved"}`}
                  disabled
                  title={patient.donationApproved ? "Approved for donation" : "Not approved for donation"}
                >
                  <span className="toggle-thumb" />
                </button>
                <span className="donation-label">
                  {patient.donationApproved ? "Approved" : "Not Approved"}
                </span>
              </div>

              {/* Actions */}
              <div
                className="actions-cell"
                ref={(el) => { rowRefs.current[patient.id] = el; }}
              >
                <button
                  onClick={(e) => {
                    e.stopPropagation();
                    toggleMenu(patient.id);
                  }}
                  className="dots-button"
                  disabled={savingId === patient.id}
                >
                  <DotsIcon />
                </button>
              </div>

            </div>
          ))
        )}
      </div>
      )}

      {/* Dropdown Portal */}
      {openMenu !== null && dropdownPos &&
        createPortal(
          <div
            className="patient-dropdown"
            style={{ position: "fixed", top: dropdownPos.top, left: dropdownPos.left, zIndex: 9999 }}
            onClick={(e) => e.stopPropagation()}
          >
          <button
              onClick={() => handleViewProfile(openMenu)}
              className="patient-dropdown__item"
            >
              <ViewProfileIcon />
              <span>View profile</span>
            </button>

            <div className="patient-dropdown__divider">CHANGE STATUS</div>

            <button
              onClick={() => updateStatus(openMenu, "Active")}
              className="patient-dropdown__item patient-dropdown__item--success"
            >
              <ActiveIcon />
              <span>Active</span>
            </button>

            <button
              onClick={() => updateStatus(openMenu, "Suspended")}
              className="patient-dropdown__item patient-dropdown__item--warning"
            >
              <SuspendIcon />
              <span>Suspend</span>
            </button>

            <button
              onClick={() => updateStatus(openMenu, "Archived")}
              className="patient-dropdown__item patient-dropdown__item--danger"
            >
              <ArchiveIcon />
              <span>Archive</span>
            </button>
          </div>,
          document.body
        )}
        
      <ViewPatientDialog
        open={viewDialogOpen}
        patient={selectedPatient}
        onClose={() => setViewDialogOpen(false)}
      />
    </div>
  );
}

function ViewPatientDialog({
  open,
  patient,
  onClose,
}: {
  open: boolean;
  patient: Patient | null;
  onClose: () => void;
}) {
  const dialogRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const handler = (e: KeyboardEvent) => {
      if (e.key === "Escape") onClose();
    };

    if (open) window.addEventListener("keydown", handler);
    return () => window.removeEventListener("keydown", handler);
  }, [open, onClose]);

  const handleBackdropClick = (e: React.MouseEvent<HTMLDivElement>) => {
    if (dialogRef.current && !dialogRef.current.contains(e.target as Node)) {
      onClose();
    }
  };

  if (!open || !patient) return null;

  return (
    <div className="patient-dialog-overlay" onClick={handleBackdropClick}>
      <div ref={dialogRef} className="patient-dialog">
        <div className="patient-dialog__header">
          <div>
            <h2 className="patient-dialog__title">Patient Profile</h2>
            <p className="patient-dialog__subtitle">
              View patient information.
            </p>
          </div>
          <button onClick={onClose} className="patient-dialog__close">
            ×
          </button>
        </div>

        <div className="patient-dialog__body">
          <div className="patient-profile-preview">
            <div className="patient-profile-preview__avatar">
              {patient.avatar ? (
                <img src={patient.avatar} alt={patient.name} className="patient-profile-avatar-img" />
              ) : (
                <UserIcon />
              )}
            </div>

            <div className="patient-profile-preview__info">
              <h3 className="patient-profile-preview__name">{patient.name}</h3>
            </div>
          </div>

          <ReadOnlyPatientField label="Full Name" value={patient.name} />
          <ReadOnlyPatientField label="Email Address" value={patient.email} />
          <ReadOnlyPatientField label="Cancer Type" value={patient.cancerType} />
          <ReadOnlyPatientField label="Stage" value={patient.stage} />
          <ReadOnlyPatientField label="Companion Name" value={patient.companionName} />
          <ReadOnlyPatientField label="Companion Email" value={patient.companionEmail} />
          <ReadOnlyPatientField label="Status" value={patient.status} />
          <ReadOnlyPatientField
            label="Donation Approval"
            value={patient.donationApproved ? "Approved" : "Not Approved"}
          />
        </div>

        <div className="patient-dialog__footer">
          <button onClick={onClose} className="patient-dialog__cancel">
            Close
          </button>
        </div>
      </div>
    </div>
  );
}

function ReadOnlyPatientField({
  label,
  value,
}: {
  label: string;
  value?: string;
}) {
  return (
    <div className="patient-field">
      <label className="patient-field__label">{label}</label>
      <div className="patient-readonly-box">{value || "-"}</div>
    </div>
  );
}