"use client";
 
import React, { useState, useRef } from "react";
import { backendRequest } from "@/app/lib/backend-api";
import { Appointment } from "./timeline";

// Interface defining the props for the AppointmentDetails component
interface AppointmentDetailsProps {
  appointment: Appointment;
  onClose: () => void;
  onSaveStart?: () => void;
  onSaveSuccess?: (updatedAppointment: Appointment) => void;
  onSaveError?: (message: string) => void;
}

interface BackendAppointment {
  id: string;
  name: string;
  time: string;
  type: string;
  status: "done" | "upcoming" | "overdue";
  date?: string;
  zoom_meeting_id?: string;
  zoom_passcode?: string;
  clinical_notes?: string;
  intake_note?: string;
  prescription_url?: string;
  prescription_filename?: string;
  documentation_url?: string;
  documentation_filename?: string;
}

interface UploadedAppointmentFile {
  url: string;
  filename: string;
  category: "prescription" | "documentation";
}

function mapBackendAppointment(item: BackendAppointment): Appointment {
  return {
    id: item.id,
    name: item.name,
    time: item.time,
    type: item.type,
    status: item.status,
    date: item.date,
    zoomMeetingId: item.zoom_meeting_id,
    zoomPasscode: item.zoom_passcode,
    clinicalNotes: item.clinical_notes,
    intakeNote: item.intake_note,
    prescriptionUrl: item.prescription_url,
    prescriptionFilename: item.prescription_filename,
    documentationUrl: item.documentation_url,
    documentationFilename: item.documentation_filename,
  };
}

