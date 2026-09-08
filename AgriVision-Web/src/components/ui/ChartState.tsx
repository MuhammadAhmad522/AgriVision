import React from 'react';
import { Loader2, AlertTriangle, Inbox } from 'lucide-react';

/**
 * Every chart on this screen used to render its axes and grid regardless of whether data
 * had arrived, failed, or simply did not exist for that field. All three looked identical:
 * a plausible, empty chart. This makes the three states say what they are.
 */
interface ChartStateProps {
  isLoading?: boolean;
  isError?: boolean;
  isEmpty?: boolean;
  emptyMessage?: string;
  errorMessage?: string;
  height?: number;
  children: React.ReactNode;
}

const Frame: React.FC<{ height: number; children: React.ReactNode }> = ({ height, children }) => (
  <div
    className="flex flex-col items-center justify-center text-center gap-2 px-6"
    style={{ height }}
  >
    {children}
  </div>
);

export const ChartState: React.FC<ChartStateProps> = ({
  isLoading,
  isError,
  isEmpty,
  emptyMessage = 'No readings in this window.',
  errorMessage = 'Could not load telemetry for this field.',
  height = 240,
  children,
}) => {
  if (isLoading) {
    return (
      <Frame height={height}>
        <Loader2 size={20} className="animate-spin text-primary-light" />
        <p className="text-xs text-text-muted">Loading telemetry…</p>
      </Frame>
    );
  }

  if (isError) {
    return (
      <Frame height={height}>
        <AlertTriangle size={20} className="text-accent-red" />
        <p className="text-xs text-accent-red">{errorMessage}</p>
      </Frame>
    );
  }

  if (isEmpty) {
    return (
      <Frame height={height}>
        <Inbox size={20} className="text-text-dim" />
        <p className="text-xs text-text-muted leading-relaxed max-w-[280px]">{emptyMessage}</p>
      </Frame>
    );
  }

  return <div style={{ height }}>{children}</div>;
};
