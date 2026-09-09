import React, { useState } from 'react';
import { useAdvisories, useSendAdvisory } from '../../core/hooks/useAdvisoryHooks';
import { PRIORITY_PRESENTATION, ADVISORY_PRIORITIES } from '../../core/utils/advisory';
import { GlassCard } from '../ui/GlassCard';
import { MetricBadge } from '../ui/MetricBadge';
import { Send, Smartphone, CheckCircle2, AlertTriangle, Loader2, Inbox, Eye, EyeOff } from 'lucide-react';
import clsx from 'clsx';
import type { AdvisoryPriority, Field } from '../../core/types';

/**
 * Direct advice from the agronomist to the farmer, delivered to the iOS notification inbox.
 *
 * This is the channel the studio was missing. "Agronomist Guidance" below it addresses the
 * AI; approving a recommendation emits an automatic line. Neither let an expert say
 * something of their own to the person who has to walk the field.
 */

const TEMPLATES: { label: string; title: string; message: string; priority: AdvisoryPriority }[] = [
  {
    label: 'Irrigation call',
    title: 'Irrigation recommended',
    message: 'Soil moisture in this field has dropped below the level I am comfortable with. Please irrigate within the next 24 hours and let me know once done.',
    priority: 'high',
  },
  {
    label: 'Scouting request',
    title: 'Please scout this field',
    message: 'Satellite imagery shows an area of this field I would like eyes on. Please walk it and send photographs of anything unusual on the leaves or stems.',
    priority: 'normal',
  },
  {
    label: 'Hold off',
    title: 'Hold off on planned application',
    message: 'Please do not apply anything to this field until we have spoken. Conditions have changed since the last recommendation.',
    priority: 'urgent',
  },
];

const MAX_TITLE = 120;
const MAX_MESSAGE = 4000;

