import React, { useMemo, useState, useEffect } from 'react';
import { useActiveField, useActiveDashboard, useFleetFields } from '../core/hooks/useFleet';
import { useFleetStore } from '../core/store/fleetStore';
import { useDashboard } from '../core/hooks/useFarmQueries';
import { useAuth } from '../core/auth/AuthContext';
import {
  usePendingRecommendations,
  useValidateRecommendation,
  useTriggerReEvaluation,
  useAnalysisRun,
  useSeasonMemory,
  useChatHistory,
  useFieldGuidance,
  useAddGuidance,
  useRetractGuidance
} from '../core/hooks/useAdvisoryHooks';
import { useToast } from '../core/ui/toast';
import { describeError } from '../core/utils/sanitize';
import { AdvisoryComposer } from '../components/advisory/AdvisoryComposer';
import { GlassCard } from '../components/ui/GlassCard';
import { MetricBadge } from '../components/ui/MetricBadge';
import { recommendationPriority, waitingFor, stalenessBand } from '../core/utils/advisory';
import {
  Sparkles, Brain, Zap, AlertTriangle, Clock, ExternalLink, MessageSquare, Send,
  BookOpen, ChevronDown, ChevronUp, ShieldCheck, FlaskConical, Inbox, Loader2,
  CheckCircle2, XCircle, Smartphone, ArrowUpDown, Trash2
} from 'lucide-react';
import clsx from 'clsx';
import type { AIRecommendation, Field } from '../core/types';

type StudioTab = 'field' | 'queue';
type QueueSort = 'oldest' | 'priority';

// ---------------------------------------------------------------------------

