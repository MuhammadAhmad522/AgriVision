/**
 * Client-side input sanitization + validation helpers.
 *
 * These are a UX / defense-in-depth layer only — the backend (Pydantic StrictModel,
 * Firebase, DB constraints) remains the real authority. The goal here is: never send
 * obviously-garbage input, give the user an immediate reason why, and never let raw
 * control characters or unbounded strings into a request body.
 */

// C0 controls + DEL + C1 controls. Multiline variant preserves tab and newline.
const CONTROL_CHARS_SINGLELINE = new RegExp('[\\u0000-\\u001F\\u007F-\\u009F]', 'g');
const CONTROL_CHARS_MULTILINE = new RegExp('[\\u0000-\\u0008\\u000B\\u000C\\u000E-\\u001F\\u007F-\\u009F]', 'g');

export interface CleanTextOptions {
  maxLen?: number;
  multiline?: boolean;
  /** Collapse runs of internal whitespace to a single space (single-line fields). */
  collapseWhitespace?: boolean;
}

/** Trim, remove control chars, optionally collapse whitespace, and hard-cap length. */
export function cleanText(value: string, opts: CleanTextOptions = {}): string {
  const { maxLen = 2000, multiline = false, collapseWhitespace = !multiline } = opts;
  let out = (value ?? '').normalize('NFC');
  out = out.replace(multiline ? CONTROL_CHARS_MULTILINE : CONTROL_CHARS_SINGLELINE, '');
  if (collapseWhitespace) out = out.replace(/[^\S\r\n]{2,}/g, ' ');
  if (multiline) out = out.replace(/\n{3,}/g, '\n\n');
  out = out.trim();
  if (out.length > maxLen) out = out.slice(0, maxLen).trim();
  return out;
}

/** Single-line convenience: no newlines, collapsed whitespace, capped. */
export function cleanSingleLine(value: string, maxLen = 200): string {
  return cleanText(value, { maxLen, multiline: false, collapseWhitespace: true }).replace(/[\r\n]+/g, ' ');
}

/** True when the string has non-whitespace content after cleaning. */
export function hasContent(value: string): boolean {
  return cleanText(value, { collapseWhitespace: true }).length > 0;
}

// ---- email -------------------------------------------------------------------

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/;

export function normalizeEmail(value: string): string {
  return cleanSingleLine(value, 254).toLowerCase();
}

export function isValidEmail(value: string): boolean {
  const v = normalizeEmail(value);
  return v.length <= 254 && EMAIL_RE.test(v);
}

// ---- person / display name -------------------------------------------------

// Letters (any script), marks, spaces, and a small set of name punctuation.
const NAME_RE = /^[\p{L}\p{M}][\p{L}\p{M}\p{Zs}.'\-]*$/u;

export function cleanDisplayName(value: string): string {
  return cleanSingleLine(value, 80);
}

export function isValidDisplayName(value: string): boolean {
  const v = cleanDisplayName(value);
  return v.length >= 2 && v.length <= 80 && NAME_RE.test(v);
}

// ---- identifiers ----------------------------------------------------------

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export function isUuid(value: string): boolean {
  return UUID_RE.test((value ?? '').trim());
}

/** Short alphanumeric pairing / verification codes (e.g. sensor pairing). */
export function cleanPairingCode(value: string): string {
  return (value ?? '').replace(/[^A-Za-z0-9-]/g, '').toUpperCase().slice(0, 32);
}

// ---- password ------------------------------------------------------------

export interface PasswordCheck {
  ok: boolean;
  reason?: string;
}

export function checkPassword(pw: string, confirm?: string): PasswordCheck {
  // Do not alter the interior — only guard against accidental wrapping whitespace and absurd length.
  const value = (pw ?? '').replace(/^\s+|\s+$/g, '');
  if (value.length < 8) return { ok: false, reason: 'Password must be at least 8 characters long.' };
  if (value.length > 128) return { ok: false, reason: 'Password must be 128 characters or fewer.' };
  if (/[\u0000-\u001F\u007F-\u009F]/.test(value)) return { ok: false, reason: 'Password contains invalid control characters.' };
  if (confirm !== undefined && value !== (confirm ?? '').replace(/^\s+|\s+$/g, '')) {
    return { ok: false, reason: 'Passwords do not match.' };
  }
  return { ok: true };
}

// ---- AI configuration whitelist ----------------------------------------

export const ALLOWED_AI_MODES = ['free', 'vertex'] as const;
export const ALLOWED_AI_MODELS = [
  'gemini-3.7-flash',
  'gemini-3.6-flash',
  'gemini-3.5-flash',
  'gemini-3.5-flash-lite',
] as const;

export type AiMode = (typeof ALLOWED_AI_MODES)[number];
export type AiModel = (typeof ALLOWED_AI_MODELS)[number];

export function isAllowedAiMode(v: string): v is AiMode {
  return (ALLOWED_AI_MODES as readonly string[]).includes(v);
}
export function isAllowedAiModel(v: string): v is AiModel {
  return (ALLOWED_AI_MODELS as readonly string[]).includes(v);
}

// ---- error description -------------------------------------------------

/** Turn any thrown value into a short, user-safe sentence. */
export function describeError(err: unknown, fallback = 'Something went wrong. Please try again.'): string {
  if (!err) return fallback;
  const anyErr = err as any;
  const raw =
    (typeof anyErr?.message === 'string' && anyErr.message) ||
    (typeof err === 'string' && err) ||
    '';
  const msg = cleanSingleLine(String(raw || fallback), 300);
  const status = anyErr?.statusCode ?? anyErr?.status;
  if (status === 401 || anyErr?.code === 'unauthorized') return 'Your session has expired. Please sign in again.';
  if (status === 403 || anyErr?.code === 'forbidden') return 'You do not have permission to do that.';
  if (status === 404) return msg || 'That item no longer exists.';
  if (status === 429) return msg || 'Rate limit reached. Please wait a moment and retry.';
  if (status && status >= 500) return msg || 'The server had a problem completing that request.';
  if (anyErr?.name === 'TypeError' && /fetch/i.test(msg)) return 'Cannot reach the server. Check your connection.';
  return msg || fallback;
}
