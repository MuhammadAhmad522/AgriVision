import React, { useState, useEffect } from 'react';
import { useFarm } from '../core/context/FarmContext';
import { useAuth } from '../core/auth/AuthContext';
import { advisoryService } from '../core/services/AdvisoryService';
import { GlassCard } from '../components/ui/GlassCard';
import { MetricBadge } from '../components/ui/MetricBadge';
import { Sparkles, CheckCircle, Brain, Zap, AlertTriangle } from 'lucide-react';
import type { AIRecommendation } from '../core/types';
import clsx from 'clsx';

export const AIAdvisoryView: React.FC = () => {
  const { dashboardData, activeField, refreshData, loading } = useFarm();
  const { user } = useAuth();
  const [selectedFilter, setSelectedFilter] = useState<string>('all');
  const [agronomistRecs, setAgronomistRecs] = useState<AIRecommendation[]>([]);
  const [validating, setValidating] = useState<string | null>(null);
  const [validationNotes, setValidationNotes] = useState('');

  const isAgronomist = user?.role === 'agronomist';

  useEffect(() => {
    if (isAgronomist) {
      advisoryService.getExpertPendingRecommendations().then(setAgronomistRecs).catch(console.error);
    }
  }, [isAgronomist]);

  const handleValidate = async (id: string, status: 'approved' | 'rejected') => {
    try {
      await advisoryService.validateRecommendation(id, status, validationNotes);
      setAgronomistRecs(prev => prev.filter(r => r.id !== id));
      setValidating(null);
      setValidationNotes('');
    } catch (e) {
      console.error(e);
      alert('Failed to validate recommendation');
    }
  };

  const recs = isAgronomist ? agronomistRecs : (dashboardData?.recommendations || []);

  const filteredRecs = selectedFilter === 'all'
    ? recs
    : recs.filter((r) => r.category.toLowerCase().replace(' ', '_') === selectedFilter);

  return (
    <div className="flex flex-col gap-6 pb-10">
      {/* Hero AI Engine Header */}
      <GlassCard glow className="flex flex-col md:flex-row justify-between items-start md:items-center gap-4 p-5">
        <div className="flex items-center gap-4">
          <div
            className="w-12 h-12 rounded-xl flex items-center justify-center shadow-[0_0_20px_rgba(154,212,108,0.4)] shrink-0 bg-gradient-to-br from-accent-lime to-primary-light"
          >
            <Brain size={28} className="text-[#0a170d]" />
          </div>
          <div>
            <div className="flex flex-col sm:flex-row sm:items-center gap-2 mb-1">
              <h2 className="text-xl font-extrabold text-text-main">
                {isAgronomist ? 'Expert Validation Queue' : 'Google Gemini Multimodal Agronomy Engine'}
              </h2>
              {!isAgronomist && <MetricBadge label="Model: gemini-3.7-flash" variant="info" size="sm" />}
            </div>
            <p className="text-[13px] text-text-muted">
              {isAgronomist 
                ? 'Review and validate pending high-risk AI recommendations across all fields.' 
                : 'Continuous multi-source synthesis across Sentinel-2 canopy vigor, soil telemetry, and Punjab crop rules.'}
            </p>
          </div>
        </div>

        {!isAgronomist && (
          <button 
            onClick={refreshData} 
            disabled={loading} 
            className="btn-primary shrink-0"
          >
            <Sparkles size={16} />
            <span>Force AI Re-Evaluation</span>
          </button>
        )}
      </GlassCard>

      {/* Category Filter Chips */}
      <div className="flex flex-wrap gap-2.5">
        {['all', 'fertilizer_window', 'irrigation', 'pest_risk', 'plant_health', 'weather_alert'].map((cat) => (
          <button
            key={cat}
            onClick={() => setSelectedFilter(cat)}
            className={clsx(
              "px-4 py-2 rounded-full text-xs font-semibold cursor-pointer capitalize transition-all duration-200 border",
              selectedFilter === cat 
                ? "bg-primary border-border-glass-bright text-white shadow-glow" 
                : "bg-white/5 border-border-subtle text-text-muted hover:bg-white/10 hover:text-text-main"
            )}
          >
            {cat.replace('_', ' ')}
          </button>
        ))}
      </div>

      {/* Recommendations Feed */}
      <div className="flex flex-col gap-3.5">
        {filteredRecs.length === 0 && (
          <p className="text-text-muted text-sm text-center py-10">No recommendations available.</p>
        )}
        {filteredRecs.map((rec) => (
          <GlassCard key={rec.id} glow={rec.priority === 'high'} className="p-5">
            <div className="flex flex-col sm:flex-row justify-between items-start gap-4">
              <div className="flex gap-3.5 w-full">
                <div
                  className={clsx(
                    "w-9 h-9 rounded-lg flex items-center justify-center border shrink-0",
                    rec.priority === 'high' 
                      ? "bg-red-400/20 border-red-400" 
                      : "bg-primary-medium/20 border-primary-light"
                  )}
                >
                  <Zap size={18} className={rec.priority === 'high' ? "text-red-400" : "text-accent-lime"} />
                </div>
                <div className="w-full">
                  <div className="flex items-center gap-2 mb-1">
                    <h3 className="text-[15px] font-bold text-text-main">{rec.category}</h3>
                    <MetricBadge
                      label={`${rec.priority.toUpperCase()} PRIORITY`}
                      variant={rec.priority === 'high' ? 'danger' : rec.priority === 'medium' ? 'warning' : 'success'}
                      size="sm"
                    />
                    {rec.requires_expert_confirmation && rec.expert_status === 'pending' && !isAgronomist && (
                      <MetricBadge label="PENDING EXPERT REVIEW" variant="warning" size="sm" />
                    )}
                    {rec.expert_status === 'approved' && (
                      <MetricBadge label="EXPERT APPROVED" variant="success" size="sm" />
                    )}
                    {rec.expert_status === 'rejected' && (
                      <MetricBadge label="EXPERT REJECTED" variant="danger" size="sm" />
                    )}
                  </div>
                  <p className="text-[13px] text-text-main leading-relaxed opacity-90 mb-2">
                    {rec.advice}
                  </p>
                  {rec.rationale && (
                    <p className="text-[12px] text-text-muted italic mb-2">
                      Rationale: {rec.rationale}
                    </p>
                  )}
                  {rec.expert_notes && (
                    <div className="bg-white/5 border border-border-subtle rounded p-2 mt-2">
                      <p className="text-[12px] text-text-main font-semibold flex items-center gap-1">
                        <AlertTriangle size={12} className="text-accent-lime" />
                        Expert Note
                      </p>
                      <p className="text-[12px] text-text-muted">{rec.expert_notes}</p>
                    </div>
                  )}
                  <p className="text-[11px] text-text-dim mt-2">
                    {isAgronomist ? `Field ID: ${rec.field_id}` : `Generated for ${activeField?.name}`} • {new Date(rec.created_at).toLocaleString()}
                  </p>
                </div>
              </div>

              {!isAgronomist ? (
                <button
                  className="btn-secondary px-3 py-1.5 text-xs shrink-0"
                  onClick={() => alert(`Recommendation acknowledged for ${activeField?.name}`)}
                >
                  <CheckCircle size={14} className="text-accent-lime" />
                  <span>Mark Actioned</span>
                </button>
              ) : (
                <div className="flex flex-col gap-2 w-full sm:w-auto shrink-0 mt-4 sm:mt-0">
                  {validating === rec.id ? (
                    <div className="flex flex-col gap-2">
                      <textarea 
                        className="bg-bg-main border border-border-glass rounded text-xs p-2 text-text-main"
                        placeholder="Add notes for the farmer..."
                        value={validationNotes}
                        onChange={(e) => setValidationNotes(e.target.value)}
                        rows={2}
                      />
                      <div className="flex gap-2">
                        <button className="btn-primary py-1 px-2 text-xs" onClick={() => handleValidate(rec.id, 'approved')}>Approve</button>
                        <button className="btn-secondary py-1 px-2 text-xs text-red-400" onClick={() => handleValidate(rec.id, 'rejected')}>Reject</button>
                        <button className="text-xs text-text-muted hover:text-text-main" onClick={() => { setValidating(null); setValidationNotes(''); }}>Cancel</button>
                      </div>
                    </div>
                  ) : (
                    <button className="btn-primary py-1.5 px-3 text-xs" onClick={() => setValidating(rec.id)}>
                      Validate
                    </button>
                  )}
                </div>
              )}
            </div>
          </GlassCard>
        ))}
      </div>
    </div>
  );
};