export const AIAdvisoryView: React.FC = () => {
  const activeField = useActiveField();
  const { fields } = useFleetFields();
  const setActiveField = useFleetStore((s) => s.setActiveField);
  const { dashboard: dashboardData } = useActiveDashboard();
  const dashboardQuery = useDashboard(activeField?.id || null);
  const { user } = useAuth();

  const isStaff = user?.role === 'admin' || user?.role === 'agronomist';

  const [tab, setTab] = useState<StudioTab>('field');
  const [selectedCategory, setSelectedCategory] = useState<string>('all');
  const [queueSort, setQueueSort] = useState<QueueSort>('oldest');
  const [reEvaluating, setReEvaluating] = useState(false);
  const [actionError, setActionError] = useState<string | null>(null);

  const { data: queueRecs = [], isLoading: queueLoading } = usePendingRecommendations();
  const triggerMutation = useTriggerReEvaluation();

  const advisor = dashboardData?.advisor;
  const fieldRecs = useMemo(() => dashboardData?.recommendations || [], [dashboardData]);

  // Only offer filters for categories that actually appear. The bar previously rendered
  // eight fixed chips, most of which matched nothing and silently emptied the list.
  const categories = useMemo(() => {
    const present = new Set(fieldRecs.map((r) => r.category).filter(Boolean));
    return ['all', ...Array.from(present).sort()];
  }, [fieldRecs]);

  useEffect(() => {
    if (!categories.includes(selectedCategory)) setSelectedCategory('all');
  }, [categories, selectedCategory]);

  const visibleFieldRecs = selectedCategory === 'all'
    ? fieldRecs
    : fieldRecs.filter((r) => r.category === selectedCategory);

  const handleForceReEvaluation = async () => {
    if (!activeField) return;
    setReEvaluating(true);
    setActionError(null);
    try {
      await triggerMutation.mutateAsync(activeField.id);
      await dashboardQuery.refetch();
    } catch (e: any) {
      setActionError(e?.message || 'Could not trigger AI re-evaluation.');
    } finally {
      setReEvaluating(false);
    }
  };

  const pendingOnActiveField = fieldRecs.filter(
    (r) => r.requires_expert_confirmation && r.expert_status === 'pending'
  ).length;

  return (
    <div className="flex flex-col gap-5 pb-10">
      {/* Header */}
      <GlassCard glow className="p-5">
        <div className="flex flex-col lg:flex-row justify-between items-start lg:items-center gap-4">
          <div className="flex items-center gap-4">
            <div className="w-12 h-12 rounded-xl flex items-center justify-center shadow-[0_0_20px_rgba(154,212,108,0.4)] shrink-0 bg-gradient-to-br from-accent-lime to-primary-light">
              <Brain size={28} className="text-[#0a170d]" />
            </div>
            <div>
              <h2 className="text-xl font-extrabold text-text-main">AI Agronomy Studio</h2>
              <p className="text-[13px] text-text-muted mt-0.5">
                {tab === 'queue'
                  ? 'High-risk AI advice awaiting an expert decision across every field you can see.'
                  : activeField
                    ? <>Multi-source synthesis for <span className="text-text-main font-semibold">{activeField.name}</span> — canopy vigour, soil telemetry and crop rules.</>
                    : 'Select a field to review its AI advice, or work the expert queue.'}
              </p>
            </div>
          </div>

          {tab === 'field' && activeField && (
            <button
              onClick={handleForceReEvaluation}
              disabled={reEvaluating}
              className="btn-primary shrink-0 disabled:opacity-50"
            >
              {reEvaluating ? <Loader2 size={16} className="animate-spin" /> : <Sparkles size={16} />}
              <span>{reEvaluating ? 'Re-evaluating…' : 'Force AI Re-Evaluation'}</span>
            </button>
          )}
        </div>

        {/* Tabs replace the old "Expert queue" / "Back to field view" toggle button, which
            gave no indication of how much was waiting behind it. */}
        {isStaff && (
          <div className="flex gap-1 mt-4 border-b border-border-subtle -mb-5 px-0">
            <TabButton active={tab === 'field'} onClick={() => setTab('field')} label="Field advisor" />
            <TabButton
              active={tab === 'queue'}
              onClick={() => setTab('queue')}
              label="Expert queue"
              count={queueRecs.length}
            />
          </div>
        )}
      </GlassCard>

      {actionError && (
        <p className="text-xs text-accent-red flex items-center gap-1.5">
          <AlertTriangle size={13} /> {actionError}
        </p>
      )}

      {tab === 'queue' && isStaff ? (
        <ExpertQueue
          recs={queueRecs}
          fields={fields}
          isLoading={queueLoading}
          sort={queueSort}
          onSortChange={setQueueSort}
          onOpenField={(field) => { setActiveField(field); setTab('field'); }}
        />
      ) : (
        <>
          {!activeField ? (
            <GlassCard className="p-10 text-center">
              <Brain size={40} className="text-border-subtle mx-auto mb-3" />
              <h3 className="text-base font-bold text-text-main mb-1.5">No field selected</h3>
              <p className="text-sm text-text-muted max-w-md mx-auto leading-relaxed">
                Pick a field from the header, the map, or the fleet triage table to see its AI
                advice, crop journal and farmer conversation.
              </p>
            </GlassCard>
          ) : (
            <>
              {/* The advisory channel sits at the top: it is the one action here that
                  reaches the farmer directly. */}
              {isStaff && <AdvisoryComposer field={activeField} />}

              {advisor && (advisor.status === 'unavailable' || advisor.status === 'stale') && (
                <GlassCard className={clsx(
                  'p-4 flex items-start gap-3 border',
                  advisor.status === 'unavailable' ? 'border-red-400/40' : 'border-amber-500/40'
                )}>
                  {advisor.status === 'unavailable'
                    ? <AlertTriangle size={18} className="text-red-400 shrink-0 mt-0.5" />
                    : <Clock size={18} className="text-amber-400 shrink-0 mt-0.5" />}
                  <div>
                    <p className="text-sm font-semibold text-text-main">
                      {advisor.status === 'unavailable' ? 'AI Advisor is unavailable' : 'Showing the last successful advice'}
                    </p>
                    <p className="text-[13px] text-text-muted">
                      {advisor.message || 'The AI Advisor could not complete the latest analysis.'}
                    </p>
                    {advisor.data_quality && (
                      <p className="text-[12px] text-text-dim mt-1">Evidence quality: {advisor.data_quality}</p>
                    )}
                  </div>
                </GlassCard>
              )}

              <div className="flex flex-wrap items-center justify-between gap-3">
                <div className="flex flex-wrap gap-2">
                  {categories.map((cat) => (
                    <button
                      key={cat}
                      onClick={() => setSelectedCategory(cat)}
                      className={clsx(
                        'px-3.5 py-1.5 rounded-full text-[11px] font-semibold cursor-pointer capitalize transition-all border',
                        selectedCategory === cat
                          ? 'bg-primary border-border-glass-bright text-white shadow-glow'
                          : 'bg-white/5 border-border-subtle text-text-muted hover:bg-white/10 hover:text-text-main'
                      )}
                    >
                      {cat.replace(/_/g, ' ')}
                      {cat === 'all' && ` (${fieldRecs.length})`}
                    </button>
                  ))}
                </div>
                {pendingOnActiveField > 0 && (
                  <MetricBadge
                    label={`${pendingOnActiveField} awaiting your review`}
                    variant="warning"
                    size="sm"
                  />
                )}
              </div>

              <div className="flex flex-col gap-3.5">
                {visibleFieldRecs.length === 0 && (
                  <GlassCard className="p-8 text-center">
                    <Inbox size={28} className="text-border-subtle mx-auto mb-2" />
                    <p className="text-sm text-text-muted">
                      {fieldRecs.length === 0
                        ? 'No AI recommendations for this field yet. Use Force AI Re-Evaluation to generate some.'
                        : 'No recommendations in this category.'}
                    </p>
                  </GlassCard>
                )}
                {visibleFieldRecs.map((rec) => (
                  <RecommendationCard
                    key={rec.id}
                    rec={rec}
                    fieldName={activeField.name}
                    ownerEmail={activeField.owner_name || activeField.owner_email}
                    isStaff={isStaff}
                  />
                ))}
              </div>

              <SeasonMemoryPanel fieldId={activeField.id} />
              <FieldChatPanel fieldId={activeField.id} />
              {isStaff && <AgronomistGuidancePanel fieldId={activeField.id} />}
            </>
          )}
        </>
      )}
    </div>
  );
};

