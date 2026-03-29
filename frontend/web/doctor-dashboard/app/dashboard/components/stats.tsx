"use client";
 
import React, { useState, useEffect } from "react";
import { db } from "@/app/lib/firebase";
import { collection, getDocs } from "firebase/firestore";
 
interface Appointment {
  id: string;
  status: "done" | "upcoming" | "overdue";
  date?: string;
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
            className="w-full rounded-t-sm min-h-[3px] transition-all"
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
 
export default function Stats() {
  const [appointments, setAppointments] = useState<Appointment[]>([]);
  const [weeklyCount, setWeeklyCount] = useState<number[]>([0,0,0,0,0,0,0]);

  useEffect(() => {
    async function fetchAppointments() {
      const querySnapshot = await getDocs(collection(db, "appointments"));

      const data = querySnapshot.docs.map(doc => ({
        id: doc.id,
        ...doc.data()
      })) as Appointment[];

      setAppointments(data);

      /* Calculate weekly counts */
      const week = [0,0,0,0,0,0,0];

      data.forEach((appointment) => {
        if (appointment.date) {
          const day = new Date(appointment.date).getDay();
          week[day]++;
        }
      });

      setWeeklyCount(week);
    }

    fetchAppointments();
  }, []);

  const total = appointments.length;
  const overdue = appointments.filter((a) => a.status === "overdue").length;
  const upcoming = appointments.filter((a) => a.status === "upcoming").length;
  const done = appointments.filter((a) => a.status === "done").length;
  const uncompleted = total - done;
 
  return (
    <div className="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-4 gap-4">
      {/* Today's Total */}
      <div className="bg-white rounded-2xl shadow-sm overflow-hidden hover:-translate-y-1 transition-transform">
        <div className="h-7 bg-[#4285F4] rounded-t-2xl flex items-center px-3">
          <p className="text-[12px] font-bold text-white uppercase tracking-wider">Today's Total</p>
        </div>
        <div className="px-5 py-5">
          <div className="flex items-end justify-between">
            <div>
              <p className="text-4xl font-bold text-[#1A1A2E]">{String(total).padStart(2, "0")}</p>
              <p className="text-[11px] text-gray-400 font-semibold tracking-wide mt-0.5">APPOINTMENTS</p>
            </div>
            <BarChart data={weeklyCount} color="#4285F4" />
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
              <p className="text-4xl font-bold text-[#1A1A2E]">{String(overdue).padStart(2, "0")}</p>
              <p className="text-[11px] text-gray-400 font-semibold tracking-wide mt-0.5">DELAYED VISITS</p>
            </div>
            <Ring value={overdue} total={uncompleted || 1} color="#EA4335">
              <span className="text-[10px] font-bold text-[#EA4335]">{overdue}/{uncompleted}</span>
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
              <p className="text-4xl font-bold text-[#1A1A2E]">{String(upcoming).padStart(2, "0")}</p>
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
              <p className="text-4xl font-bold text-[#1A1A2E]">{String(done).padStart(2, "0")}</p>
              <p className="text-[11px] text-gray-400 font-semibold tracking-wide mt-0.5">RESOLVED</p>
            </div>
            <Ring value={done} total={total || 1} color="#34A853">
              <span className="text-sm text-[#34A853]">✓</span>
            </Ring>
          </div>
        </div>
      </div>
    </div>
  );
}