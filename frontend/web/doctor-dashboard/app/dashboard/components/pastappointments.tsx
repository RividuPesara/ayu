"use client";

import { useState } from "react";
import { Appointment } from "./timeline";

interface PastAppointmentsProps {
  patientName: string;
  appointments: Appointment[];
  onClose: () => void;
}

function statusLabel(status: Appointment["status"]): string {
  return status === "done" ? "Completed" : "Overdue";
}

function statusClass(status: Appointment["status"]): string {
  return status === "done"
    ? "bg-green-100 text-green-600"
    : "bg-amber-100 text-amber-600";
}

export default function PastAppointments({ patientName, appointments, onClose }: PastAppointmentsProps) {
  const [selected, setSelected] = useState<Appointment | null>(null);

  return (
    <div
      className="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4 backdrop-blur-sm"
      onClick={(e) => {
        if (e.target === e.currentTarget) onClose();
      }}
    >
      <div className="bg-gray-50 rounded-2xl w-full max-w-lg max-h-[90vh] flex flex-col shadow-2xl overflow-hidden">

        {/* LIST */}
        {!selected && (
          <div className="flex flex-col flex-1 min-h-0">

            {/* HEADER */}
            <div className="bg-white border-b border-purple-50 px-6 py-5 flex items-start justify-between">
              <div className="flex items-center gap-3">

                {/* Icon */}
                <div className="w-10 h-10 rounded-xl bg-purple-50 border border-purple-100 flex items-center justify-center">
                  <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="#7C3AED" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                    <circle cx="12" cy="12" r="11" />
                    <polyline points="12 6 12 12 16 14" />
                  </svg>
                </div>
                <div>
                  <h3 className="text-base font-bold text-[#1A1A2E]">History: {patientName}</h3>
                  <p className="text-sm text-gray-400">
                    Select a past appointment to view details.
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
            <div className="flex-1 min-h-0 overflow-y-auto p-5 pr-3 flex flex-col gap-4">
              <div className="bg-white rounded-xl border border-purple-100 p-4">
                {appointments.length === 0 ? (
                  <p className="text-sm text-gray-400 text-center py-4">No past appointments found.</p>
                ) : (
                  <div className="space-y-3">
                    {appointments.map((item) => (
                      <div
                        key={item.id}
                        onClick={() => setSelected(item)}
                        className="flex items-center justify-between p-4 border rounded-xl cursor-pointer hover:bg-gray-50 transition"
                      >
                        <div>
                          <p className="text-[13px] font-bold text-gray-400 uppercase tracking-wider mb-3 flex items-center gap-1.5">
                            <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                              <rect x="3" y="4" width="18" height="18" rx="2" ry="2" />
                              <line x1="16" y1="2" x2="16" y2="6" />
                              <line x1="8" y1="2" x2="8" y2="6" />
                              <line x1="3" y1="10" x2="21" y2="10" />
                            </svg>
                            {item.date}</p>
                          <p className="text-[12px] font-bold text-gray-500">{item.time}</p>
                        </div>

                        <span className={`text-[10px] font-bold px-2 py-1 rounded-full ${statusClass(item.status)}`}>
                          {statusLabel(item.status)}
                        </span>
                      </div>
                    ))}
                  </div>
                )}
              </div>
            </div>
          </div>
        )}

        {/* DETAILS */}
        {selected && (
          <div className="flex flex-col flex-1 min-h-0">

            {/* HEADER */}
            <div className="bg-white border-b border-purple-50 px-6 py-5 flex items-start justify-between">
              <div className="flex items-center gap-3">
                 {/* Icon */}
                <button
                  onClick={() => setSelected(null)}
                  className="text-sm text-gray-400 hover:text-gray-600 w-8 h-8 flex items-center justify-center rounded-lg hover:bg-gray-100 transition-colors">
                  <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                    <path d="M15 18l-6-6 6-6" />
                    </svg>
                </button>
                <div>
                  <h3 className="text-base font-bold text-[#1A1A2E]">Session Details</h3>
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
            <div className="flex-1 min-h-0 overflow-y-auto p-5 pr-3 flex flex-col gap-4">

              <div className="bg-white rounded-xl border border-purple-100 p-4 flex items-center justify-between gap-3">
                <div className="flex items-center gap-2">
                  <svg className="text-gray-400" width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                    <rect x="3" y="4" width="18" height="18" rx="2" ry="2" />
                    <line x1="16" y1="2" x2="16" y2="6" />
                    <line x1="8" y1="2" x2="8" y2="6" />
                    <line x1="3" y1="10" x2="21" y2="10" />
                  </svg>
                  <p className="text-sm text-gray-400">
                    {selected.date} • {selected.time}
                  </p>
                </div>

                <span className={`text-[12px] px-2 py-1 rounded-full ${statusClass(selected.status)}`}>
                  {statusLabel(selected.status)}
                </span>
              </div>

              {/* CLINICAL NOTES */}
              <div className="mb-4">
                <p className="text-[11px] font-bold text-gray-400 uppercase tracking-wider mb-3">
                  CLINICAL RECORDS
                </p>

                <div className="text-gray-600 bg-white rounded-xl border border-purple-100 p-4">
                  {selected.clinicalNotes || <span className="text-gray-400 italic">No clinical notes recorded.</span>}
                </div>
              </div>

              {/* PRESCRIPTION */}
              <div className="mb-4">
                <p className="text-[11px] font-bold text-gray-400 uppercase tracking-wider mb-3">
                  PRESCRIPTION
                </p>

                <div className="bg-white rounded-xl border border-purple-100 p-4">
                  {selected.prescriptionUrl ? (
                    <a
                      href={selected.prescriptionUrl}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="inline-flex items-center gap-2 text-sm text-[#7C3AED] font-medium hover:underline"
                    >
                      <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                        <path d="M18 13v6a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h6" />
                        <polyline points="15 3 21 3 21 9" />
                        <line x1="10" y1="14" x2="21" y2="3" />
                      </svg>
                      {selected.prescriptionFilename || "View prescription"}
                    </a>
                  ) : (
                    <p className="text-gray-400 italic text-sm">No prescription attached.</p>
                  )}
                </div>
              </div>

              {/* DOCUMENTS */}
              <div>
                <p className="text-[11px] font-bold text-gray-400 uppercase tracking-wider mb-3">
                  MEDICAL DOCUMENTS
                </p>

                <div className="bg-white rounded-xl border border-purple-100 p-4">
                  {selected.documentationUrl ? (
                    <a
                      href={selected.documentationUrl}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="inline-flex items-center gap-2 text-sm text-[#7C3AED] font-medium hover:underline"
                    >
                      <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                        <path d="M18 13v6a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h6" />
                        <polyline points="15 3 21 3 21 9" />
                        <line x1="10" y1="14" x2="21" y2="3" />
                      </svg>
                      {selected.documentationFilename || "View documentation"}
                    </a>
                  ) : (
                    <p className="text-gray-400 italic text-sm">No documents attached.</p>
                  )}
                </div>
              </div>

              {/* FOOTER */}
              <button
                onClick={onClose}
                className="flex-2 py-2.5 rounded-xl bg-[#7C3AED] text-white text-sm font-semibold hover:opacity-90 transition-opacity"
              >
                Close Records
              </button>
            </div>
          </div>
        )}

      </div>
    </div>
  );
}