// ---------------------------------------------------------------------------

const TabButton: React.FC<{ active: boolean; onClick: () => void; label: string; count?: number }> = ({
  active, onClick, label, count
}) => (
  <button
    onClick={onClick}
    className={clsx(
      'px-4 py-2.5 text-[13px] font-semibold border-b-2 -mb-px transition-colors flex items-center gap-2',
      active
        ? 'border-accent-lime text-accent-lime'
        : 'border-transparent text-text-muted hover:text-text-main'
    )}
  >
    {label}
    {count !== undefined && count > 0 && (
      <span className="bg-accent-orange/20 text-accent-orange text-[10px] font-bold px-1.5 py-0.5 rounded-full">
        {count}
      </span>
    )}
  </button>
);

// ---------------------------------------------------------------------------

interface ExpertQueueProps {
  recs: AIRecommendation[];
  fields: Field[];
  isLoading: boolean;
  sort: QueueSort;
  onSortChange: (sort: QueueSort) => void;
  onOpenField: (field: Field) => void;
}

const ExpertQueue: React.FC<ExpertQueueProps> = ({ recs, fields, isLoading, sort, onSortChange, onOpenField }) => {
  const fieldById = useMemo(() => new Map(fields.map((f) => [f.id, f])), [fields]);

  const sorted = useMemo(() => {
    const copy = [...recs];
    if (sort === 'priority') {
      const rank = (r: AIRecommendation) => ((r.priority || '').toLowerCase() === 'high' ? 0 : (r.priority || '').toLowerCase() === 'medium' ? 1 : 2);
      copy.sort((a, b) => rank(a) - rank(b) || new Date(a.created_at).getTime() - new Date(b.created_at).getTime());
    } else {
      // Oldest first by default: the longest-waiting item is the one most likely to have
      // gone stale in the field while nobody looked at the queue.
      copy.sort((a, b) => new Date(a.created_at).getTime() - new Date(b.created_at).getTime());
    }
    return copy;
  }, [recs, sort]);

  const stale = sorted.filter((r) => stalenessBand(waitingFor(r.created_at).hours) === 'stale').length;

  if (isLoading) {
    return (
      <GlassCard className="p-10 text-center">
        <Loader2 size={24} className="animate-spin text-primary-light mx-auto mb-2" />
        <p className="text-sm text-text-muted">Loading the expert queue…</p>
      </GlassCard>
    );
  }

  if (sorted.length === 0) {
    return (
      <GlassCard className="p-10 text-center">
        <CheckCircle2 size={36} className="text-accent-lime mx-auto mb-3" />
        <h3 className="text-base font-bold text-text-main mb-1">Queue is clear</h3>
        <p className="text-sm text-text-muted">No AI recommendation is waiting for an expert decision.</p>
      </GlassCard>
    );
  }

  return (
    <>
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div className="flex items-center gap-3">
          <span className="text-sm text-text-main font-semibold">
            {sorted.length} awaiting review
          </span>
          {stale > 0 && (
            <MetricBadge label={`${stale} waiting over 3 days`} variant="danger" size="sm" />
          )}
        </div>
        <div className="flex items-center gap-1.5">
          <ArrowUpDown size={13} className="text-text-muted" />
          <div className="flex rounded-md overflow-hidden border border-border-glass">
            {([['oldest', 'Oldest first'], ['priority', 'Priority']] as [QueueSort, string][]).map(([id, label]) => (
              <button
                key={id}
                onClick={() => onSortChange(id)}
                className={clsx(
                  'px-3 py-1 text-[11px] font-semibold transition-colors',
                  sort === id ? 'bg-primary-medium/40 text-accent-lime' : 'text-text-muted hover:text-text-main hover:bg-white/5'
                )}
              >
                {label}
              </button>
            ))}
          </div>
        </div>
      </div>

      <div className="flex flex-col gap-3.5">
        {sorted.map((rec) => {
          const field = fieldById.get(rec.field_id);
          return (
            <RecommendationCard
              key={rec.id}
              rec={rec}
              // The queue used to print a raw "Field ID: <uuid>" — unusable for deciding
              // whether advice about a field is sound.
              fieldName={field?.name}
              ownerEmail={field?.owner_name || field?.owner_email}
              isStaff
              showAge
              onOpenField={field ? () => onOpenField(field) : undefined}
            />
          );
        })}
      </div>
    </>
  );
};