/*
AppointmentDetails Component
* Displays a modal with appointment details including Zoom meeting info, clinical notes, prescription upload functionality, and intake notes.
* Allows healthcare providers to save session notes and upload prescriptions.
*/
export default function AppointmentDetails({
  appointment,
  onClose,
  onSaveStart,
  onSaveSuccess,
  onSaveError,
}: AppointmentDetailsProps) {
  const [notes, setNotes] = useState(appointment.clinicalNotes || "");
  const [uploadedPrescriptionFile, setUploadedPrescriptionFile] = useState<File | null>(null);
  const [uploadedDocumentationFile, setUploadedDocumentationFile] = useState<File | null>(null);
  const [toast, setToast] = useState<string | null>(null);
  const [copiedField, setCopiedField] = useState<"id" | "pass" | null>(null);
  const [hoveredField, setHoveredField] = useState<"id" | "pass" | null>(null);
  const saveStartedRef = useRef(false);
  const fileInputRef = useRef<HTMLInputElement>(null);
  const documentationInputRef = useRef<HTMLInputElement>(null);
 
  /*
  * Displays a temporary toast notification
  * @param msg - The message to display in the toast
  */
  function showToast(msg: string) {
    setToast(msg);
    setTimeout(() => setToast(null), 3000);
  }
 
  // Copies text to clipboard and updates the copied field state for visual feedback
  function handleCopy(text: string, field: "id" | "pass") {
    navigator.clipboard.writeText(text);
    setCopiedField(field);
    setTimeout(() => setCopiedField(null), 1800);
  }
 
  /*
  * Handles file selection from the file input
  * Validates file type and size before accepting
  */
  function handleFileChange(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    if (!file) return;
 
    // Allowed file types for prescription uploads
    const allowed = ["application/pdf", "image/jpeg", "image/png", "image/webp"];
    if (!allowed.includes(file.type)) {
      showToast("Only PDF, JPG, PNG, or WEBP files are supported.");
      return;
    }

    // Size validation - limit to 10MB
    if (file.size > 10 * 1024 * 1024) {
      showToast("File size must be under 10MB.");
      return;
    }
 
    setUploadedPrescriptionFile(file);
    showToast(`${file.name} attached.`);
    e.target.value = "";
  }

  function handleDocumentationFileChange(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    if (!file) return;

    const allowed = ["application/pdf", "image/jpeg", "image/png", "image/webp"];
    if (!allowed.includes(file.type)) {
      showToast("Only PDF, JPG, PNG, or WEBP files are supported.");
      return;
    }

    if (file.size > 10 * 1024 * 1024) {
      showToast("File size must be under 10MB.");
      return;
    }

    setUploadedDocumentationFile(file);
    showToast(`${file.name} attached.`);
    e.target.value = "";
  }
 
  /*
  * Saves clinical notes and uploads selected files via backend Cloudinary endpoints
  */
  async function handleSave() {
    if (saveStartedRef.current) {
      return;
    }

    saveStartedRef.current = true;
    onSaveStart?.();
    onClose();

    try {
      let prescriptionUpload: UploadedAppointmentFile | null = null;
      let documentationUpload: UploadedAppointmentFile | null = null;

      if (uploadedPrescriptionFile) {
        prescriptionUpload = await uploadAppointmentFile(uploadedPrescriptionFile, "prescription");
      }

      if (uploadedDocumentationFile) {
        documentationUpload = await uploadAppointmentFile(uploadedDocumentationFile, "documentation");
      }

      const updated = await backendRequest<BackendAppointment>(`/api/doctor/appointments/${appointment.id}/session`, {
        method: "PATCH",
        body: JSON.stringify({
          clinical_notes: notes,
          prescription_url: prescriptionUpload?.url,
          prescription_filename: prescriptionUpload?.filename,
          documentation_url: documentationUpload?.url,
          documentation_filename: documentationUpload?.filename,
        }),
      });

      onSaveSuccess?.(mapBackendAppointment(updated));
    } catch (error) {
      console.error(error);
      if (error instanceof Error) {
        onSaveError?.(error.message || "Failed to save session.");
      } else {
        onSaveError?.("Failed to save session.");
      }
    } finally {
      saveStartedRef.current = false;
    }
  }

  async function uploadAppointmentFile(
    file: File,
    category: "prescription" | "documentation",
  ): Promise<UploadedAppointmentFile> {
    const formData = new FormData();
    formData.append("file", file);

    return backendRequest<UploadedAppointmentFile>(
      `/api/doctor/appointments/${appointment.id}/files?category=${category}`,
      {
        method: "POST",
        body: formData,
      },
    );
  }
  
  // Formats file size in bytes to a human-readable string
  function formatBytes(bytes: number): string {
    if (bytes < 1024) return `${bytes} B`;
    if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
    return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
  }
 
  return (
    <>
      {/* Backdrop -  Semi-transparent overlay that closes modal when clicked */}
      <div
        className="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4 backdrop-blur-sm"
        onClick={(e) => { if (e.target === e.currentTarget) onClose(); }}
      >
        <div className="bg-gray-50 rounded-2xl w-full max-w-lg max-h-[90vh] flex flex-col shadow-2xl overflow-hidden">
 
          {/* Header */}
          <div className="bg-white border-b border-purple-50 px-6 py-5 flex items-start justify-between">
            <div className="flex items-center gap-3">

              {/* Icon */}
              <div className="w-10 h-10 rounded-xl bg-purple-50 border border-purple-100 flex items-center justify-center">
                <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="#7C3AED" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                  <path d="M15 10l4.553-2.069A1 1 0 0 1 21 8.82v6.361a1 1 0 0 1-1.447.894L15 14" />
                  <rect x="1" y="6" width="14" height="12" rx="2" />
                </svg>
              </div>
              <div>
                <h3 className="text-base font-bold text-[#1A1A2E]">Appointment Details</h3>
                <p className="text-sm text-gray-400">
                  Manage visit for <span className="text-[#7C3AED] font-semibold">{appointment.name}</span>
                </p>
              </div>
            </div>

            {/* Close Button */}
            <button
              onClick={onClose}
              className="text-gray-400 hover:text-gray-600 w-8 h-8 flex items-center justify-center rounded-lg hover:bg-gray-100 transition-colors"
            >
              ✕
            </button>
          </div>
 
          {/* Scrollable Body */}
          <div className="overflow-y-auto flex-1 p-5 flex flex-col gap-4">
 
            {/* Zoom Meeting Information */}
            <div className="bg-white rounded-xl border border-purple-50 p-4">
              <p className="text-[11px] font-bold text-gray-400 uppercase tracking-wider mb-3 flex items-center gap-1.5">
                <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                  <path d="M15 10l4.553-2.069A1 1 0 0 1 21 8.82v6.361a1 1 0 0 1-1.447.894L15 14" />
                  <rect x="1" y="6" width="14" height="12" rx="2" />
                </svg>
                Zoom Meeting Information
              </p>
 
              {/* Meeting ID and Passcode cards with copy functionality */}
              <div className="grid grid-cols-2 gap-3 mb-3">
                {[
                  { label: "Meeting ID", value: appointment.zoomMeetingId || "—", field: "id" as const },
                  { label: "Passcode", value: appointment.zoomPasscode || "—", field: "pass" as const },
                ].map(({ label, value, field }) => (
                  <div
                    key={field}
                    className="relative bg-gray-50 border border-gray-100 rounded-xl p-3 cursor-pointer"
                    onMouseEnter={() => setHoveredField(field)}
                    onMouseLeave={() => setHoveredField(null)}
                    onClick={() => handleCopy(value, field)}
                  >
                    <p className="text-[10px] text-gray-400 font-semibold mb-1"># {label.toUpperCase()}</p>
                    <p className="text-base font-bold text-[#1A1A2E] tracking-wide">{value}</p>

                    {/* Tooltip that appears on hover */}
                    {hoveredField === field && (
                      <span className={`absolute top-2 right-2 text-[10px] font-bold text-white px-2 py-0.5 rounded-md ${copiedField === field ? "bg-green-500" : "bg-[#7C3AED]"}`}>
                        {copiedField === field ? "Copied!" : "Copy"}
                      </span>
                    )}
                  </div>
                ))}
              </div>
 
              {/* Direct Zoom meeting link button */}
              <a
                href={`https://zoom.us/j/${appointment.zoomMeetingId?.replace(/\s/g, "")}?pwd=${appointment.zoomPasscode}`}
                target="_blank"
                rel="noopener noreferrer"
                className="flex items-center justify-center gap-2 w-full py-2.5 rounded-xl bg-[#7C3AED] text-white text-sm font-semibold hover:opacity-90 transition-opacity"
              >
                <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                  <path d="M18 13v6a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h6" />
                  <polyline points="15 3 21 3 21 9" />
                  <line x1="10" y1="14" x2="21" y2="3" />
                </svg>
                Join Zoom Meeting
              </a>
            </div>
 
            {/* Clinical Notes - Text area for session documentations */}
            <div className="bg-white rounded-xl border border-purple-50 p-4">
              <p className="text-[11px] font-bold text-gray-400 uppercase tracking-wider mb-3">
                Clinical Session Notes
              </p>
              <textarea
                value={notes}
                onChange={(e) => setNotes(e.target.value)}
                placeholder="Record symptoms, diagnosis, and plan here..."
                rows={4}
                className="w-full border border-gray-100 rounded-xl px-3 py-2.5 text-sm text-gray-700 outline-none focus:border-[#7C3AED] resize-y transition-colors"
              />
            </div>
 
            {/* Prescription Upload */}
            <div className="bg-white rounded-xl border border-purple-50 p-4">
              <p className="text-[11px] font-bold text-gray-400 uppercase tracking-wider mb-3">
                Prescription & Documentation
              </p>
 
              {/* Conditional rendering based on whether a file has been uploaded */}
              {!uploadedPrescriptionFile ? (
                // File upload dropzone - appears when no file is selected
                <div
                  onClick={() => fileInputRef.current?.click()}
                  className="border-2 border-dashed border-purple-200 rounded-xl p-8 text-center cursor-pointer hover:border-[#7C3AED] hover:bg-purple-50/30 transition-all"
                >
                  <div className="w-10 h-10 rounded-full bg-purple-50 flex items-center justify-center mx-auto mb-2">
                    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="#7C3AED" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                      <polyline points="16 16 12 12 8 16" />
                      <line x1="12" y1="12" x2="12" y2="21" />
                      <path d="M20.39 18.39A5 5 0 0 0 18 9h-1.26A8 8 0 1 0 3 16.3" />
                    </svg>
                  </div>
                  <p className="text-[#7C3AED] text-sm font-semibold">Upload Prescription</p>
                  <p className="text-gray-400 text-xs mt-1">PDF, JPG or PNG (Max 5MB)</p>
                </div>
              ) : (

                // File preview card - appears after file upload
                <div className="flex items-center gap-3 bg-green-50 border border-green-200 rounded-xl px-4 py-3">
                  <div className="w-9 h-9 rounded-lg bg-green-100 flex items-center justify-center text-lg shrink-0">
                    {uploadedPrescriptionFile.type === "application/pdf" ? "📄" : "🖼️"}
                  </div>
                  <div className="flex-1 min-w-0">
                    <p className="text-sm font-semibold text-green-800 truncate">{uploadedPrescriptionFile.name}</p>
                    <p className="text-xs text-green-500 mt-0.5">✓ Uploaded · {formatBytes(uploadedPrescriptionFile.size)}</p>
                  </div>

                  {/* Remove file button */}
                  <button
                    onClick={() => setUploadedPrescriptionFile(null)}
                    className="w-7 h-7 flex items-center justify-center rounded-lg bg-red-100 text-red-500 hover:bg-red-200 transition-colors shrink-0"
                  >
                    ✕
                  </button>
                </div>
              )}

              {appointment.prescriptionUrl && !uploadedPrescriptionFile && (
                <a
                  href={appointment.prescriptionUrl}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="mt-3 inline-flex items-center gap-2 text-sm text-[#7C3AED] font-medium hover:underline"
                >
                  View current prescription ({appointment.prescriptionFilename || "file"})
                </a>
              )}
 
              {/* Hidden file input triggered by the dropzone */}
              <input
                ref={fileInputRef}
                type="file"
                accept=".pdf,.jpg,.jpeg,.png,.webp"
                onChange={handleFileChange}
                className="hidden"
              />
            </div>

            <div className="bg-white rounded-xl border border-purple-50 p-4">
              <p className="text-[11px] font-bold text-gray-400 uppercase tracking-wider mb-3">
                Additional Documentation
              </p>

              {!uploadedDocumentationFile ? (
                <div
                  onClick={() => documentationInputRef.current?.click()}
                  className="border-2 border-dashed border-purple-200 rounded-xl p-8 text-center cursor-pointer hover:border-[#7C3AED] hover:bg-purple-50/30 transition-all"
                >
                  <div className="w-10 h-10 rounded-full bg-purple-50 flex items-center justify-center mx-auto mb-2">
                    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="#7C3AED" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                      <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4" />
                      <polyline points="7 10 12 15 17 10" />
                      <line x1="12" y1="15" x2="12" y2="3" />
                    </svg>
                  </div>
                  <p className="text-[#7C3AED] text-sm font-semibold">Upload Documentation</p>
                  <p className="text-gray-400 text-xs mt-1">PDF, JPG, PNG, WEBP (Max 10MB)</p>
                </div>
              ) : (
                <div className="flex items-center gap-3 bg-green-50 border border-green-200 rounded-xl px-4 py-3">
                  <div className="w-9 h-9 rounded-lg bg-green-100 flex items-center justify-center text-lg shrink-0">
                    {uploadedDocumentationFile.type === "application/pdf" ? "📄" : "🖼️"}
                  </div>
                  <div className="flex-1 min-w-0">
                    <p className="text-sm font-semibold text-green-800 truncate">{uploadedDocumentationFile.name}</p>
                    <p className="text-xs text-green-500 mt-0.5">✓ Uploaded · {formatBytes(uploadedDocumentationFile.size)}</p>
                  </div>
                  <button
                    onClick={() => setUploadedDocumentationFile(null)}
                    className="w-7 h-7 flex items-center justify-center rounded-lg bg-red-100 text-red-500 hover:bg-red-200 transition-colors shrink-0"
                  >
                    ✕
                  </button>
                </div>
              )}

              {appointment.documentationUrl && !uploadedDocumentationFile && (
                <a
                  href={appointment.documentationUrl}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="mt-3 inline-flex items-center gap-2 text-sm text-[#7C3AED] font-medium hover:underline"
                >
                  View current documentation ({appointment.documentationFilename || "file"})
                </a>
              )}

              <input
                ref={documentationInputRef}
                type="file"
                accept=".pdf,.jpg,.jpeg,.png,.webp"
                onChange={handleDocumentationFileChange}
                className="hidden"
              />
            </div>
 
            {/* Original Intake Note */}
            {appointment.intakeNote && (
              <div className="bg-white rounded-xl border border-purple-50 p-4">
                <p className="text-[11px] font-bold text-gray-400 uppercase tracking-wider mb-3">
                  Original Intake Note
                </p>
                <div className="bg-gray-50 border-l-4 border-purple-200 rounded-r-xl px-4 py-3 text-sm text-gray-500 leading-relaxed italic">
                  &ldquo;{appointment.intakeNote}&rdquo;
                </div>
              </div>
            )}
          </div>
 
          {/* Footer */}
          <div className="bg-white border-t border-gray-100 px-5 py-4 flex gap-3">
            <button
              onClick={onClose}
              className="flex-1 py-2.5 rounded-xl border border-gray-200 text-gray-600 text-sm font-semibold hover:bg-gray-50 transition-colors"
            >
              Cancel
            </button>
            <button
              onClick={handleSave}
              className="flex-2 py-2.5 rounded-xl bg-[#7C3AED] text-white text-sm font-semibold hover:opacity-90 transition-opacity"
            >
              Save Session
            </button>
          </div>
        </div>
      </div>
 
      {/* Toast Notification */}
      {toast && (
        <div className="fixed bottom-6 right-6 z-60 bg-green-500 text-white text-sm font-medium px-4 py-3 rounded-xl shadow-lg flex items-center gap-2">
          <span>✓</span>
          <span>{toast}</span>
        </div>
      )}
    </>
  );
}