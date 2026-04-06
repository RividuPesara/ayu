"use client";

import { useState, useRef, useEffect } from "react";
import { createPortal } from "react-dom";
import "../../../../styles/patient.css";

type Status = "Active" | "Archived" | "Suspended";

type Patient = {
  id: number;
  name: string;
  email: string;
  status: Status;
  donationApproved: boolean;
};

const initialPatients: Patient[] = [
  { id: 1, name: "Maya Singh",   email: "maya.singh@example.com",   status: "Active",    donationApproved: true  },
  { id: 2, name: "Leo Carter",   email: "leo.carter@example.com",   status: "Suspended", donationApproved: false },
  { id: 3, name: "Sophia Loren", email: "sophia.loren@example.com", status: "Archived",  donationApproved: false },
];

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

export default function PatientManagement() {
  const [patients, setPatients] = useState<Patient[]>(initialPatients);
  const [openMenu, setOpenMenu] = useState<number | null>(null);
  const [dropdownPos, setDropdownPos] = useState<{ top: number; left: number } | null>(null);
  const [search, setSearch] = useState("");
  const rowRefs = useRef<Record<number, HTMLDivElement | null>>({});

  const filteredPatients = patients.filter(
    (p) =>
      p.name.toLowerCase().includes(search.toLowerCase()) ||
      p.email.toLowerCase().includes(search.toLowerCase())
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
    setPatients((prev) => prev.map((p) => (p.id === id ? { ...p, status } : p)));
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

      {/* Table */}
      <div className="table-wrapper">
        <div className="table-header">
          <span className="table-header-cell">Name</span>
          <span className="table-header-cell">Status</span>
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
                  <UserIcon />
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
                  onClick={(e) => { e.stopPropagation(); toggleMenu(patient.id); }}
                  className="dots-button"
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
            className="dropdown-menu"
            style={{ position: "fixed", top: dropdownPos.top, left: dropdownPos.left, zIndex: 9999 }}
            onClick={(e) => e.stopPropagation()}
          >
            <button onClick={() => updateStatus(openMenu, "Active")} className="dropdown-item">Active</button>
            <button onClick={() => updateStatus(openMenu, "Archived")} className="dropdown-item">Archive</button>
            <button onClick={() => updateStatus(openMenu, "Suspended")} className="dropdown-item danger">Suspend</button>
          </div>,
          document.body
        )
      }

    </div>
  );
}