// ---------------------------------------------------------------------------

interface RecommendationCardProps {
  rec: AIRecommendation;
  fieldName?: string;
  ownerEmail?: string;
  isStaff: boolean;
  showAge?: boolean;
  onOpenField?: () => void;
}

const RecommendationCard: React.FC<RecommendationCardProps> = ({
  rec, fieldName, ownerEmail, isStaff, showAge, onOpenField
}) => {
  const [showEvidence, setShowEvidence] = useState(false);
  const [reviewing, setReviewing] = useState(false);
  const [notes, setNotes] = useState('');
  const [error, setError] = useState<string | null>(null);
  const { data: run, isLoading: loadingRun } = useAnalysisRun(rec.analysis_run_id, showEvidence);
  const validateMutation = useValidateRecommendation();

  const priority = recommendationPriority(rec.priority);
  const age = waitingFor(rec.created_at);
  const staleness = stalenessBand(age.hours);
  const isPending = rec.requires_expert_confirmation && rec.expert_status === 'pending';

  const handleValidate = async (status: 'approved' | 'rejected') => {
    setError(null);
    try {
      await validateMutation.mutateAsync({ id: rec.id, status, notes });
      setReviewing(false);
      setNotes('');
    } catch (e: any) {
      setError(e?.message || 'Failed to record this decision.');
    }
  };

  return (
    <GlassCard
      glow={priority.label === 'Urgent' || rec.priority === 'high'}
      className="p-5"
      style={{ borderLeftWidth: '3px', borderLeftColor: priority.color }}
    >
      <div className="flex flex-col lg:flex-row justify-between items-start gap-4">
        <div className="flex gap-3.5 w-full min-w-0">
          <div
            className="w-9 h-9 rounded-lg flex items-center justify-center border shrink-0"
            style={{ background: `${priority.color}20`, borderColor: priority.color }}
          >
            <Zap size={18} style={{ color: priority.color }} />
          </div>

          <div className="w-full min-w-0">
            <div className="flex items-center gap-2 mb-1.5 flex-wrap">
              <h3 className="text-[15px] font-bold text-text-main capitalize">
                {(rec.category || 'recommendation').replace(/_/g, ' ')}
              </h3>
              <MetricBadge label={`${priority.label} priority`} variant={priority.badge} size="sm" />
              {isPending && <MetricBadge label="Awaiting review" variant="warning" size="sm" />}
              {rec.expert_status === 'approved' && <MetricBadge label="Expert approved" variant="success" size="sm" />}
              {rec.expert_status === 'rejected' && <MetricBadge label="Expert rejected" variant="danger" size="sm" />}
              {showAge && (
                <span
                  className={clsx(
                    'text-[10px] font-bold px-2 py-0.5 rounded-full flex items-center gap-1',
                    staleness === 'stale' ? 'bg-accent-red/20 text-accent-red'
                      : staleness === 'aging' ? 'bg-amber-500/20 text-amber-400'
                        : 'bg-white/10 text-text-muted'
                  )}
                >
                  <Clock size={10} /> waiting {age.label}
                </span>
              )}
            </div>

            <p className="text-[13px] text-text-main leading-relaxed opacity-95 mb-2">{rec.advice}</p>

            {rec.rationale && (
              <p className="text-[12px] text-text-muted italic mb-2">Rationale: {rec.rationale}</p>
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
                  <ShieldCheck size={12} className="text-accent-lime" />
                  Expert note (delivered to the farmer)
                </p>
                <p className="text-[12px] text-text-muted mt-0.5">{rec.expert_notes}</p>
              </div>
            )}

            <div className="flex flex-wrap items-center gap-x-2 gap-y-1 text-[11px] text-text-dim mt-2">
              {fieldName ? (
                onOpenField ? (
                  <button onClick={onOpenField} className="text-primary-light hover:text-accent-lime font-semibold transition-colors">
                    {fieldName}
                  </button>
                ) : <span>{fieldName}</span>
              ) : <span className="italic">Unknown field</span>}
              {ownerEmail && <><span>·</span><span>{ownerEmail}</span></>}
              <span>·</span>
              <span>{new Date(rec.created_at).toLocaleString()}</span>
            </div>

            {rec.reviewed_by_email && rec.reviewed_at && (
              <p className="text-[11px] text-accent-lime/80 mt-1 flex items-center gap-1">
                <ShieldCheck size={12} />
                Reviewed by {rec.reviewed_by_email} · {new Date(rec.reviewed_at).toLocaleString()}
              </p>
            )}

            {rec.analysis_run_id && (
              <button
                onClick={() => setShowEvidence((v) => !v)}
                className="mt-2.5 flex items-center gap-1 text-[11px] font-semibold text-primary-light hover:text-accent-lime transition-colors"
              >
                <FlaskConical size={12} />
                {showEvidence ? 'Hide evidence' : 'Show evidence'}
                {showEvidence ? <ChevronUp size={12} /> : <ChevronDown size={12} />}
              </button>
            )}

            {showEvidence && (
              <div className="mt-2 bg-black/25 border border-border-subtle rounded-lg p-3">
                {loadingRun && <p className="text-[11px] text-text-muted">Loading evidence…</p>}
                {!loadingRun && !run && (
                  <p className="text-[11px] text-text-muted">No analysis run recorded for this recommendation.</p>
                )}
                {!loadingRun && run && (
                  <div className="flex flex-col gap-2">
                    <div className="flex flex-wrap gap-1.5">
                      {run.model_name && <MetricBadge label={`Model: ${run.model_name}`} variant="info" size="sm" />}
                      {run.prompt_version && <MetricBadge label={`Prompt: ${run.prompt_version}`} variant="neutral" size="sm" />}
                      {run.policy_version && <MetricBadge label={`Policy: ${run.policy_version}`} variant="neutral" size="sm" />}
                      {run.data_quality && <MetricBadge label={`Evidence quality: ${run.data_quality}`} variant="warning" size="sm" />}
                    </div>
                    <p className="text-[11px] text-text-dim">
                      Run {run.status} · started {new Date(run.started_at).toLocaleString()}
                      {run.completed_at && ` · completed ${new Date(run.completed_at).toLocaleString()}`}
                    </p>
                    {run.error && <p className="text-[11px] text-red-400">Error: {run.error}</p>}
                    {Boolean(run.context_snapshot || run.evidence) && (
                      <details className="mt-1">
                        <summary className="text-[11px] text-text-muted cursor-pointer hover:text-text-main">
                          Raw context the AI evaluated
                        </summary>
                        <pre className="mt-2 text-[10px] text-text-muted bg-black/30 rounded p-2 overflow-x-auto max-h-64 overflow-y-auto whitespace-pre-wrap break-words">
                          {JSON.stringify({ context: run.context_snapshot, evidence: run.evidence }, null, 2)}
                        </pre>
                      </details>
                    )}
                  </div>
                )}
              </div>
            )}
          </div>
        </div>

        {isStaff && (
          <div className="flex flex-col gap-2 w-full lg:w-[300px] shrink-0">
            {reviewing ? (
              <div className="flex flex-col gap-2 bg-black/20 border border-border-subtle rounded-lg p-3">
                <label className="text-[11px] font-semibold text-text-main">
                  Note for {ownerEmail || 'the farmer'}
                </label>
                <textarea
                  className="bg-bg-main border border-border-glass rounded text-xs p-2 text-text-main outline-none focus:border-accent-lime transition-colors"
                  placeholder="Why you agree or disagree, and what the farmer should actually do."
                  value={notes}
                  onChange={(e) => setNotes(e.target.value)}
                  rows={3}
                />
                {/* The old UI labelled this box "Add notes for the farmer..." while the
                    backend never delivered it. It does now, so the promise is stated. */}
                <p className="text-[10px] text-accent-cyan flex items-start gap-1 leading-relaxed">
                  <Smartphone size={11} className="shrink-0 mt-0.5" />
                  This note is delivered to the farmer's iOS notification inbox with your decision.
                </p>
                <div className="flex gap-2 flex-wrap">
                  <button
                    className="btn-primary py-1.5 px-3 text-xs flex items-center gap-1.5 disabled:opacity-50"
                    disabled={validateMutation.isPending}
                    onClick={() => handleValidate('approved')}
                  >
                    {validateMutation.isPending ? <Loader2 size={13} className="animate-spin" /> : <CheckCircle2 size={13} />}
                    Approve &amp; notify
                  </button>
                  <button
                    className="btn-danger py-1.5 px-3 text-xs flex items-center gap-1.5 disabled:opacity-50"
                    disabled={validateMutation.isPending}
                    onClick={() => handleValidate('rejected')}
                  >
                    <XCircle size={13} />
                    Reject &amp; notify
                  </button>
                  <button
                    className="text-xs text-text-muted hover:text-text-main px-2 py-1"
                    onClick={() => { setReviewing(false); setNotes(''); setError(null); }}
                  >
                    Cancel
                  </button>
                </div>
                {error && (
                  <p className="text-[11px] text-accent-red flex items-center gap-1">
                    <AlertTriangle size={11} /> {error}
                  </p>
                )}
              </div>
            ) : (
              <button
                className={clsx('py-1.5 px-3 text-xs', isPending ? 'btn-primary' : 'btn-secondary')}
                onClick={() => { setReviewing(true); setNotes(rec.expert_notes || ''); }}
              >
                {rec.expert_status === 'pending' ? 'Review' : 'Revise decision'}
              </button>
            )}
          </div>
        )}
      </div>
    </GlassCard>
  );
};

