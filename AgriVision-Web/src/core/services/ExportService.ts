import { http } from '../api/http';

/**
 * CSV exports for a single field. These endpoints stream server-side and were already
 * implemented in the backend but unreachable from the UI — an agronomist who wants to take
 * a field's history into a spreadsheet or share it with a farmer had no way to get it out.
 */
export type ExportKind = 'sensor-readings' | 'recommendations' | 'observations' | 'satellite-scenes';

export const EXPORT_KINDS: { id: ExportKind; label: string; description: string }[] = [
  { id: 'sensor-readings', label: 'Sensor readings', description: 'Raw probe telemetry' },
  { id: 'recommendations', label: 'AI recommendations', description: 'Advice, review status and outcomes' },
  { id: 'observations', label: 'Field observations', description: 'Weather, soil and UV history' },
  { id: 'satellite-scenes', label: 'Satellite scenes', description: 'Scene metadata and indices' },
];

function safeFilePart(value: string): string {
  return value.replace(/[^a-z0-9]+/gi, '-').replace(/^-|-$/g, '').toLowerCase() || 'field';
}

export class ExportService {
  async downloadFieldCsv(fieldId: string, fieldName: string, kind: ExportKind): Promise<void> {
    const stamp = new Date().toISOString().slice(0, 10);
    await http.downloadFile(
      `/api/fields/${fieldId}/export/${kind}`,
      `agrivision-${safeFilePart(fieldName)}-${kind}-${stamp}.csv`
    );
  }
}

export const exportService = new ExportService();
