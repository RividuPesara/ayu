"use client";
 
import React, { useMemo } from "react";
import { Appointment } from "./timeline";

interface StatsProps {
  selectedDate: string;
  appointments: Appointment[];
  isLoading: boolean;
}

interface DerivedDashboardSummary {
  total_for_date: number;
  overdue_for_date: number;
  upcoming_for_date: number;
  done_for_date: number;
  done_all: number;
  total_all: number;
  weekly_count: number[];
}

function parseSundayBasedIndex(dateKey: string): number | null {
  const parts = dateKey.split("-");
  if (parts.length !== 3) {
    return null;
  }

  const [year, month, day] = parts.map(Number);
  if (!year || !month || !day) {
    return null;
  }

  return new Date(Date.UTC(year, month - 1, day)).getUTCDay();
}
 
// Simple SVG ring for circular progress
function Ring({
  value,
  total,
  color,
  children,
}: {
  value: number;
  total: number;
  color: string;
  children?: React.ReactNode;
}) {
  const radius = 26;
  const stroke = 5;
  const normalizedRadius = radius - stroke / 2;
  const circumference = 2 * Math.PI * normalizedRadius;
  const pct = total > 0 ? value / total : 0;
  const offset = circumference * (1 - pct);
 
  return (
    <div className="relative" style={{ width: radius * 2, height: radius * 2 }}>
      <svg width={radius * 2} height={radius * 2} style={{ transform: "rotate(-90deg)" }}>
        <circle cx={radius} cy={radius} r={normalizedRadius} fill="transparent" stroke="#F3F4F6" strokeWidth={stroke} />
        <circle
          cx={radius} cy={radius} r={normalizedRadius}
          fill="transparent"
          stroke={color}
          strokeWidth={stroke}
          strokeDasharray={`${circumference} ${circumference}`}
          strokeDashoffset={offset}
          strokeLinecap="round"
        />
      </svg>
      <div className="absolute inset-0 flex items-center justify-center">
        {children}
      </div>
    </div>
  );
}
 
// Mini bar chart for weekly totals
function BarChart({ data, color }: { data: number[]; color: string }) {
  const max = Math.max(...data, 1);
  const days = ["S", "M", "T", "W", "T", "F", "S"];
  const today = new Date().getDay();
 
  return (
    <div className="flex items-end gap-1 h-10">
      {data.map((val, i) => (
        <div key={i} className="flex flex-col items-center gap-0.5 flex-1">
          <div
            className="w-full rounded-t-sm min-h-0.75 transition-all"
            style={{
              height: `${(val / max) * 28}px`,
              backgroundColor: i === today ? color : `${color}44`,
            }}
          />
          <span className="text-[8px]" style={{ color: i === today ? color : "#D1D5DB", fontWeight: i === today ? 700 : 400 }}>
            {days[i]}
          </span>
        </div>
      ))}
    </div>
  );
}
 