// ---------------------------------------------------------------------------

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

  useEffect(() => { setOpen(false); }, [fieldId]);

  return (
    <GlassCard className="p-5">
      <button className="flex items-center justify-between w-full" onClick={() => setOpen((v) => !v)}>
        <div className="flex items-center gap-2">
          <MessageSquare size={16} className="text-accent-lime" />
          <h3 className="text-sm font-bold text-text-main">Farmer AI Chat History</h3>
        </div>
        <span className="text-xs text-text-muted flex items-center gap-1">
          {open ? 'Hide' : 'Show'} {open ? <ChevronUp size={13} /> : <ChevronDown size={13} />}
        </span>
      </button>
      {open && (
        <div className="mt-4 flex flex-col gap-2 max-h-96 overflow-y-auto">
          {isLoading && <p className="text-text-muted text-xs">Loading…</p>}
          {!isLoading && messages.length === 0 && (
            <p className="text-text-muted text-xs">No chat history for this field yet.</p>
          )}
          {messages.map((m: any) => (
            <div
              key={m.id}
              className={clsx(
                'rounded-lg p-2.5 text-[13px] max-w-[85%]',
                m.role === 'user' ? 'bg-primary-medium/15 self-end text-text-main' : 'bg-white/5 self-start text-text-main'
              )}
            >
              <p className="text-[10px] text-text-dim mb-0.5">
                {m.role === 'user' ? 'Farmer' : 'Advisor'} · {new Date(m.created_at).toLocaleString()}
              </p>
              <p>{m.content}</p>
            </div>
          ))}
        </div>
      )}
    </GlassCard>
  );
};

