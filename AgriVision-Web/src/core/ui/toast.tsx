import React, { createContext, useCallback, useContext, useMemo, useRef, useState } from 'react';
import { CheckCircle2, AlertTriangle, Info, X } from 'lucide-react';
import { describeError } from '../utils/sanitize';

export type ToastKind = 'success' | 'error' | 'info';

export interface ToastItem {
  id: number;
  kind: ToastKind;
  message: string;
  /** ms; 0 = sticky until dismissed */
  duration: number;
}

interface ToastApi {
  success: (message: string, duration?: number) => void;
  error: (message: string, duration?: number) => void;
  info: (message: string, duration?: number) => void;
  /** Normalize any thrown value into a readable error toast. */
  fromError: (err: unknown, fallback?: string) => void;
  dismiss: (id: number) => void;
}

const ToastContext = createContext<ToastApi | null>(null);

const DEFAULTS: Record<ToastKind, number> = { success: 4000, info: 5000, error: 8000 };

export const ToastProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [toasts, setToasts] = useState<ToastItem[]>([]);
  const seq = useRef(0);
  const timers = useRef<Map<number, ReturnType<typeof setTimeout>>>(new Map());

  const dismiss = useCallback((id: number) => {
    setToasts((prev) => prev.filter((t) => t.id !== id));
    const timer = timers.current.get(id);
    if (timer) {
      clearTimeout(timer);
      timers.current.delete(id);
    }
  }, []);

  const push = useCallback(
    (kind: ToastKind, message: string, duration?: number) => {
      const clean = String(message ?? '').trim().slice(0, 400) || 'Done.';
      const id = ++seq.current;
      const ms = duration ?? DEFAULTS[kind];
      setToasts((prev) => {
        // Collapse an identical message already on screen instead of stacking duplicates.
        if (prev.some((t) => t.kind === kind && t.message === clean)) return prev;
        return [...prev.slice(-3), { id, kind, message: clean, duration: ms }];
      });
      if (ms > 0) {
        timers.current.set(
          id,
          setTimeout(() => dismiss(id), ms)
        );
      }
    },
    [dismiss]
  );

  const api = useMemo<ToastApi>(
    () => ({
      success: (m, d) => push('success', m, d),
      error: (m, d) => push('error', m, d),
      info: (m, d) => push('info', m, d),
      fromError: (err, fallback) => push('error', describeError(err, fallback)),
      dismiss,
    }),
    [push, dismiss]
  );

  return (
    <ToastContext.Provider value={api}>
      {children}
      <div
        aria-live="polite"
        aria-atomic="false"
        className="fixed z-[9999] bottom-4 right-4 flex flex-col gap-2 w-[min(92vw,380px)] pointer-events-none"
      >
        {toasts.map((t) => (
          <ToastCard key={t.id} toast={t} onClose={() => dismiss(t.id)} />
        ))}
      </div>
    </ToastContext.Provider>
  );
};

const STYLES: Record<ToastKind, { wrap: string; icon: React.ReactNode }> = {
  success: {
    wrap: 'bg-[#12240f]/95 border-primary-light/40 text-accent-lime',
    icon: <CheckCircle2 size={16} className="shrink-0 mt-0.5" />,
  },
  error: {
    wrap: 'bg-[#2a1212]/95 border-red-400/50 text-red-200',
    icon: <AlertTriangle size={16} className="shrink-0 mt-0.5" />,
  },
  info: {
    wrap: 'bg-black/90 border-white/20 text-text-main',
    icon: <Info size={16} className="shrink-0 mt-0.5" />,
  },
};

const ToastCard: React.FC<{ toast: ToastItem; onClose: () => void }> = ({ toast, onClose }) => {
  const s = STYLES[toast.kind];
  return (
    <div
      role={toast.kind === 'error' ? 'alert' : 'status'}
      className={
        'pointer-events-auto flex items-start gap-2.5 rounded-lg border px-3.5 py-3 text-[12.5px] leading-snug shadow-xl backdrop-blur-md ' +
        s.wrap
      }
    >
      {s.icon}
      <span className="flex-1 break-words">{toast.message}</span>
      <button
        onClick={onClose}
        aria-label="Dismiss notification"
        className="shrink-0 -mr-1 -mt-0.5 p-0.5 rounded text-current/70 hover:text-current hover:bg-white/10 transition-colors"
      >
        <X size={14} />
      </button>
    </div>
  );
};

export function useToast(): ToastApi {
  const ctx = useContext(ToastContext);
  if (!ctx) throw new Error('useToast must be used within <ToastProvider>');
  return ctx;
}
