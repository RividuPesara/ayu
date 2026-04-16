"use client";
 
import React, { useState } from "react";
 
const DAYS = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"];
const MONTHS = [
  "January", "February", "March", "April", "May", "June",
  "July", "August", "September", "October", "November", "December",
];
 
interface CalendarProps {
  selectedDate: Date;
  onDateSelect: (date: Date) => void;
}
 
function getWeekStart(date: Date): Date {
  const d = new Date(date);
  d.setDate(d.getDate() - d.getDay()); // go back to Sunday
  return d;
}
 
function addDays(date: Date, days: number): Date {
  const d = new Date(date);
  d.setDate(d.getDate() + days);
  return d;
}
 
function isSameDay(a: Date, b: Date): boolean {
  return (
    a.getDate() === b.getDate() &&
    a.getMonth() === b.getMonth() &&
    a.getFullYear() === b.getFullYear()
  );
}
 
export default function Calendar({ selectedDate, onDateSelect }: CalendarProps) {
  const today = new Date();
  const [weekStart, setWeekStart] = useState(getWeekStart(new Date()));
 
  const weekDates = Array.from({ length: 7 }, (_, i) => addDays(weekStart, i));
 
  function goToPrevWeek() {
    setWeekStart((prev) => addDays(prev, -7));
  }
 
  function goToNextWeek() {
    setWeekStart((prev) => addDays(prev, 7));
  }
 
  function goToToday() {
    setWeekStart(getWeekStart(today));
    onDateSelect(today);
  }
 
  const monthLabel = MONTHS[weekDates[0].getMonth()] +
    (weekDates[0].getMonth() !== weekDates[6].getMonth()
      ? ` / ${MONTHS[weekDates[6].getMonth()]}`
      : "") +
    ` ${weekDates[0].getFullYear()}`;
 
  return (
    <div className="bg-white rounded-2xl px-6 py-5 shadow-sm border border-gray-100">
      {/* Top row — month label, today button and arrows */}
      <div className="flex items-center justify-between mb-4">
        <div className="flex items-center gap-3">
          <span className="text-sm text-[15px] font-bold text-[#1A1A2E] tracking-wide uppercase">
            {monthLabel}
          </span>
          
          <button
            onClick={goToToday}
            className="text-xs font-bold text-white bg-[#694EBC] px-3 py-1.5 rounded-lg hover:bg-[#6d28d9] transition-colors"
          >
            Today
          </button>
        </div>
        <div className="flex gap-2">
          <button
            onClick={goToPrevWeek}
            className="w-8 h-8 flex items-center justify-center rounded-lg bg-gray-100 hover:bg-gray-200 text-gray-600 transition-colors text-lg"
          >
            ‹
          </button>
          <button
            onClick={goToNextWeek}
            className="w-8 h-8 flex items-center justify-center rounded-lg bg-gray-100 hover:bg-gray-200 text-gray-600 transition-colors text-lg"
          >
            ›
          </button>
        </div>
      </div>
 
      {/* Day pills */}
      <div className="grid grid-cols-7 gap-2">
        {weekDates.map((date, idx) => {
          const isSelected = isSameDay(date, selectedDate);
          const isToday = isSameDay(date, today);
          const isWeekend = idx === 0 || idx === 6;
 
          return (
            <button
              key={idx}
              onClick={() => onDateSelect(date)}
              className={`flex flex-col items-center gap-1 py-3 rounded-xl transition-all duration-200
                ${isSelected
                  ? "bg-[#694EBC]"
                  : isToday
                  ? "bg-purple-50 ring-2 ring-purple-200"
                  : "hover:bg-purple-50"
                }`}
            >
              <span className={`text-[10px] font-bold tracking-wider
                ${isSelected ? "text-white/70" : isWeekend ? "text-red-400" : "text-gray-400"}`}>
                {DAYS[idx]}
              </span>
              <span className={`text-lg font-bold leading-none
                ${isSelected ? "text-white" : isWeekend ? "text-red-500" : "text-[#1A1A2E]"}`}>
                {date.getDate()}
              </span>
            </button>
          );
        })}
      </div>
    </div>
  );
}