export interface Coordinate {
  lat?: number;
  lng?: number;
  latitude?: number;
  longitude?: number;
}

export interface Field {
  id: string;
  owner_id?: string;
  owner_email?: string;
  /** Farmer's display name from their Firebase profile; may be absent — fall back to owner_email. */
  owner_name?: string | null;
  name: string;
  crop_type: string;
  area_ha: number;
  plantation_date: string;
  expected_harvest_date: string | null;
  coordinates: Coordinate[];
  status: string;
  /** Backend field name is `latest_ndvi`. There is no `ndvi_score` — reading that returned
   * undefined for every field, which is why the map used to paint them all one colour. */
  latest_ndvi?: number;
  latest_health_score?: number;
  latest_health_label?: string;
  latest_health_rationale?: string;
  latest_health_updated_at?: string;
  agro_status?: string;
  last_satellite_sync?: string;
}

export interface SensorReading {
  id: string;
  sensor_id: string;
  time: string;
  temperature?: number;
  moisture?: number;
  humidity?: number;
  ph?: number;
  ec?: number;
  npk_n?: number;
  npk_p?: number;
  npk_k?: number;
}

export interface SensorReadingHourly {
  bucket: string;
  sensor_id: string;
  temperature_avg?: number | null;
  temperature_min?: number | null;
  temperature_max?: number | null;
  moisture_avg?: number | null;
  moisture_min?: number | null;
  moisture_max?: number | null;
  humidity_avg?: number | null;
  humidity_min?: number | null;
  humidity_max?: number | null;
  ph_avg?: number | null;
  ec_avg?: number | null;
  npk_n_avg?: number | null;
  npk_p_avg?: number | null;
  npk_k_avg?: number | null;
  reading_count: number;
}

export interface SensorDevice {
  id: string;
  field_id?: string;
  device_id: string;
  name?: string;
  sensor_type: string;
  /** Staff manage hardware across many farmers, so a probe names its owner and field. */
  owner_id?: string | null;
  owner_email?: string | null;
  owner_name?: string | null;
  field_name?: string | null;
  battery_level?: number;
  last_seen?: string;
}

export interface SatelliteStats {
  mean?: number;
  min?: number;
  max?: number;
  std?: number;
}

export interface DashboardSources {
  sensors: {
    status: string;
    configured_count: number;
    data?: SensorReading[];
  };
  satellite: {
    status: string;
    last_updated?: string;
    message?: string;
    data?: {
      scene_id?: string;
      acquired_at?: string;
      cloud_percent?: number;
      coverage_percent?: number;
      ndvi_image_url?: string;
      truecolor_image_url?: string;
      /** Tile templates already carry a `?v=<scene timestamp>` cache-buster. Always use
       * these rather than rebuilding the path, or new imagery never replaces cached tiles. */
      ndvi_tile_url?: string;
      ndwi_tile_url?: string;
      evi_tile_url?: string;
      truecolor_tile_url?: string;
      statistics?: Record<string, SatelliteStats>;
    };
  };
  soil: {
    status: string;
    data?: {
      moisture?: number;
      surface_temp_c?: number;
      depth_temp_c?: number;
    };
  };
  weather: {
    status: string;
    data?: {
      current: {
        temp_c?: number;
        humidity?: number;
        description?: string;
      };
      forecast_days: Array<{
        date: string;
        temp_max_c?: number;
        temp_min_c?: number;
        rain_mm?: number;
        description?: string;
      }>;
    };
  };
  uvi: {
    status: string;
    data?: {
      uvi?: number;
    };
  };
}

export interface RecommendationEvidence {
  url?: string;
  approved?: boolean;
}

export interface AIRecommendation {
  id: string;
  field_id: string;
  category: string;
  priority: string;
  advice: string;
  rationale?: string;
  confidence?: number;
  confidence_reason?: string;
  evidence?: RecommendationEvidence[];
  safety_level: string;
  requires_expert_confirmation: boolean;
  expert_status: 'pending' | 'approved' | 'rejected';
  expert_notes?: string;
  status: string;
  ndvi_at_generation?: number;
  created_at: string;
  expires_at?: string;
  outcome?: string;
  outcome_notes?: string;
  analysis_run_id?: string;
  reviewed_by_id?: string;
  reviewed_by_email?: string;
  reviewed_at?: string;
}

/** The evidence behind one AI recommendation — fetched on demand when a reviewer expands
 * a card, since context_snapshot/evidence can be a large blob. */
export interface AnalysisRunDetail {
  id: string;
  field_id: string;
  provider: string;
  status: string;
  model_name?: string;
  prompt_version?: string;
  policy_version?: string;
  data_quality?: string;
  context_snapshot?: unknown;
  evidence?: unknown;
  error?: string;
  started_at: string;
  completed_at?: string;
}

export interface SeasonKeyEvent {
  date?: string;
  description?: string;
}

/** The AI advisor's compressed, whole-season narrative for a field's current crop cycle. */
export interface SeasonMemory {
  field_id: string;
  season_started_at: string;
  narrative?: string;
  key_events: SeasonKeyEvent[];
}

export interface AdvisorState {
  status: 'pending' | 'available' | 'stale' | 'unavailable';
  last_updated?: string;
  message?: string;
  retryable: boolean;
  data_quality?: string;
}

export interface DashboardPayload {
  sources: DashboardSources;
  recommendations: AIRecommendation[];
  advisor?: AdvisorState;
}

export interface ChatAttachment {
  id: string;
  mime_type: string;
  byte_size: number;
  width: number;
  height: number;
  url: string;
}

export interface ChatMessage {
  id: string;
  role: 'user' | 'model';
  content: string;
  status: string;
  created_at: string;
  attachments: ChatAttachment[];
}

export interface AISettings {
  mode: string;
  model: string;
}

/** Live probe result for the currently-active AI provider (admin settings portal). */
export interface AIHealth {
  ok: boolean;
  mode: string;
  model: string;
  provider: string;
  knowledge: string;
  latency_ms: number | null;
  detail: string;
}

export type AdvisoryPriority = 'low' | 'normal' | 'high' | 'urgent';

/** A direct staff-to-farmer message. Lands in the farmer's iOS notification inbox. */
export interface Advisory {
  id: string;
  title: string;
  body: string;
  priority: AdvisoryPriority;
  category: string;
  field_id?: string | null;
  field_name?: string | null;
  created_by_id?: string | null;
  created_by_email?: string | null;
  reference_id?: string | null;
  reference_type?: string | null;
  is_read: boolean;
  created_at: string;
}

export interface AdvisoryCreate {
  title: string;
  message: string;
  priority: AdvisoryPriority;
  recommendation_id?: string;
}

/** Reporting behaviour for one probe — "online" alone cannot tell a probe publishing
 *  every 30 seconds from one that sent a single packet 59 minutes ago and died. */
export interface SensorHealth {
  device_id: string;
  sensor_id: string;
  field_id: string | null;
  field_name: string | null;
  window_hours: number;
  reading_count: number;
  median_interval_seconds: number | null;
  longest_gap_seconds: number | null;
  first_reading_at: string | null;
  last_reading_at: string | null;
  battery_level: number | null;
  latest: {
    temperature?: number | null;
    moisture?: number | null;
    humidity?: number | null;
    ph?: number | null;
    ec?: number | null;
    npk_n?: number | null;
    npk_p?: number | null;
    npk_k?: number | null;
  } | null;
  /** Metric name -> how many readings in the window carried it. */
  reporting_metrics: Record<string, number>;
}