export default function Stats({ selectedDate, appointments, isLoading }: StatsProps) {
  const summary = useMemo<DerivedDashboardSummary>(() => {
    const derived: DerivedDashboardSummary = {
      total_for_date: 0,
      overdue_for_date: 0,
      upcoming_for_date: 0,
      done_for_date: 0,
      done_all: 0,
      total_all: appointments.length,
      weekly_count: [0, 0, 0, 0, 0, 0, 0],
    };

    for (const appointment of appointments) {
      if (appointment.status === "done") {
        derived.done_all += 1;
      }

      if (appointment.date) {
        const weekdayIndex = parseSundayBasedIndex(appointment.date);
        if (weekdayIndex !== null) {
          derived.weekly_count[weekdayIndex] += 1;
        }
      }

      if (appointment.date !== selectedDate) {
        continue;
      }

      derived.total_for_date += 1;

      if (appointment.status === "overdue") {
        derived.overdue_for_date += 1;
        derived.upcoming_for_date += 1;
      }

      if (appointment.status === "upcoming") {
        derived.upcoming_for_date += 1;
      }

      if (appointment.status === "done") {
        derived.done_for_date += 1;
      }
    }

    return derived;
  }, [appointments, selectedDate]);

  const total = summary.total_for_date;
  const overdue = summary.overdue_for_date;
  const upcoming = summary.upcoming_for_date;
  const doneForDate = summary.done_for_date;
  const doneAll = summary.done_all;
  const totalAll = summary.total_all;
  const uncompletedForDate = total - doneForDate;
 
  return (
    <div className="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-4 gap-4">
      {/* Today's Total */}
      <div className="bg-white rounded-2xl shadow-sm overflow-hidden hover:-translate-y-1 transition-transform">
        <div className="h-7 bg-[#4285F4] rounded-t-2xl flex items-center px-3">
          <p className="text-[12px] font-bold text-white uppercase tracking-wider">Today&apos;s Total</p>
        </div>
        <div className="px-5 py-5">
          <div className="flex items-end justify-between">
            <div>
              <p className="text-4xl font-bold text-[#1A1A2E]">{isLoading ? "--" : String(total).padStart(2, "0")}</p>
              <p className="text-[11px] text-gray-400 font-semibold tracking-wide mt-0.5">APPOINTMENTS</p>
            </div>
            <BarChart data={summary.weekly_count} color="#4285F4" />
          </div>
        </div>
      </div>
 
      {/* Late / Overdue */}
      <div className="bg-white rounded-2xl shadow-sm overflow-hidden hover:-translate-y-1 transition-transform">
        <div className="h-7 bg-[#EA4335] rounded-t-2xl flex items-center px-3">
          <p className="text-[12px] font-bold text-white uppercase tracking-wider mb-1">Late / Overdue</p>
        </div>
        <div className="px-5 py-5">
          <div className="flex items-end justify-between">
            <div>
              <p className="text-4xl font-bold text-[#1A1A2E]">{isLoading ? "--" : String(overdue).padStart(2, "0")}</p>
              <p className="text-[11px] text-gray-400 font-semibold tracking-wide mt-0.5">DELAYED VISITS</p>
            </div>
            <Ring value={overdue} total={uncompletedForDate || 1} color="#EA4335">
              <span className="text-[10px] font-bold text-[#EA4335]">{overdue}/{Math.max(uncompletedForDate, 0)}</span>
            </Ring>
          </div>
        </div>
      </div>
 
      {/* Remaining */}
      <div className="bg-white rounded-2xl shadow-sm overflow-hidden hover:-translate-y-1 transition-transform">
        <div className="h-7 bg-[#D5B60A] rounded-t-2xl flex items-center px-3">
          <p className="text-[12px] font-bold text-white uppercase tracking-wider mb-1">Remaining</p>
        </div>
        <div className="px-5 py-5">
          <div className="flex items-end justify-between">
            <div>
              <p className="text-4xl font-bold text-[#1A1A2E]">{isLoading ? "--" : String(upcoming).padStart(2, "0")}</p>
              <p className="text-[11px] text-gray-400 font-semibold tracking-wide mt-0.5">TO CONSULT</p>
            </div>
            <Ring value={upcoming} total={total || 1} color="#D5B60A">
              <span className="text-[10px] font-bold text-[#D5B60A]">{upcoming}/{total}</span>
            </Ring>
          </div>
        </div>
      </div>
 
      {/* Completed */}
      <div className="bg-white rounded-2xl shadow-sm 0verflow-hidden hover:-translate-y-1 transition-transform">
        <div className="h-7 bg-[#34A853] rounded-t-2xl flex items-center px-3">
          <p className="text-[12px] font-bold text-white uppercase tracking-wider mb-1">Completed</p>
        </div>
        <div className="px-5 py-5">
          <div className="flex items-end justify-between">
            <div>
              <p className="text-4xl font-bold text-[#1A1A2E]">{isLoading ? "--" : String(doneAll).padStart(2, "0")}</p>
              <p className="text-[11px] text-gray-400 font-semibold tracking-wide mt-0.5">RESOLVED</p>
            </div>
            <Ring value={doneAll} total={totalAll || 1} color="#34A853">
              <span className="text-sm text-[#34A853]">✓</span>
            </Ring>
          </div>
        </div>
      </div>
    </div>
  );
}