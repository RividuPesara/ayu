"use client";

import React from "react";
 
export interface Appointment {
  id: string;
  name: string;
  time: string;
  type: string;
  status: "done" | "upcoming" | "overdue";
  date?: string;
  zoomMeetingId?: string;
  zoomPasscode?: string;
  clinicalNotes?: string;
  intakeNote?: string;
  prescriptionUrl?: string;
  prescriptionFilename?: string;
  documentationUrl?: string;
  documentationFilename?: string;
}

interface TimelineProps {
  appointments: Appointment[];
  isLoading: boolean;
  onJoinSession: (appointment: Appointment) => void;
  onStatusChange: (id: string, status: "done" | "upcoming" | "overdue") => void;
}
 
function getInitials(name: string): string {
  return name
    .split(" ")
    .map((n) => n[0])
    .join("")
    .toUpperCase()
    .slice(0, 2);
}

function parseTimeToMinutes(rawTime: string): number | null {
  const normalized = rawTime.trim().toLowerCase().replace(/\./g, ":");
  const match = normalized.match(/^(\d{1,2}):(\d{2})(?:\s*([ap]m))?$/);
  if (!match) {
    return null;
  }

  let hour = Number(match[1]);
  const minute = Number(match[2]);
  const amPm = match[3];

  if (Number.isNaN(hour) || Number.isNaN(minute) || minute > 59) {
    return null;
  }

  if (amPm) {
    if (hour < 1 || hour > 12) {
      return null;
    }

    if (amPm === "am") {
      hour = hour === 12 ? 0 : hour;
    } else {
      hour = hour === 12 ? 12 : hour + 12;
    }
  } else if (hour > 23) {
    return null;
  }

  return hour * 60 + minute;
}

function parseDateKeyToDate(dateKey?: string): Date | null {
  if (!dateKey) {
    return null;
  }

  const match = dateKey.match(/^(\d{4})-(\d{2})-(\d{2})$/);
  if (!match) {
    return null;
  }

  const year = Number(match[1]);
  const monthIndex = Number(match[2]) - 1;
  const day = Number(match[3]);

  const parsed = new Date(year, monthIndex, day);
  if (
    parsed.getFullYear() !== year ||
    parsed.getMonth() !== monthIndex ||
    parsed.getDate() !== day
  ) {
    return null;
  }

  return parsed;
}

function buildAppointmentDateTime(appointment: Appointment): Date | null {
  const minutes = parseTimeToMinutes(appointment.time);
  if (minutes === null) {
    return null;
  }

  const today = new Date();
  const appointmentDate =
    parseDateKeyToDate(appointment.date) ||
    new Date(today.getFullYear(), today.getMonth(), today.getDate());

  appointmentDate.setHours(Math.floor(minutes / 60), minutes % 60, 0, 0);
  return appointmentDate;
}
 
function getLateMinutes(appointment: Appointment): number {
  const appointmentDateTime = buildAppointmentDateTime(appointment);
  if (!appointmentDateTime) {
    return 0;
  }

  const diffMs = Date.now() - appointmentDateTime.getTime();
  return Math.max(0, Math.floor(diffMs / 60000));
}
 
function AppointmentCard({
  appointment,
  onJoinSession,
  onStatusChange,
}: {
  appointment: Appointment;
  onJoinSession: (a: Appointment) => void;
  onStatusChange: (
    id: string,
    status: "done" | "upcoming" | "overdue"
  ) => void;
}) {
  const { name, time, type, status } = appointment;
  const isOverdue = status === "overdue";
  const isDone = status === "done";
  const lateMinutes = isOverdue ? getLateMinutes(appointment) : 0;
 
  const dotColor = isDone ? "bg-gray-300" : isOverdue ? "bg-red-500" : "bg-[#7C3AED]";

  const btnColor = isDone
    ? "bg-gray-200 text-gray-400 cursor-not-allowed" : isOverdue 
    ? "bg-red-500 text-white hover:opacity-90" : "bg-[#7C3AED] text-white hover:opacity-90";

  const handleDone = (e: React.MouseEvent) => {
    e.stopPropagation();
    onStatusChange(appointment.id, 'done');
  };

  const handleUndo = (e: React.MouseEvent) => {
    e.stopPropagation();
    const appointmentDateTime = buildAppointmentDateTime(appointment);
    const newStatus =
      appointmentDateTime && appointmentDateTime.getTime() < Date.now()
        ? "overdue"
        : "upcoming";
    onStatusChange(appointment.id, newStatus);
  };
 
  return (
    <div className="flex items-center gap-0">
      {/* Time */}
      <div 
        className={`w-12 text-xs font-semibold shrink-0 ${isDone ? "text-gray-200 line-through" : "text-gray-500"}`}>
        {time}
      </div>
 
      {/* Dot on the line */}
      <div className="relative shrink-0 mr-3">
        {/* Outer dot (glow effect) */}
        <div className={`absolute w-4 h-4 rounded-full ${dotColor} opacity-20`} style={{ top: '-4px', left: '-4px' }} />
        {/* Inner dot (main dot) */}
        <div className={`w-2 h-2 rounded-full relative z-10 ${dotColor}`} />
      </div>

      {/* Card */}
      <div
        className={`flex-1 flex items-center gap-3 px-3 py-5 rounded-xl border transition-all
          ${isDone ? "bg-gray-50 border-transparent opacity-60" : "bg-white border-gray-100 hover:border-purple-100 hover:bg-purple-50/30 hover:translate-x-1 hover:shadow-sm"}`}>
        
        {/* Avatar */}
        <div className={`w-11 h-11 rounded-full flex items-center justify-center text-xs font-bold shrink-0 text-[17px]
          ${isDone ? "bg-gray-200 text-gray-400" : isOverdue ? "bg-red-100 text-red-500" : "bg-purple-100 text-[#7C3AED]"}`}>
          {getInitials(name)}
        </div>
 
        {/* Info */}
        <div className="flex-1 min-w-0">
          <p className={`text-sm text-[15px] font-semibold truncate ${isDone ? "text-gray-400 line-through" : "text-[#1A1A2E]"}`}>
            {name}
          </p>
          <div className="flex items-center gap-2 mt-0.5">
            {isOverdue && lateMinutes > 0 && (
              <span className="text-[11px] text-red-500 font-semibold flex items-center gap-1">
                <svg width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                  <circle cx="12" cy="12" r="10" /><line x1="12" y1="8" x2="12" y2="12" /><line x1="12" y1="16" x2="12.01" y2="16" />
                </svg>
                {lateMinutes}m Late
              </span>
            )}
            {isDone && <span className="text-[11px] text-green-500 font-semibold">DONE</span>}
            <span className="text-[11px] text-gray-400 flex items-center gap-1">
              <svg width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                <path d="M15 10l4.553-2.069A1 1 0 0 1 21 8.82v6.361a1 1 0 0 1-1.447.894L15 14" />
                <rect x="1" y="6" width="14" height="12" rx="2" />
              </svg>
              {type}
            </span>
          </div>
        </div>
 
        {/* Status + button */}
        <div className="flex items-center gap-5 shrink-0">
          {!isDone && (
            <button onClick={handleDone}>
              <span className="text-[14px] text-green-500 font-semibold flex items-center gap-1 cursor-pointer transition-opacity">
                <svg width="11" height="11" viewBox="0 0 25 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                  <circle cx="12" cy="12" r="9" />
                </svg>
                Done
              </span>
            </button>
          )}

          {isDone && (
            <button onClick={handleUndo}>
              <span className="text-[14px] text-gray-400 flex items-center gap-1 cursor-pointer">
                <svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                  <circle cx="12" cy="12" r="9" />
                </svg>
                Undo
              </span>
            </button>
          )}

          <button
            disabled={isDone}
            onClick={(e) => { e.stopPropagation(); if (!isDone) { onJoinSession(appointment); } }}
            className={`flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs text-[13px] font-semibold transition-opacity ${btnColor} cursor-pointer`}>
            <svg width="10" height="10" viewBox="0 0 24 24" fill="currentColor">
              <polygon points="5 3 19 12 5 21 5 3" />
            </svg>
            Join Session
          </button>
        </div>
      </div>
    </div>
  );
}
 
