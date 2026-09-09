import React from 'react';
import clsx from 'clsx';

interface GlassCardProps extends React.HTMLAttributes<HTMLDivElement> {
  children: React.ReactNode;
  className?: string;
  glow?: boolean;
}

export const GlassCard: React.FC<GlassCardProps> = ({ children, className, glow = false, ...props }) => {
  return (
    <div
      className={clsx(
        'glass-card relative overflow-hidden',
        glow && 'interactive-glow',
        className
      )}
      {...props}
    >
      {children}
    </div>
  );
};
