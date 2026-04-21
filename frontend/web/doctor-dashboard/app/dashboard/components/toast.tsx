"use client";
import React, {
  createContext,
  useContext,
  useState,
  useCallback,
  useRef,
} from "react";
 
type ToastType = "success" | "error" | "info";
interface Toast {
  id: number;
  message: string;
  type: ToastType;
}
 
interface ToastContextValue {
  showToast: (message: string, type?: ToastType) => void;
}
 
const ToastContext = createContext<ToastContextValue>({
  showToast: () => {},
});
 
export function ToastProvider({ children }: { children: React.ReactNode }) {
  const [toasts, setToasts] = useState<Toast[]>([]);
  const counter = useRef(0);
 
  const showToast = useCallback((message: string, type: ToastType = "info") => {
    const id = ++counter.current;
    setToasts((prev) => [...prev, { id, message, type }]);
    setTimeout(() => {
      setToasts((prev) => prev.filter((t) => t.id !== id));
    }, 3500);
  }, []);
 
  const icons: Record<ToastType, string> = {
    success: "✓",
    error: "✕",
    info: "ℹ",
  };
 
  const colors: Record<ToastType, string> = {
    success: "#34A853",
    error: "#EA4335",
    info: "#4285F4",
  };
 
  return (
    <ToastContext.Provider value={{ showToast }}>
      {children}
      <div
        style={{
          position: "fixed",
          bottom: 24,
          right: 24,
          zIndex: 9999,
          display: "flex",
          flexDirection: "column",
          gap: 10,
          pointerEvents: "none",
        }}
      >
        {toasts.map((t) => (
          <div
            key={t.id}
            style={{
              background: "#1a1a2e",
              color: "#fff",
              borderRadius: 12,
              padding: "12px 18px",
              display: "flex",
              alignItems: "center",
              gap: 10,
              boxShadow: "0 8px 32px rgba(0,0,0,0.35)",
              borderLeft: `4px solid ${colors[t.type]}`,
              minWidth: 260,
              animation: "slideUp 0.3s ease",
              pointerEvents: "auto",
            }}
          >
            <span
              style={{
                width: 22,
                height: 22,
                borderRadius: "50%",
                background: colors[t.type],
                display: "flex",
                alignItems: "center",
                justifyContent: "center",
                fontSize: 12,
                fontWeight: 700,
                flexShrink: 0,
              }}
            >
              {icons[t.type]}
            </span>
            <span style={{ fontSize: 14, fontWeight: 500 }}>{t.message}</span>
          </div>
        ))}
      </div>
      <style>{`
        @keyframes slideUp {
          from { transform: translateY(20px); opacity: 0; }
          to { transform: translateY(0); opacity: 1; }
        }
      `}</style>
    </ToastContext.Provider>
  );
}
 
export function useToast() {
  return useContext(ToastContext);
}