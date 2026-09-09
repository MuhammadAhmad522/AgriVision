import { Component } from 'react';
import type { ErrorInfo, ReactNode } from 'react';
import { ShieldAlert } from 'lucide-react';

interface Props {
  children: ReactNode;
}

interface State {
  hasError: boolean;
  error: Error | null;
}

export class ErrorBoundary extends Component<Props, State> {
  public state: State = {
    hasError: false,
    error: null
  };

  public static getDerivedStateFromError(error: Error): State {
    return { hasError: true, error };
  }

  public componentDidCatch(error: Error, errorInfo: ErrorInfo) {
    // In a real production app, this is where we'd send the error to Sentry or Datadog
    console.error('Uncaught Error Boundary Exception:', error, errorInfo);
  }

  public render() {
    if (this.state.hasError) {
      return (
        <div className="min-h-screen flex items-center justify-center p-6 bg-bg-main text-text-main font-body">
          <div className="w-full max-w-md bg-bg-glass-card border border-accent-red/30 p-8 rounded-xl shadow-glass text-center backdrop-blur-md">
            <div className="w-12 h-12 rounded-full bg-accent-red/10 flex items-center justify-center mx-auto mb-4 border border-accent-red/20">
              <ShieldAlert className="text-accent-red" size={24} />
            </div>
            <h2 className="text-xl font-heading font-bold mb-2">Something went wrong</h2>
            <p className="text-sm text-text-muted mb-6">
              An unexpected application error occurred. We've logged the issue.
              Please try refreshing the page or contact support if the problem persists.
            </p>
            <button
              onClick={() => window.location.reload()}
              className="btn-primary w-full justify-center"
            >
              Reload Dashboard
            </button>
          </div>
        </div>
      );
    }

    return this.props.children;
  }
}
