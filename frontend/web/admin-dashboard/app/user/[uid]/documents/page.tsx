"use client";

import { useState, useRef, useEffect } from "react";
import { createPortal } from "react-dom";
import "../../../../styles/document.css";
import {
  MedicalDocument,
  DocStatus,
  fetchMedicalDocuments,
  approveMedicalDocument,
  rejectMedicalDocument,
  toggleDonationApproval,
} from "../../../lib/documentService";
import { onAuthStateChanged } from 'firebase/auth';
import { auth } from '../../../lib/firebase';

const badgeClass: Record<DocStatus, string> = {
  Pending:  "documents-badge documents-badge--pending",
  Approved: "documents-badge documents-badge--approved",
  Rejected: "documents-badge documents-badge--rejected",
};

// Icons

const DotsIcon = () => (
  <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="currentColor">
    <circle cx="5" cy="12" r="1.5" />
    <circle cx="12" cy="12" r="1.5" />
    <circle cx="19" cy="12" r="1.5" />
  </svg>
);

const XIcon = () => (
  <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
    <line x1="18" y1="6" x2="6" y2="18" />
    <line x1="6" y1="6" x2="18" y2="18" />
  </svg>
);

const SearchIcon = () => (
  <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
    <circle cx="11" cy="11" r="8" />
    <line x1="21" y1="21" x2="16.65" y2="16.65" />
  </svg>
);

// Main Page

