import React, { useState, useEffect } from 'react';
import { useFleetStore } from '../core/store/fleetStore';
import { useIoTStore } from '../core/store/iotStore';
import { useDashboard } from '../core/hooks/useFarmQueries';
import { useAuth } from '../core/auth/AuthContext';
import { 
  usePendingRecommendations, 
  useValidateRecommendation, 
  useTriggerReEvaluation,
  useSeasonMemory,
  useChatHistory,
  useGuidanceHistory,
  useSendGuidance
} from '../core/hooks/useAdvisoryHooks';
import { GlassCard } from '../components/ui/GlassCard';
import { MetricBadge } from '../components/ui/MetricBadge';
import { Sparkles, Brain, Zap, AlertTriangle, Clock, ExternalLink, MessageSquare, Send, BookOpen } from 'lucide-react';
import clsx from 'clsx';

const CATEGORY_FILTERS = ['all', 'irrigation', 'plant_health', 'weather_alert', 'fertilizer_window', 'harvest_timing', 'pest_risk', 'field_monitoring'];

export const AIAdvisoryView: React.FC = () => {
  const activeField = useFleetStore(s => s.activeField);
  const dashboardData = useIoTStore(s => s.dashboardData);
  const dashboardQuery = useDashboard(activeField?.id || null);
  const refreshActiveFieldData = () => dashboardQuery.refetch();
  const { user } = useAuth();
  const [selectedFilter, setSelectedFilter] = useState<string>('all');
  const [validating, setValidating] = useState<string | null>(null);
  const [validationNotes, setValidationNotes] = useState('');
  const [showQueue, setShowQueue] = useState(false);
  const [reEvaluating, setReEvaluating] = useState(false);

  const isAgronomist = user?.role === 'agronomist';
  const isStaff = user?.role === 'admin' || user?.role === 'agronomist';

  const { data: agronomistRecs = [] } = usePendingRecommendations();
  const validateMutation = useValidateRecommendation();
  const triggerMutation = useTriggerReEvaluation();

  const handleValidate = async (id: string, status: 'approved' | 'rejected') => {
    try {
      await validateMutation.mutateAsync({ id, status, notes: validationNotes });
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
      await triggerMutation.mutateAsync(activeField.id);
      await refreshActiveFieldData();
    } catch (e: any) {
      console.error(e);
      alert(e.message || 'Could not trigger AI re-evaluation.');
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
                      <div className="flex gap-2 flex-wrap">
                        <button className="btn-primary py-1 px-2 text-xs bg-gradient-to-r from-accent-lime to-[#4ade80] hover:brightness-110 border-transparent text-[#0a170d]" onClick={() => handleValidate(rec.id, 'approved')}>
                          <Send size={14} />
                          Approve & Publish to iOS
                        </button>
                        <button className="btn-danger py-1 px-2 text-xs" onClick={() => handleValidate(rec.id, 'rejected')}>Reject & Discard</button>
                        <button className="text-xs text-text-muted hover:text-text-main px-2 py-1" onClick={() => { setValidating(null); setValidationNotes(''); }}>Cancel</button>
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

      {!showQueue && activeField && <SeasonMemoryPanel fieldId={activeField.id} />}
      {!showQueue && activeField && <FieldChatPanel fieldId={activeField.id} />}
      {!showQueue && isStaff && activeField && <AgronomistGuidancePanel fieldId={activeField.id} />}
    </div>
  );
};

const SeasonMemoryPanel: React.FC<{ fieldId: string }> = ({ fieldId }) => {
  const { data: memory, isLoading } = useSeasonMemory(fieldId);

  if (!isLoading && !memory?.narrative) return null;

  return (
    <GlassCard className="p-5">
      <div className="flex items-center gap-2 mb-1">
        <BookOpen size={16} className="text-accent-lime" />
        <h3 className="text-sm font-bold text-text-main">Crop Journal</h3>
      </div>
      <p className="text-[12px] text-text-muted mb-3">
        The AI's compressed, whole-season narrative for this field's current crop cycle — fusing satellite,
        sensor, and farmer-reported context over time.
      </p>
      {isLoading && <p className="text-text-muted text-xs">Loading…</p>}
      {!isLoading && memory?.narrative && (
        <>
          <p className="text-[13px] text-text-main leading-relaxed">{memory.narrative}</p>
          {memory.key_events.length > 0 && (
            <div className="flex flex-col gap-1 mt-3">
              {memory.key_events.map((event: any, i: number) => (
                <p key={i} className="text-[12px] text-text-muted">• {event.description}</p>
              ))}
            </div>
          )}
        </>
      )}
    </GlassCard>
  );
};

const FieldChatPanel: React.FC<{ fieldId: string }> = ({ fieldId }) => {
  const [open, setOpen] = useState(false);
  const { data: messages = [], isLoading } = useChatHistory(open ? fieldId : undefined);

  useEffect(() => {
    setOpen(false);
  }, [fieldId]);

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
          {isLoading && <p className="text-text-muted text-xs">Loading…</p>}
          {!isLoading && messages.length === 0 && <p className="text-text-muted text-xs">No chat history for this field yet.</p>}
          {messages.map((m: any) => (
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
  const dashboardQuery = useDashboard(fieldId);
  const refreshActiveFieldData = () => dashboardQuery.refetch();
  const { data: messages = [], isLoading } = useGuidanceHistory(fieldId);
  const sendGuidance = useSendGuidance();
  const [draft, setDraft] = useState('');

  const handleSend = async () => {
    const text = draft.trim();
    if (!text || sendGuidance.isPending) return;
    try {
      await sendGuidance.mutateAsync({ fieldId, text });
      setDraft('');
      // Give the backend's fingerprint-triggered AI reconsideration a moment, then nudge one
      // extra dashboard refresh instead of waiting for the normal 5-minute reactive-tier poll.
      setTimeout(() => { refreshActiveFieldData(); }, 6000);
    } catch (e) {
      console.error(e);
      alert('Failed to send guidance to the AI.');
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
        {isLoading && <p className="text-text-muted text-xs">Loading…</p>}
        {!isLoading && messages.length === 0 && <p className="text-text-muted text-xs">No guidance sent yet for this field.</p>}
        {messages.map((m: any) => (
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
        <button className="btn-primary px-3" onClick={handleSend} disabled={sendGuidance.isPending || !draft.trim()}>
          <Send size={16} />
        </button>
      </div>
    </GlassCard>
  );
};
