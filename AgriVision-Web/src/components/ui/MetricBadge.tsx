import React from 'react';
import clsx from 'clsx';

interface MetricBadgeProps {
  label: string;
  variant?: 'success' | 'warning' | 'danger' | 'info' | 'neutral';
  size?: 'sm' | 'md';
}

export const MetricBadge: React.FC<MetricBadgeProps> = ({ label, variant = 'success', size = 'md' }) => {
  const variantStyles = {
    success: 'bg-primary-medium/20 text-accent-lime border-primary-light/40',
    warning: 'bg-amber-500/20 text-amber-400 border-amber-500/40',
    danger: 'bg-red-400/20 text-red-400 border-red-400/40',
    info: 'bg-accent-cyan/20 text-accent-cyan border-accent-cyan/40',
    neutral: 'bg-white/10 text-gray-300 border-white/20'
  };

  const sizeStyles = {
    sm: 'text-[10px] font-bold px-2 py-0.5',
    md: 'text-[11px] font-bold px-2.5 py-1'
  };

  return (
    <span
      className={clsx(
        'inline-flex items-center gap-1.5 rounded-full border shadow-sm backdrop-blur-md',
        variantStyles[variant],
        sizeStyles[size]
      )}
    >
      <span className="w-1.5 h-1.5 rounded-full bg-current" />
      {label}
    </span>
  );
};