export default function MedicalDocumentApprovals() {
  const [documents, setDocuments] = useState<MedicalDocument[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [openMenu, setOpenMenu] = useState<string | null>(null);
  const [dropdownPos, setDropdownPos] = useState<{ top: number; left: number } | null>(null);
  const [rejectTarget, setRejectTarget] = useState<{ id: string; patient: string } | null>(null);
  const [search, setSearch] = useState(""); 

  const rowRefs = useRef<Record<string, HTMLDivElement | null>>({});

  // Search Filter 
  const filteredDocuments = documents.filter(
    (d) =>
      d.patient.toLowerCase().includes(search.toLowerCase()) ||
      d.document.toLowerCase().includes(search.toLowerCase()) ||
      d.submitted.toLowerCase().includes(search.toLowerCase()) ||
      d.status.toLowerCase().includes(search.toLowerCase())
  );

  useEffect(() => {
    const unsubscribe = onAuthStateChanged(auth, async (user) => {
      if (!user) {
        setError('User not logged in');
        setLoading(false);
        return;
      }

      try {
        setLoading(true);
        setError('');
        const data = await fetchMedicalDocuments();
        setDocuments(data);
      } catch (err) {
        setError(err instanceof Error ? err.message : 'Failed to load documents');
      } finally {
        setLoading(false);
      }
    });

    return () => unsubscribe();
  }, []);

  const toggleMenu = (id: string) => {
    if (openMenu === id) {
      setOpenMenu(null);
      setDropdownPos(null);
    } else {
      const el = rowRefs.current[id];
      if (el) {
        const rect = el.getBoundingClientRect();
        setDropdownPos({ top: rect.bottom + 4, left: rect.right - 176 });
      }
      setOpenMenu(id);
    }
  };

  useEffect(() => {
    const handler = () => { setOpenMenu(null); setDropdownPos(null); };
    if (openMenu !== null) window.addEventListener("click", handler);
    return () => window.removeEventListener("click", handler);
  }, [openMenu]);

  const handleApprove = async (id: string) => {
    try {
      await approveMedicalDocument(id);

      setDocuments((prev) =>
        prev.map((doc) =>
          doc.id === id
            ? {
                ...doc,
                status: "Approved",
                approvedForDonation: true,
                rejectionComment: "",
              }
            : doc
        )
      );
    } catch (err) {
      alert(err instanceof Error ? err.message : "Failed to approve document");
    } finally {
      setOpenMenu(null);
      setDropdownPos(null);
    }
  };

  const handleRejectClick = (id: string, patient: string) => {
    setOpenMenu(null);
    setDropdownPos(null);
    setRejectTarget({ id, patient });
  };

  const handleRejectConfirm = async (comment: string) => {
    if (!rejectTarget) return;
    try {
      await rejectMedicalDocument(rejectTarget.id, comment);

      setDocuments((prev) =>
        prev.map((doc) =>
          doc.id === rejectTarget.id
            ? {
                ...doc,
                status: "Rejected",
                approvedForDonation: false,
                rejectionComment: comment,
              }
            : doc
        )
      );

      setRejectTarget(null);
    } catch (err) {
      alert(err instanceof Error ? err.message : "Failed to reject document");
    }
  };

  const handleToggleDonation = async (id: string) => {
    const doc = documents.find((d) => d.id === id);
    if (!doc || doc.status !== "Approved") return;

    const newValue = !doc.approvedForDonation;

    try {
      await toggleDonationApproval(id, newValue);

      setDocuments((prev) =>
        prev.map((item) =>
          item.id === id ? { ...item, approvedForDonation: newValue } : item
        )
      );
    } catch (err) {
      alert(err instanceof Error ? err.message : "Failed to update donation approval");
    }
  };

  return (
    <div>

      {/* Header */}
      <div className="documents-header">
        <div>
          <h1 className="documents-title">Medical Document Approvals</h1>
          <p className="documents-subtitle">
            Review and approve documents for patient donation requests.
          </p>
        </div>

        {/* Search (Added) */}
        <div className="documents-search-wrapper">
          <span className="documents-search-icon">
            <SearchIcon />
          </span>
          <input
            type="text"
            placeholder="Search documents..."
            className="documents-search-input"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
          />
        </div>
      </div>

      {loading && (
      <div className="documents-loading">
        <div className="documents-spinner" />
        <p className="documents-loading-text">Loading documents...</p>
      </div>
    )}
      {error && <div className="documents-empty">{error}</div>}

      {/* Table */}
      {!loading && !error && (
      <div className="documents-table-wrapper">

        {/* Table Header */}
        <div className="documents-table-header">
          {["Patient", "Document", "Submitted", "Status", "Approval for Donation", "Actions"].map((col, i) => (
            <span key={col} className={`documents-table-header-cell${i === 5 ? " text-right" : ""}`}>
              {col}
            </span>
          ))}
        </div>

        {/* Table Rows */}
        {filteredDocuments.map((doc) => (
          <div key={doc.id} className="documents-table-row">

            <span className="documents-patient">{doc.patient}</span>

            <span className="documents-filename">{doc.document}</span>

            <span className="documents-submitted">{doc.submitted}</span>

            <div>
              <span className={badgeClass[doc.status]}>{doc.status}</span>
            </div>

            <div className="documents-toggle-cell">
              <button
                onClick={() => handleToggleDonation(doc.id)}
                disabled={doc.status !== "Approved"}
                className={`documents-toggle ${doc.approvedForDonation ? "documents-toggle--on" : "documents-toggle--off"} ${doc.status !== "Approved" ? "documents-toggle--disabled" : ""}`}
              >
                <span className={`documents-toggle__thumb ${doc.approvedForDonation ? "documents-toggle__thumb--on" : "documents-toggle__thumb--off"}`} />
              </button>
              <span className="documents-toggle-label">
                {doc.approvedForDonation ? "Yes" : "No"}
              </span>
            </div>

            <div
              className="documents-actions-cell"
              ref={(el) => { rowRefs.current[doc.id] = el; }}
            >
              <button
                onClick={(e) => { e.stopPropagation(); toggleMenu(doc.id); }}
                className="documents-dots-btn"
              >
                <DotsIcon />
              </button>
            </div>

          </div>
        ))}

        {filteredDocuments.length === 0 && (
          <div className="documents-empty">
            No documents match your search.
          </div>
        )}

      </div>)}

      {/* Dropdown Portal */}
      {openMenu !== null && dropdownPos &&
        createPortal(
          <div
            className="documents-dropdown"
            style={{ position: "fixed", top: dropdownPos.top, left: dropdownPos.left, zIndex: 9999 }}
            onClick={(e) => e.stopPropagation()}
          >
            <button
              className="documents-dropdown__item"
              onClick={() => {
                const doc = documents.find((d) => d.id === openMenu);
                if (doc?.documentUrl) {
                  window.open(doc.documentUrl, "_blank", "noopener,noreferrer");
                }
                setOpenMenu(null);
                setDropdownPos(null);
              }}
            >
              View Document
            </button>
            <button onClick={() => handleApprove(openMenu)} className="documents-dropdown__item documents-dropdown__item--approve">Approve</button>
            <button onClick={() => { const doc = documents.find(d => d.id === openMenu); if (doc) handleRejectClick(doc.id, doc.patient); }} className="documents-dropdown__item documents-dropdown__item--reject">Reject</button>
          </div>,
          document.body
        )
      }

      {/* Reject Dialog */}
      <RejectDialog
        open={rejectTarget !== null}
        patientName={rejectTarget?.patient ?? ""}
        onClose={() => setRejectTarget(null)}
        onConfirm={handleRejectConfirm}
      />

    </div>
  );
}

// Reject Dialog

function RejectDialog({
  open,
  patientName,
  onClose,
  onConfirm,
}: {
  open: boolean;
  patientName: string;
  onClose: () => void;
  onConfirm: (comment: string) => void;
}) {
  const [comment, setComment] = useState("");
  const [error, setError] = useState("");

  const handleConfirm = () => {
    if (!comment.trim()) { setError("Please provide a reason for rejection."); return; }
    onConfirm(comment.trim());
    setComment("");
    setError("");
  };

  const handleClose = () => { setComment(""); setError(""); onClose(); };

  if (!open) return null;

  return (
    <div className="reject-dialog-overlay">
      <div className="reject-dialog">

        {/* Header */}
        <div className="reject-dialog__header">
          <div>
            <h2 className="reject-dialog__title">Reject Document</h2>
            <p className="reject-dialog__subtitle">
              Rejecting document for <span>{patientName}</span>
            </p>
          </div>
          <button onClick={handleClose} className="reject-dialog__close"><XIcon /></button>
        </div>

        {/* Body */}
        <div className="reject-dialog__body">
          <label className="reject-dialog__label">
            Reason for Rejection <span className="reject-dialog__required">*</span>
          </label>
          <textarea
            rows={4}
            placeholder="Describe why this document is being rejected..."
            value={comment}
            onChange={(e) => { setComment(e.target.value); if (error) setError(""); }}
            className={`reject-dialog__textarea${error ? " reject-dialog__textarea--error" : ""}`}
          />
          {error && <p className="reject-dialog__error">{error}</p>}
        </div>

        {/* Footer */}
        <div className="reject-dialog__footer">
          <button onClick={handleClose} className="reject-dialog__cancel">Cancel</button>
          <button onClick={handleConfirm} className="reject-dialog__confirm">Confirm Rejection</button>
        </div>

      </div>
    </div>
  );
}