export default function Timeline({ appointments, isLoading, onJoinSession, onStatusChange }: TimelineProps) {

  const sortByTime = (a: Appointment, b: Appointment) => {
    const aMinutes = parseTimeToMinutes(a.time);
    const bMinutes = parseTimeToMinutes(b.time);

    if (aMinutes !== null && bMinutes !== null) {
      return aMinutes - bMinutes;
    }

    if (aMinutes !== null) {
      return -1;
    }

    if (bMinutes !== null) {
      return 1;
    }

    return a.time.localeCompare(b.time);
  };

  const overdue = appointments.filter((a) => a.status === "overdue").sort(sortByTime);
  const upcoming = appointments.filter((a) => a.status === "upcoming").sort(sortByTime);
  const done = appointments.filter((a) => a.status === "done").sort(sortByTime);
 
  if (isLoading) {
    return (
      <div className="bg-white rounded-2xl shadow-sm border border-gray-100 p-16 text-center">
        <p className="text-gray-500 font-semibold">
          Loading appointments...
        </p>
      </div>
    );
  }

  if (appointments.length === 0) {
    return (
      <div className="bg-white rounded-2xl shadow-sm border border-gray-100 p-16 text-center">
        <p className="text-gray-500 font-semibold">
          No appointments available
        </p>
      </div>
    );
  }
 
  const sections = [
    { label: "OVERDUE", color: "text-red-500", bg: "bg-red-50", items: overdue },
    { label: "UPCOMING", color: "text-[#7C3AED]", bg: "bg-purple-50", items: upcoming, badge: upcoming.length > 0 ? `${upcoming.length} Left` : null },
    { label: "DONE", color: "text-green-500", bg: "bg-green-50", items: done },
  ].filter((s) => s.items.length > 0);
 
  return (
    <div className="bg-white rounded-2xl shadow-sm border border-gray-100 px-6 py-5">
      {/* Header */}
      <div className="flex items-center justify-between mb-5">
        <div className="flex items-center gap-3">
          <h2 className="text-base font-bold text-[#1A1A2E]">Timeline</h2>
          <div className="h-px w-10 bg-gray-200" />
        </div>
      </div>
 
      {/* Sections */}
      <div className="flex flex-col gap-6">
        {sections.map((section) => (
          <div key={section.label}>
            {/* Section label */}
            <div className="flex items-center gap-2 mb-3">
              <span className={`text-[11px] font-bold tracking-wider px-3 py-1 rounded-full ${section.color} ${section.bg}`}>
                {section.label}
              </span>
              {"badge" in section && section.badge && (
                <span className="text-[11px] text-gray-400 bg-gray-100 px-2 py-0.5 rounded-full">
                  {section.badge}
                </span>
              )}
            </div>
 
            {/* Cards with vertical line */}
            <div className="relative pl-0">
              <div className="absolute left-12.75 top-0 bottom-0 w-0.5 bg-[#D3D3D3] rounded-full" />
              <div className="flex flex-col gap-2">
                {section.items.map((appt) => (
                  <AppointmentCard
                    key={appt.id}
                    appointment={appt}
                    onJoinSession={onJoinSession}
                    onStatusChange={onStatusChange}
                  />
                ))}
              </div>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}