export interface Coordinate {
  lat?: number;
  lng?: number;
  latitude?: number;
  longitude?: number;
}

export interface Field {
  id: string;
  owner_id?: string;
  name: string;
  crop_type: string;
  area_ha: number;
  plantation_date: string;
  expected_harvest_date: string | null;
  coordinates: Coordinate[];
  status: string;
  ndvi_score?: number;
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
  temperature_avg?: number;
  moisture_avg?: number;
  humidity_avg?: number;
  ph_avg?: number;
  ec_avg?: number;
  npk_n_avg?: number;
  npk_p_avg?: number;
  npk_k_avg?: number;
  reading_count: number;
}

export interface SensorDevice {
  id: string;
  field_id?: string;
  device_id: string;
  name?: string;
  sensor_type: string;
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
    data?: {
      ndvi_image_url?: string;
      truecolor_image_url?: string;
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
