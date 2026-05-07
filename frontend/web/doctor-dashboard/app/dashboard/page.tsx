"use client";

import React, { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { useRouter } from "next/navigation";
import { onAuthStateChanged, signOut } from "firebase/auth";
import Header from "./components/header";
import Calendar from "./components/calendar";
import Stats from "./components/stats";
import Timeline from "./components/timeline";
import AppointmentDetails from "./components/appointmentdetails";
import PastAppointments from "./components/pastappointments";
import { auth } from "@/app/lib/firebase";
import { backendRequest, UnauthenticatedError } from "@/app/lib/backend-api";

import { Appointment } from "./components/timeline";

interface DashboardProfile {
  full_name?: string | null;
  specialty?: string | null;
  phone?: string | null;
  avatar_url?: string | null;
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

// Format date to YYYY-MM-DD
const toDateKey = (date: Date) => {
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, "0");
  const day = String(date.getDate()).padStart(2, "0");
  return `${year}-${month}-${day}`;
};

export default function DashboardPage() {
  const router = useRouter();

  const today = new Date();

  const [isDashboardReady, setIsDashboardReady] = useState(false);
  const [isAppointmentsLoading, setIsAppointmentsLoading] = useState(true);
  const [doctorName, setDoctorName] = useState("Doctor");
  const [doctorSpecialty, setDoctorSpecialty] = useState("");
  const [doctorPhone, setDoctorPhone] = useState("");
  const [doctorAvatar, setDoctorAvatar] = useState("/assets/avatar.png");
  const [allAppointments, setAllAppointments] = useState<Appointment[]>([]);
  const [toast, setToast] = useState<{ message: string; type: "success" | "error" | "info" } | null>(null);
  const [showPastAppointments, setShowPastAppointments] = useState(false);
  const [pastAppointmentSource, setPastAppointmentSource] = useState<Appointment | null>(null);
  const [selectedDate, setSelectedDate] = useState<Date>(today);
  const [selectedAppointment, setSelectedAppointment] = useState<Appointment | null>(null);
  const selectedDateKey = toDateKey(selectedDate);
  const autoLogoutTimer = useRef<number | null>(null);
  const AUTO_LOGOUT_IDLE_MS = 60* 60 * 1000; //  60mins

  const redirectToLogin = useCallback(() => {
    setIsAppointmentsLoading(false);
    setIsDashboardReady(false);
    router.replace("/login");
  }, [router]);

  const showToast = useCallback((message: string, type: "success" | "error" | "info") => {
    setToast({ message, type });
    setTimeout(() => setToast(null), 3000);
  }, []);

  const scheduleAutoLogout = useCallback(() => {
    if (autoLogoutTimer.current) {
      window.clearTimeout(autoLogoutTimer.current);
    }

    autoLogoutTimer.current = window.setTimeout(async () => {
      try {
        await signOut(auth);
      } finally {
        showToast("You were logged out due to inactivity.", "info");
        redirectToLogin();
      }
    }, AUTO_LOGOUT_IDLE_MS);
  }, [redirectToLogin, showToast]);

  const selectedDateAppointments = useMemo(() => {
    return allAppointments.filter((appointment) => appointment.date === selectedDateKey);
  }, [allAppointments, selectedDateKey]);

  const handleStatusChange = async (
    id: string,
    status: "done" | "upcoming" | "overdue"
  ) => {
    const originalAppointment = allAppointments.find((appointment) => appointment.id === id);
    if (!originalAppointment) {
      return;
    }

    setAllAppointments((prev) =>
      prev.map((appointment) =>
        appointment.id === id ? { ...appointment, status } : appointment
      )
    );

    setSelectedAppointment((prev) =>
      prev && prev.id === id ? { ...prev, status } : prev
    );

    try {
      const updated = await backendRequest<BackendAppointment>(
        `/api/doctor/appointments/${id}/status`,
        {
          method: "PATCH",
          body: JSON.stringify({ status }),
        }
      );

      const updatedMapped = mapBackendAppointment(updated);
      setAllAppointments((prev) =>
        prev.map((appointment) =>
          appointment.id === id ? updatedMapped : appointment
        )
      );

      setSelectedAppointment((prev) =>
        prev && prev.id === id ? updatedMapped : prev
      );
    } catch (error) {
      console.error(error);

      setAllAppointments((prev) =>
        prev.map((appointment) =>
          appointment.id === id ? originalAppointment : appointment
        )
      );

      setSelectedAppointment((prev) =>
        prev && prev.id === id ? originalAppointment : prev
      );

      showToast("Failed to update appointment status.", "error");
    }
  };

  const handlePastAppointments = (appointment: Appointment) => {
    setPastAppointmentSource(appointment);
    setShowPastAppointments(true);
  };

  useEffect(() => {
    let isMounted = true;
    let isBootstrapping = false;

    async function bootstrapDashboard() {
      if (isBootstrapping) {
        return;
      }

      isBootstrapping = true;

      try {
        const [profile, appointments] = await Promise.all([
          backendRequest<DashboardProfile>("/api/doctor/profile"),
          backendRequest<BackendAppointment[]>("/api/doctor/appointments"),
        ]);

        if (!isMounted) {
          return;
        }

        setDoctorName(profile.full_name?.trim() || "Doctor");
        setDoctorSpecialty(profile.specialty?.trim() || "");
        setDoctorPhone(profile.phone?.trim() || "");
        if (profile.avatar_url) {
          setDoctorAvatar(profile.avatar_url);
        }

        setAllAppointments(appointments.map(mapBackendAppointment));
        setIsAppointmentsLoading(false);
        setIsDashboardReady(true);
      } catch (error) {
        if (!isMounted) {
          return;
        }

        if (error instanceof UnauthenticatedError) {
          redirectToLogin();
          return;
        }

        console.error(error);
        setAllAppointments([]);
        setIsAppointmentsLoading(false);
        setIsDashboardReady(true);
      } finally {
        isBootstrapping = false;
      }
    }

    const unsubscribe = onAuthStateChanged(auth, (user) => {
      if (!isMounted) {
        return;
      }

      if (!user) {
        redirectToLogin();
        return;
      }

      scheduleAutoLogout();
      bootstrapDashboard();
    });

    const activityEvents = [
      "mousemove",
      "mousedown",
      "keydown",
      "scroll",
      "touchstart",
    ];

    const handleUserActivity = () => {
      if (auth.currentUser) {
        scheduleAutoLogout();
      }
    };

    activityEvents.forEach((eventName) =>
      window.addEventListener(eventName, handleUserActivity),
    );

    return () => {
      isMounted = false;
      unsubscribe();
      if (autoLogoutTimer.current) {
        window.clearTimeout(autoLogoutTimer.current);
      }
      activityEvents.forEach((eventName) =>
        window.removeEventListener(eventName, handleUserActivity),
      );
    };
  }, [redirectToLogin, scheduleAutoLogout]);

  if (!isDashboardReady) {
    return (
      <div className="min-h-screen bg-[#F1F5F9] flex items-center justify-center">
        <div className="flex flex-col items-center gap-3">
          <div className="w-10 h-10 rounded-full border-4 border-[#694EBC]/20 border-t-[#694EBC] animate-spin" />
          <p className="text-sm font-semibold text-[#483674]">Loading dashboard...</p>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-[#F1F5F9]">

      {/* Hero Banner */}
      <div
        className="pb-20 pt-4 relative overflow-hidden"
        style={{ background: "#483674" }}
      >

        <div className="absolute -right-10 -top-24 w-80 h-80 rounded-full bg-white/5" />
        <div className="absolute right-24 -bottom-10 w-48 h-48 rounded-full bg-white/5" />

        <div className="absolute top-0 left-0 right-0 z-10 pt-4">
          <Header
            initialProfile={{
              name: doctorName,
              specialty: doctorSpecialty,
              phone: doctorPhone,
              avatar: doctorAvatar,
            }}
          />
        </div>

        <div className="max-w-7xl mx-auto px-8 pt-24 text-white">
          <p className="text-sm font-bold text-white/70 uppercase tracking-widest mb-1">
            Hi, Dr. {doctorName}
          </p>

          <h2 className="text-5xl font-extrabold tracking-tight mb-2">
            Daily Schedule
          </h2>
        </div>
      </div>


      {/* Main Content */}
      <div className="max-w-7xl w-full mx-auto px-6 pb-16 -mt-14 flex flex-col relative gap-5">

        {/* Stats */}
        <Stats
          selectedDate={selectedDateKey}
          appointments={allAppointments}
          isLoading={isAppointmentsLoading}
        />

        {/* Calendar */}
        <Calendar
          selectedDate={selectedDate}
          onDateSelect={setSelectedDate}
        />

        {/* Timeline */}
        <Timeline
          appointments={selectedDateAppointments}
          isLoading={isAppointmentsLoading}
          onStatusChange={handleStatusChange}
          onJoinSession={(appt) => setSelectedAppointment(appt)}
          onPastAppointments={handlePastAppointments}
        />

      </div>

      {/* Past Appointment Details */}
      {showPastAppointments && pastAppointmentSource && (
        <PastAppointments
          patientName={pastAppointmentSource.name}
          appointments={allAppointments.filter(
            (a) => a.name === pastAppointmentSource.name && (a.status === "done" || a.status === "overdue")
          )}
          onClose={() => {
            setShowPastAppointments(false);
            setPastAppointmentSource(null);
          }}
        />
      )}

      {/* Appointment Details */}
      {selectedAppointment && (
        <AppointmentDetails
          appointment={selectedAppointment}
          onClose={() => setSelectedAppointment(null)}
          onSaveStart={() => showToast("Saving session in background...", "info")}
          onSaveSuccess={(updatedAppointment) => {
            setAllAppointments((prev) =>
              prev.map((appointment) =>
                appointment.id === updatedAppointment.id ? updatedAppointment : appointment
              )
            );

            setSelectedAppointment((prev) =>
              prev && prev.id === updatedAppointment.id ? updatedAppointment : prev
            );

            showToast("Session saved successfully.", "success");
          }}
          onSaveError={(message) => showToast(message, "error")}
        />
      )}

      {toast && (
        <div
          className={`fixed bottom-6 right-6 z-70 flex items-center gap-3 px-4 py-3 rounded-xl shadow-lg text-white text-sm font-medium ${
            toast.type === "success"
              ? "bg-green-500"
              : toast.type === "error"
                ? "bg-red-500"
                : "bg-[#1A1A2E]"
          }`}
        >
          <span>{toast.type === "success" ? "✓" : toast.type === "error" ? "✕" : "ℹ"}</span>
          <span>{toast.message}</span>
        </div>
      )}

    </div>
  );
}