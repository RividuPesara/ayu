"use client";

import React, { useState } from "react";
import Header from "./components/header";
import Calendar from "./components/calendar";
import Stats from "./components/stats";
import Timeline from "./components/timeline";
import AppointmentDetails from "./components/appointmentdetails";

import { Appointment } from "./components/timeline";

// Format date to YYYY-MM-DD
const toDateKey = (date: Date) => {
  return date.toISOString().split("T")[0];
};

export default function DashboardPage() {

  const today = new Date();

  const [selectedDate, setSelectedDate] = useState<Date>(today);
  const [selectedAppointment, setSelectedAppointment] = useState<Appointment | null>(null);

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
          <Header />
        </div>

        <div className="max-w-7xl mx-auto px-8 pt-24 text-white">
          <p className="text-sm font-bold text-white/70 uppercase tracking-widest mb-1">
            Hi, Dr. M
          </p>

          <h2 className="text-5xl font-extrabold tracking-tight mb-2">
            Daily Schedule
          </h2>
        </div>
      </div>


      {/* Main Content */}
      <div className="max-w-7xl w-full mx-auto px-6 pb-16 -mt-14 flex flex-col relative gap-5">

        {/* Stats */}
        <Stats />

        {/* Calendar */}
        <Calendar
          selectedDate={selectedDate}
          onDateSelect={setSelectedDate}
        />

        {/* Timeline */}
        <Timeline
          onJoinSession={(appt) => setSelectedAppointment(appt)}
        />

      </div>

      {/* Appointment Details */}
      {selectedAppointment && (
        <AppointmentDetails
          appointment={selectedAppointment}
          onClose={() => setSelectedAppointment(null)}
        />
      )}

    </div>
  );
}