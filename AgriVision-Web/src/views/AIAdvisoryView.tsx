import React, { useState, useEffect, useCallback } from 'react';
import { useFarm } from '../core/context/FarmContext';
import { useAuth } from '../core/auth/AuthContext';
import { advisoryService } from '../core/services/AdvisoryService';
import { GlassCard } from '../components/ui/GlassCard';
import { MetricBadge } from '../components/ui/MetricBadge';
import { Sparkles, CheckCircle, Brain, Zap, AlertTriangle, Clock, ExternalLink, MessageSquare, Send } from 'lucide-react';
import type { AIRecommendation, ChatMessage } from '../core/types';
import clsx from 'clsx';

const CATEGORY_FILTERS = ['all', 'irrigation', 'plant_health', 'weather_alert', 'fertilizer_window', 'harvest_timing', 'pest_risk', 'field_monitoring'];

export const AIAdvisoryView: React.FC = () => {
  const { dashboardData, activeField, refreshActiveFieldData } = useFarm();
  const { user } = useAuth();
  const [selectedFilter, setSelectedFilter] = useState<string>('all');
  const [agronomistRecs, setAgronomistRecs] = useState<AIRecommendation[]>([]);
  const [validating, setValidating] = useState<string | null>(null);
  const [validationNotes, setValidationNotes] = useState('');
  const [showQueue, setShowQueue] = useState(false);
  const [reEvaluating, setReEvaluating] = useState(false);

  const isAgronomist = user?.role === 'agronomist';
  const isStaff = user?.role === 'admin' || user?.role === 'agronomist';

  useEffect(() => {
    if (isAgronomist && showQueue) {
      advisoryService.getExpertPendingRecommendations().then(setAgronomistRecs).catch(console.error);
    }
  }, [isAgronomist, showQueue]);

  const handleValidate = async (id: string, status: 'approved' | 'rejected') => {
    try {
      await advisoryService.validateRecommendation(id, status, validationNotes);
      setAgronomistRecs(prev => prev.filter(r => r.id !== id));
      setValidating(null);
      setValidationNotes('');
      await refreshActiveFieldData();
    } catch (e) {
      console.error(e);
      alert('Failed to validate recommendation');
    }
  };

  const handleForceReEvaluation = async () => {
    if (!activeField) return;
    setReEvaluating(true);
    try {
      const ok = await advisoryService.triggerAIReasoning(activeField.id);
      if (!ok) {
        alert('Could not trigger AI re-evaluation. It may be rate-limited — try again shortly.');
        return;
      }
      // The run happens in the background; give it a moment before pulling fresh data.
      await new Promise((resolve) => setTimeout(resolve, 1500));
      await refreshActiveFieldData();
    } finally {
      setReEvaluating(false);
    }
  };

  const recs = showQueue ? agronomistRecs : (dashboardData?.recommendations || []);
  const advisor = dashboardData?.advisor;

  const filteredRecs = selectedFilter === 'all'
    ? recs
    : recs.filter((r) => r.category.toLowerCase().replace(/\s+/g, '_') === selectedFilter);

  return (
    <div className="flex flex-col gap-6 pb-10">
      <GlassCard glow className="flex flex-col md:flex-row justify-between items-start md:items-center gap-4 p-5">
        <div className="flex items-center gap-4">
          <div className="w-12 h-12 rounded-xl flex items-center justify-center shadow-[0_0_20px_rgba(154,212,108,0.4)] shrink-0 bg-gradient-to-br from-accent-lime to-primary-light">
            <Brain size={28} className="text-[#0a170d]" />
          </div>
          <div>
            <div className="flex flex-col sm:flex-row sm:items-center gap-2 mb-1">
              <h2 className="text-xl font-extrabold text-text-main">
                {showQueue ? 'Expert Validation Queue' : 'Google Gemini Multimodal Agronomy Engine'}
              </h2>
              {!showQueue && <MetricBadge label="Model: gemini-3.7-flash" variant="info" size="sm" />}
            </div>
            <p className="text-[13px] text-text-muted">
              {showQueue
                ? 'Review and validate pending high-risk AI recommendations across all fields.'
                : `Continuous multi-source synthesis for ${activeField?.name || 'the selected field'} — Sentinel-2 canopy vigor, soil telemetry, and Punjab crop rules.`}
            </p>
          </div>
        </div>

        <div className="flex items-center gap-2 shrink-0">
          {isAgronomist && (
            <button onClick={() => setShowQueue((v) => !v)} className="btn-secondary">
              {showQueue ? 'Back to field view' : 'Expert queue'}
            </button>
          )}
          {!showQueue && (
            <button onClick={handleForceReEvaluation} disabled={reEvaluating || !activeField} className="btn-primary">
              <Sparkles size={16} />
              <span>{reEvaluating ? 'Re-evaluating…' : 'Force AI Re-Evaluation'}</span>
            </button>
          )}
        </div>
      </GlassCard>

      {!showQueue && advisor && (advisor.status === 'unavailable' || advisor.status === 'stale') && (
        <GlassCard className={clsx('p-4 flex items-start gap-3 border', advisor.status === 'unavailable' ? 'border-red-400/40' : 'border-amber-500/40')}>
          {advisor.status === 'unavailable' ? <AlertTriangle size={18} className="text-red-400 shrink-0 mt-0.5" /> : <Clock size={18} className="text-amber-400 shrink-0 mt-0.5" />}
          <div>
            <p className="text-sm font-semibold text-text-main">
              {advisor.status === 'unavailable' ? 'AI Advisor is unavailable' : 'Showing the last successful advice'}
            </p>
            <p className="text-[13px] text-text-muted">{advisor.message || 'The AI Advisor could not complete the latest analysis.'}</p>
            {advisor.data_quality && (
              <p className="text-[12px] text-text-dim mt-1">Evidence quality: {advisor.data_quality}</p>
            )}
          </div>
        </GlassCard>
      )}

      {!showQueue && (
        <div className="flex flex-wrap gap-2.5">
          {CATEGORY_FILTERS.map((cat) => (
            <button
              key={cat}
              onClick={() => setSelectedFilter(cat)}
              className={clsx(
                'px-4 py-2 rounded-full text-xs font-semibold cursor-pointer capitalize transition-all duration-200 border',
                selectedFilter === cat
                  ? 'bg-primary border-border-glass-bright text-white shadow-glow'
                  : 'bg-white/5 border-border-subtle text-text-muted hover:bg-white/10 hover:text-text-main'
              )}
            >
              {cat.replace(/_/g, ' ')}
            </button>
          ))}
        </div>
      )}

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
                    'w-9 h-9 rounded-lg flex items-center justify-center border shrink-0',
                    rec.priority === 'high'
                      ? 'bg-red-400/20 border-red-400'
                      : 'bg-primary-medium/20 border-primary-light'
                  )}
                >
                  <Zap size={18} className={rec.priority === 'high' ? 'text-red-400' : 'text-accent-lime'} />
                </div>
                <div className="w-full">
                  <div className="flex items-center gap-2 mb-1 flex-wrap">
                    <h3 className="text-[15px] font-bold text-text-main">{rec.category}</h3>
                    <MetricBadge
                      label={`${rec.priority.toUpperCase()} PRIORITY`}
                      variant={rec.priority === 'high' ? 'danger' : rec.priority === 'medium' ? 'warning' : 'success'}
                      size="sm"
                    />
                    {rec.requires_expert_confirmation && rec.expert_status === 'pending' && (
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
                  {rec.evidence && rec.evidence.length > 0 && (
                    <div className="flex flex-col gap-1 mb-2">
                      {rec.evidence.filter((e) => e.url).map((e, i) => (
                        <a
                          key={i}
                          href={e.url}
                          target="_blank"
                          rel="noreferrer"
                          className="text-[11px] text-accent-cyan hover:underline flex items-center gap-1 w-fit"
                        >
                          <ExternalLink size={11} />
                          {e.url}
                        </a>
                      ))}
                    </div>
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
                    {showQueue ? `Field ID: ${rec.field_id}` : `Generated for ${activeField?.name}`} • {new Date(rec.created_at).toLocaleString()}
                  </p>
                </div>
              </div>

              {isStaff && (
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
                        <button className="btn-primary py-1 px-2 text-xs" onClick={() => handleValidate(rec.id, 'approved')}>
                          <CheckCircle size={14} />
                          Approve
                        </button>
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

      {!showQueue && activeField && <FieldChatPanel fieldId={activeField.id} />}
      {!showQueue && isStaff && activeField && <AgronomistGuidancePanel fieldId={activeField.id} />}
    </div>
  );
};

const FieldChatPanel: React.FC<{ fieldId: string }> = ({ fieldId }) => {
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [loading, setLoading] = useState(true);
  const [open, setOpen] = useState(false);

  useEffect(() => {
    setOpen(false);
  }, [fieldId]);

  useEffect(() => {
    if (!open) return;
    setLoading(true);
    advisoryService.getFieldChatHistory(fieldId)
      .then(setMessages)
      .catch((e) => { console.error(e); setMessages([]); })
      .finally(() => setLoading(false));
  }, [fieldId, open]);

  return (
    <GlassCard className="p-5">
      <button className="flex items-center justify-between w-full" onClick={() => setOpen((v) => !v)}>
        <div className="flex items-center gap-2">
          <MessageSquare size={16} className="text-accent-lime" />
          <h3 className="text-sm font-bold text-text-main">Farmer AI Chat History</h3>
        </div>
        <span className="text-xs text-text-muted">{open ? 'Hide' : 'Show'}</span>
      </button>
      {open && (
        <div className="mt-4 flex flex-col gap-2 max-h-96 overflow-y-auto">
          {loading && <p className="text-text-muted text-xs">Loading…</p>}
          {!loading && messages.length === 0 && <p className="text-text-muted text-xs">No chat history for this field yet.</p>}
          {messages.map((m) => (
            <div key={m.id} className={clsx('rounded-lg p-2.5 text-[13px] max-w-[85%]', m.role === 'user' ? 'bg-primary-medium/15 self-end text-text-main' : 'bg-white/5 self-start text-text-main')}>
              <p className="text-[10px] text-text-dim mb-0.5">{m.role === 'user' ? 'Farmer' : 'Advisor'} • {new Date(m.created_at).toLocaleString()}</p>
              <p>{m.content}</p>
            </div>
          ))}
        </div>
      )}
    </GlassCard>
  );
};

const AgronomistGuidancePanel: React.FC<{ fieldId: string }> = ({ fieldId }) => {
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [draft, setDraft] = useState('');
  const [sending, setSending] = useState(false);
  const [loading, setLoading] = useState(true);

  const load = useCallback(() => {
    setLoading(true);
    advisoryService.getAgronomistGuidanceHistory(fieldId)
      .then(setMessages)
      .catch((e) => { console.error(e); setMessages([]); })
      .finally(() => setLoading(false));
  }, [fieldId]);

  useEffect(() => { load(); }, [load]);

  const handleSend = async () => {
    const text = draft.trim();
    if (!text || sending) return;
    setSending(true);
    try {
      const turn = await advisoryService.sendAgronomistGuidance(fieldId, text);
      setMessages((prev) => [...prev, turn.user_message, turn.assistant_message]);
      setDraft('');
    } catch (e) {
      console.error(e);
      alert('Failed to send guidance to the AI.');
    } finally {
      setSending(false);
    }
  };

  return (
    <GlassCard glow className="p-5">
      <div className="flex items-center gap-2 mb-1">
        <Brain size={16} className="text-accent-lime" />
        <h3 className="text-sm font-bold text-text-main">Agronomist Guidance</h3>
      </div>
      <p className="text-[12px] text-text-muted mb-3">
        Instruct the AI directly for this field. Your guidance shapes future farmer-facing recommendations —
        it cannot override safety rules (approved sources, expert confirmation) on its own.
      </p>
      <div className="flex flex-col gap-2 max-h-80 overflow-y-auto mb-3">
        {loading && <p className="text-text-muted text-xs">Loading…</p>}
        {!loading && messages.length === 0 && <p className="text-text-muted text-xs">No guidance sent yet for this field.</p>}
        {messages.map((m) => (
          <div key={m.id} className={clsx('rounded-lg p-2.5 text-[13px] max-w-[90%]', m.role === 'user' ? 'bg-primary-medium/15 self-end text-text-main' : 'bg-white/5 self-start text-text-main')}>
            <p className="text-[10px] text-text-dim mb-0.5">{m.role === 'user' ? 'You' : 'AI'} • {new Date(m.created_at).toLocaleString()}</p>
            <p>{m.content}</p>
          </div>
        ))}
      </div>
      <div className="flex gap-2">
        <textarea
          className="flex-1 bg-bg-main border border-border-glass rounded text-sm p-2 text-text-main"
          placeholder="e.g. Prioritize water conservation this season for this field…"
          value={draft}
          onChange={(e) => setDraft(e.target.value)}
          rows={2}
          onKeyDown={(e) => { if (e.key === 'Enter' && !e.shiftKey) { e.preventDefault(); handleSend(); } }}
        />
        <button className="btn-primary px-3" onClick={handleSend} disabled={sending || !draft.trim()}>
          <Send size={16} />
        </button>
      </div>
    </GlassCard>
  );
};