export const AdvisoryComposer: React.FC<{ field: Field }> = ({ field }) => {
  const { data: sent = [], isLoading } = useAdvisories(field.id);
  const sendAdvisory = useSendAdvisory();

  const [title, setTitle] = useState('');
  const [message, setMessage] = useState('');
  const [priority, setPriority] = useState<AdvisoryPriority>('normal');
  const [error, setError] = useState<string | null>(null);
  const [confirmation, setConfirmation] = useState<string | null>(null);
  const [showHistory, setShowHistory] = useState(false);

  const canSend = title.trim().length >= 3 && message.trim().length >= 3 && !sendAdvisory.isPending;

  const applyTemplate = (template: typeof TEMPLATES[number]) => {
    setTitle(template.title);
    setMessage(template.message);
    setPriority(template.priority);
    setError(null);
  };

  const handleSend = async () => {
    if (!canSend) return;
    setError(null);
    setConfirmation(null);
    try {
      await sendAdvisory.mutateAsync({
        fieldId: field.id,
        advisory: { title: title.trim(), message: message.trim(), priority },
      });
      setConfirmation(
        `Delivered to ${field.owner_email || 'the field owner'}'s notification inbox.`
      );
      setTitle('');
      setMessage('');
      setPriority('normal');
      setShowHistory(true);
      window.setTimeout(() => setConfirmation(null), 6000);
    } catch (e: any) {
      setError(e?.message || 'Could not send this advisory. Please try again.');
    }
  };

  return (
    <GlassCard glow className="p-5 border-accent-cyan/25">
      <div className="flex flex-wrap items-start justify-between gap-3 mb-1">
        <div className="flex items-center gap-2">
          <Smartphone size={16} className="text-accent-cyan" />
          <h3 className="text-sm font-bold text-text-main">Send Advice to Farmer</h3>
        </div>
        <div className="flex items-center gap-2">
          {sent.length > 0 && (
            <button
              onClick={() => setShowHistory((v) => !v)}
              className="text-[11px] text-text-muted hover:text-text-main transition-colors flex items-center gap-1"
            >
              {showHistory ? <EyeOff size={12} /> : <Eye size={12} />}
              {showHistory ? 'Hide' : 'Show'} sent ({sent.length})
            </button>
          )}
        </div>
      </div>
      <p className="text-[12px] text-text-muted mb-3.5 leading-relaxed">
        Goes straight to{' '}
        <span className="text-accent-cyan font-semibold">{field.owner_email || 'the field owner'}</span>{' '}
        in the AgriVision iOS app, tagged to <span className="text-text-main font-semibold">{field.name}</span>.
        This is your own words — not an AI recommendation and not subject to AI review.
      </p>

      {/* Templates: the three things an agronomist most often needs to say, so a routine
          message is two clicks rather than a blank box. */}
      <div className="flex flex-wrap gap-1.5 mb-3">
        {TEMPLATES.map((template) => (
          <button
            key={template.label}
            onClick={() => applyTemplate(template)}
            className="text-[11px] px-2.5 py-1 rounded-full bg-white/5 border border-border-subtle text-text-muted hover:text-text-main hover:bg-white/10 transition-colors"
          >
            {template.label}
          </button>
        ))}
      </div>

      <div className="flex flex-col gap-2.5">
        <div>
          <div className="flex justify-between items-baseline mb-1">
            <label className="text-[11px] font-semibold text-text-muted">Subject</label>
            <span className="text-[10px] text-text-dim">{title.length}/{MAX_TITLE}</span>
          </div>
          <input
            type="text"
            value={title}
            maxLength={MAX_TITLE}
            onChange={(e) => { setTitle(e.target.value); setError(null); }}
            placeholder="e.g. Irrigate the north block before Thursday"
            className="w-full bg-bg-main border border-border-glass rounded-md px-3 py-2 text-sm text-text-main outline-none focus:border-accent-cyan transition-colors"
          />
        </div>

        <div>
          <div className="flex justify-between items-baseline mb-1">
            <label className="text-[11px] font-semibold text-text-muted">Message</label>
            <span className="text-[10px] text-text-dim">{message.length}/{MAX_MESSAGE}</span>
          </div>
          <textarea
            value={message}
            maxLength={MAX_MESSAGE}
            onChange={(e) => { setMessage(e.target.value); setError(null); }}
            rows={4}
            placeholder="What should the farmer do, and by when? Be specific — this arrives as a notification on their phone."
            className="w-full bg-bg-main border border-border-glass rounded-md px-3 py-2 text-sm text-text-main outline-none focus:border-accent-cyan transition-colors resize-y"
          />
        </div>

        <div className="flex flex-wrap items-center justify-between gap-3">
          <div className="flex items-center gap-2">
            <span className="text-[11px] font-semibold text-text-muted">Priority</span>
            <div className="flex rounded-md overflow-hidden border border-border-glass">
              {ADVISORY_PRIORITIES.map((p) => {
                const presentation = PRIORITY_PRESENTATION[p];
                const selected = priority === p;
                return (
                  <button
                    key={p}
                    onClick={() => setPriority(p)}
                    className={clsx(
                      'px-2.5 py-1 text-[11px] font-semibold transition-colors',
                      !selected && 'text-text-muted hover:text-text-main hover:bg-white/5'
                    )}
                    style={selected ? { background: `${presentation.color}25`, color: presentation.color } : undefined}
                  >
                    {presentation.label}
                  </button>
                );
              })}
            </div>
          </div>

          <button
            onClick={handleSend}
            disabled={!canSend}
            className="btn-primary px-4 py-2 text-xs flex items-center gap-2 disabled:opacity-40 disabled:cursor-not-allowed"
          >
            {sendAdvisory.isPending ? <Loader2 size={14} className="animate-spin" /> : <Send size={14} />}
            {sendAdvisory.isPending ? 'Sending…' : 'Send to farmer'}
          </button>
        </div>

        {error && (
          <p className="text-[12px] text-accent-red flex items-center gap-1.5">
            <AlertTriangle size={13} /> {error}
          </p>
        )}
        {confirmation && (
          <p className="text-[12px] text-accent-lime flex items-center gap-1.5">
            <CheckCircle2 size={13} /> {confirmation}
          </p>
        )}
      </div>

      {showHistory && (
        <div className="mt-4 pt-4 border-t border-border-subtle">
          <div className="flex items-center gap-1.5 mb-2.5">
            <Inbox size={13} className="text-text-muted" />
            <h4 className="text-[12px] font-semibold text-text-main">Previously sent on this field</h4>
          </div>
          {isLoading && <p className="text-[11px] text-text-muted">Loading…</p>}
          {!isLoading && sent.length === 0 && (
            <p className="text-[11px] text-text-muted italic">Nothing sent on this field yet.</p>
          )}
          <div className="flex flex-col gap-2 max-h-72 overflow-y-auto">
            {sent.map((advisory) => {
              const presentation = PRIORITY_PRESENTATION[advisory.priority] ?? PRIORITY_PRESENTATION.normal;
              return (
                <div
                  key={advisory.id}
                  className="rounded-lg border border-border-subtle bg-black/20 p-2.5"
                  style={{ borderLeftWidth: '3px', borderLeftColor: presentation.color }}
                >
                  <div className="flex flex-wrap items-center gap-2 mb-1">
                    <span className="text-[12px] font-bold text-text-main">{advisory.title}</span>
                    <MetricBadge label={presentation.label} variant={presentation.badge} size="sm" />
                    {/* Read receipt: whether the farmer has actually opened it. */}
                    <MetricBadge
                      label={advisory.is_read ? 'Read' : 'Unread'}
                      variant={advisory.is_read ? 'success' : 'neutral'}
                      size="sm"
                    />
                  </div>
                  <p className="text-[12px] text-text-muted leading-relaxed whitespace-pre-wrap">{advisory.body}</p>
                  <p className="text-[10px] text-text-dim mt-1.5">
                    {advisory.created_by_email || 'Unknown sender'} · {new Date(advisory.created_at).toLocaleString()}
                  </p>
                </div>
              );
            })}
          </div>
        </div>
      )}
    </GlassCard>
  );
};