function relativeSince(iso: string | null): string {
  if (!iso) return '';
  const ms = Date.now() - new Date(iso).getTime();
  if (Number.isNaN(ms)) return '';
  const mins = Math.floor(ms / 60000);
  if (mins < 1) return 'just now';
  if (mins < 60) return `${mins}m ago`;
  const hours = Math.floor(mins / 60);
  if (hours < 24) return `${hours}h ago`;
  return `${Math.floor(hours / 24)}d ago`;
}

const GUIDANCE_MAX = 2000;

const AgronomistGuidancePanel: React.FC<{ fieldId: string }> = ({ fieldId }) => {
  const dashboardQuery = useDashboard(fieldId);
  const { data: directives = [], isLoading } = useFieldGuidance(fieldId);
  const addGuidance = useAddGuidance();
  const retractGuidance = useRetractGuidance();
  const toast = useToast();
  const [draft, setDraft] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [pendingId, setPendingId] = useState<string | null>(null);

  const active = directives.filter((d) => d.status === 'active');
  const history = directives.filter((d) => d.status !== 'active');
  const busy = addGuidance.isPending || retractGuidance.isPending;

  // A forced recommendation re-run is queued the moment guidance changes, but the model
  // call itself takes a few seconds — nudge the dashboard a few times so the new advice
  // surfaces without the agronomist reaching for a manual refresh.
  const chaseRecommendations = () => {
    [7000, 18000, 35000].forEach((delay) => window.setTimeout(() => dashboardQuery.refetch(), delay));
  };

  const handleAdd = async () => {
    const text = draft.trim();
    if (!text || busy) return;
    setError(null);
    try {
      const result = await addGuidance.mutateAsync({ fieldId, text });
      setDraft('');
      if (result.deduplicated) {
        toast.info('That instruction is already active for this field.');
      } else {
        toast.success('Guidance saved. Recommendations are regenerating, and the farmer has been notified.');
        chaseRecommendations();
      }
    } catch (e) {
      const msg = describeError(e, 'Failed to save guidance.');
      setError(msg);
      toast.fromError(e, 'Failed to save guidance.');
    }
  };

  const handleRetract = async (directiveId: string) => {
    if (busy) return;
    setError(null);
    setPendingId(directiveId);
    try {
      await retractGuidance.mutateAsync({ fieldId, directiveId });
      toast.success('Guidance removed. Recommendations are regenerating, and the farmer has been notified.');
      chaseRecommendations();
    } catch (e) {
      setError(describeError(e, 'Failed to remove guidance.'));
      toast.fromError(e, 'Failed to remove guidance.');
    } finally {
      setPendingId(null);
    }
  };

  return (
    <GlassCard className="p-5">
      <div className="flex items-center gap-2 mb-1">
        <Brain size={16} className="text-accent-lime" />
        <h3 className="text-sm font-bold text-text-main">Agronomist Guidance (to the AI)</h3>
      </div>
      <p className="text-[12px] text-text-muted mb-3 leading-relaxed">
        Standing instructions that steer this field's automated recommendations. Adding or removing one
        <span className="text-text-main font-semibold"> immediately regenerates the recommendations</span> and
        notifies the farmer that a change was made. It cannot override the model's hard safety rules. To send
        the farmer advice directly, use <span className="text-accent-cyan font-semibold">Send Advice to Farmer</span> above.
      </p>

      <div className="flex flex-col gap-2 mb-3">
        {isLoading && <p className="text-text-muted text-xs">Loading…</p>}
        {!isLoading && active.length === 0 && (
          <p className="text-text-muted text-xs">No active guidance. The AI is running on evidence alone for this field.</p>
        )}
        {active.map((d) => (
          <div key={d.id} className="rounded-lg border border-primary-light/30 bg-primary-medium/10 p-2.5">
            <p className="text-[13px] text-text-main">{d.text}</p>
            <div className="flex items-center justify-between mt-1.5">
              <span className="text-[10px] text-text-dim">
                {d.created_by_name || d.created_by_email || 'Agronomist'} · {relativeSince(d.created_at)}
                {d.applied_run_id
                  ? <span className="text-accent-lime"> · applied to recommendations</span>
                  : <span className="text-accent-orange"> · applying…</span>}
              </span>
              <button
                onClick={() => handleRetract(d.id)}
                disabled={busy}
                className="inline-flex items-center gap-1 text-[11px] text-text-dim hover:text-accent-red transition-colors disabled:opacity-40"
                title="Remove this guidance"
              >
                {pendingId === d.id ? <Loader2 size={12} className="animate-spin" /> : <Trash2 size={12} />}
                Remove
              </button>
            </div>
          </div>
        ))}
      </div>

      {history.length > 0 && (
        <details className="mb-3">
          <summary className="text-[11px] text-text-dim cursor-pointer hover:text-text-muted">
            {history.length} past directive{history.length === 1 ? '' : 's'}
          </summary>
          <div className="flex flex-col gap-1.5 mt-2">
            {history.map((d) => (
              <div key={d.id} className="rounded-md bg-white/5 p-2 text-[12px] text-text-muted line-through decoration-text-dim/60">
                {d.text}
                <span className="not-italic no-underline block text-[10px] text-text-dim mt-0.5">
                  {d.status === 'superseded_by_replant' ? 'ended with the previous crop' : 'removed'} · {relativeSince(d.retracted_at)}
                </span>
              </div>
            ))}
          </div>
        </details>
      )}

      <div className="flex gap-2">
        <textarea
          className="flex-1 bg-bg-main border border-border-glass rounded text-sm p-2 text-text-main outline-none focus:border-accent-lime transition-colors"
          placeholder="e.g. Prioritise water conservation this season for this field…"
          value={draft}
          maxLength={GUIDANCE_MAX}
          onChange={(e) => { setDraft(e.target.value); if (error) setError(null); }}
          rows={2}
          onKeyDown={(e) => { if (e.key === 'Enter' && !e.shiftKey) { e.preventDefault(); handleAdd(); } }}
        />
        <button
          className="btn-primary px-3 disabled:opacity-50"
          onClick={handleAdd}
          disabled={busy || draft.trim().length < 3}
        >
          {addGuidance.isPending ? <Loader2 size={16} className="animate-spin" /> : <Send size={16} />}
        </button>
      </div>
      {error && (
        <p className="text-[11px] text-accent-red mt-2 flex items-center gap-1">
          <AlertTriangle size={11} /> {error}
        </p>
      )}
    </GlassCard>
  );
};
