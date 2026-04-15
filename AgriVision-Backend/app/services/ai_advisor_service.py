"""
AI Advisor Service — The "Brain" of AgriVision

This service aggregates multi-modal field data (satellite, sensors, weather)
and uses Google Gemini to generate structured agronomic recommendations.

The AI does NOT display raw numbers to the user.
Instead, it reasons across ALL data sources and produces actionable insights
such as:
  "Skip irrigation today. 12mm of rain is forecast in 48 hours."
  "NDVI declining for 3 consecutive days — inspect for pest stress."

Data Flow:
    Agromonitoring API (NDVI + Soil + Weather)
           ↓
    TimescaleDB (ESP32 Sensor trends)
           ↓
    Gemini Prompt Builder  ← crop context
           ↓
    Structured JSON Recommendations
           ↓
    PostgreSQL (field_recommendations table)
           ↓
    iOS SwiftUI Dashboard
"""

import os
import json
import logging
from typing import Optional

import google.generativeai as genai

logger = logging.getLogger(__name__)

GOOGLE_API_KEY = os.getenv("GOOGLE_API_KEY", "")

# Configure Gemini globally
if GOOGLE_API_KEY and GOOGLE_API_KEY != "YOUR_GOOGLE_API_KEY_HERE":
    genai.configure(api_key=GOOGLE_API_KEY)
    logger.info("AI Advisor: Gemini configured successfully.")
else:
    logger.warning("AI Advisor: GOOGLE_API_KEY not set. AI reasoning will be in mock mode.")


AGRONOMY_SYSTEM_PROMPT = """
You are an expert autonomous agronomist AI assistant integrated into AgriVision,
a precision agriculture platform for smallholder and commercial farmers.

Your role is to analyze real-time and historical field data — including
satellite-derived NDVI (plant health), soil moisture, temperature,
local ESP32 IoT sensor readings, and weather forecasts — and generate
clear, actionable, prioritized recommendations or chat responses.

Strict Rules for Recommendations:
1. When asked to generate recommendations, return ONLY valid JSON. No markdown. No preamble.
2. Always return exactly 3 recommendations in the `recommendations` array.
3. Each recommendation must follow this schema:
   {
     "category": "<one of: Irrigation, Plant Health, Weather Alert, Fertilizer Window, Harvest Timing, Pest Risk>",
     "priority": "<one of: low, medium, high>",
     "advice": "<1-2 sentences, specific and actionable. Use real data values.>",
     "confidence": <float 0.0 to 1.0>,
     "icon": "<one of: 💧, 🌿, ⛈️, 🌱, 🌾, 🐛>"
   }

Memory and Context Rules:
- You have memory of past recommendations and the farmer's feedback (e.g. if they implemented or ignored them).
- You know the crop type and plantation date. Use the date to calculate the current growth stage.
- Do NOT repeat past recommendations if they were recently implemented or dismissed, unless critical.
- Adapt your advice based on how the farmer responds to your previous suggestions.
"""


def _build_field_context(
    field_name: str,
    area_ha: float,
    ndvi: Optional[float],
    ndvi_trend: str,
    soil_data: Optional[dict],
    sensor_summary: Optional[dict],
    weather: Optional[dict],
    crop_type: Optional[str] = None,
    plantation_date: Optional[str] = None,
    recent_recommendations: Optional[list[dict]] = None,
    chat_history: Optional[list[dict]] = None
) -> str:
    """Assembles a structured text context block for the AI prompt."""
    
    lines = [
        f"FIELD: '{field_name}' | Area: {area_ha:.2f} ha",
        f"CROP: {crop_type or 'Unknown'} | PLANTED: {plantation_date or 'Unknown'}",
        "",
        "--- SATELLITE DATA ---",
        f"NDVI (Plant Health): {ndvi:.4f} (Scale: -1 to 1. Healthy crops: 0.2–0.9)" if ndvi else "NDVI: Not available",
        f"NDVI 7-Day Trend: {ndvi_trend}",
    ]

    if soil_data:
        lines += [
            "",
            "--- SATELLITE SOIL DATA ---",
            f"Soil Moisture: {soil_data.get('moisture', 'N/A')} m³/m³",
            f"Surface Temp: {soil_data.get('surface_temp_c', 'N/A')}°C",
            f"Depth Temp (10cm): {soil_data.get('depth_temp_c', 'N/A')}°C",
        ]

    if sensor_summary:
        lines += [
            "",
            "--- LOCAL IOT SENSOR DATA (ESP32 — Last 24 Hours) ---",
            f"Avg Temperature: {sensor_summary.get('avg_temp', 'N/A')}°C",
            f"Avg Soil Moisture: {sensor_summary.get('avg_moisture', 'N/A')}%",
            f"Avg Humidity: {sensor_summary.get('avg_humidity', 'N/A')}%",
            f"Sensor Count: {sensor_summary.get('sensor_count', 0)}",
        ]
    else:
        lines.append("")
        lines.append("--- IOT SENSORS: No local sensors registered for this field ---")

    if weather:
        current = weather.get("current", {})
        lines += [
            "",
            "--- WEATHER ---",
            f"Current: {current.get('temp_c', 'N/A')}°C, {current.get('description', '')} (Humidity: {current.get('humidity', 'N/A')}%)",
            "7-Day Forecast:"
        ]
        for day in weather.get("forecast_days", [])[:5]:
            lines.append(
                f"  - {day.get('date', '?')}: Max {day.get('temp_max_c', '?')}°C | Rain: {day.get('rain_mm', 0)}mm | {day.get('description', '')}"
            )

    if recent_recommendations:
        lines += ["", "--- PAST AI RECOMMENDATIONS (MEMORY & FEEDBACK) ---"]
        for r in recent_recommendations:
            lines.append(f"[{r.get('date', '?')}] {r.get('category', '')}: {r.get('advice', '')} (Feedback: {r.get('status', 'pending')})")

    if chat_history:
        lines += ["", "--- RECENT CHAT HISTORY (USER CONTEXT) ---"]
        for msg in chat_history:
            lines.append(f"{msg.get('role', 'unknown').upper()}: {msg.get('content', '')}")

    lines += [
        "",
        "--- TASK ---",
        "Based on ALL the above data, the crop type, age, and any feedback you have gathered:"
    ]

    return "\n".join(lines)


async def generate_field_recommendations(
    field_name: str,
    area_ha: float,
    ndvi: Optional[float],
    ndvi_trend: str,
    soil_data: Optional[dict],
    sensor_summary: Optional[dict],
    weather: Optional[dict],
    crop_type: Optional[str] = None,
    plantation_date: Optional[str] = None,
    recent_recommendations: Optional[list[dict]] = None,
    chat_history: Optional[list[dict]] = None
) -> list[dict]:
    """
    Core AI reasoning function. Assembles field context and calls Gemini
    to generate structured agronomic recommendations.
    """
    # Require AI configured
    if not GOOGLE_API_KEY or GOOGLE_API_KEY == "YOUR_GOOGLE_API_KEY_HERE":
        logger.error(f"AI Advisor: API Key not set. Cannot generate recommendations for '{field_name}'")
        return [{"category": "System", "priority": "high", "advice": "AI Advisor is unavailable. Please check your internet connection and API configuration.", "confidence": 1.0, "icon": "⚠️"}]

    context = _build_field_context(
        field_name=field_name,
        area_ha=area_ha,
        ndvi=ndvi,
        ndvi_trend=ndvi_trend,
        soil_data=soil_data,
        sensor_summary=sensor_summary,
        weather=weather,
        crop_type=crop_type,
        plantation_date=plantation_date,
        recent_recommendations=recent_recommendations,
        chat_history=chat_history
    )

    try:
        model = genai.GenerativeModel(
            model_name="gemini-1.5-flash",
            system_instruction=AGRONOMY_SYSTEM_PROMPT
        )

        response = model.generate_content(
            f"Analyze this field data and generate recommendations:\n\n{context}",
            generation_config=genai.types.GenerationConfig(
                temperature=0.3,  # Low temperature for consistent, factual outputs
                max_output_tokens=1024,
            )
        )

        raw_text = response.text.strip()
        # Gemini sometimes wraps JSON in markdown code blocks — strip them
        if raw_text.startswith("```"):
            raw_text = raw_text.split("```")[1]
            if raw_text.startswith("json"):
                raw_text = raw_text[4:]

        parsed = json.loads(raw_text)
        recommendations = parsed.get("recommendations", [])
        logger.info(f"AI Advisor: Generated {len(recommendations)} recommendations for '{field_name}'")
        return recommendations

    except json.JSONDecodeError as e:
        logger.error(f"AI Advisor: Failed to parse Gemini response as JSON: {e}")
        return []
    except Exception as e:
        logger.error(f"AI Advisor: Gemini API call failed: {e}")
        return []

async def chat_with_advisor(
    user_message: str,
    field_name: str,
    area_ha: float,
    ndvi: Optional[float],
    ndvi_trend: str,
    soil_data: Optional[dict],
    sensor_summary: Optional[dict],
    weather: Optional[dict],
    crop_type: Optional[str] = None,
    plantation_date: Optional[str] = None,
    recent_recommendations: Optional[list[dict]] = None,
    chat_history: Optional[list[dict]] = None
) -> str:
    """
    Allows the user to chat directly with the AI, bringing in full field context and memory.
    """
    if not GOOGLE_API_KEY or GOOGLE_API_KEY == "YOUR_GOOGLE_API_KEY_HERE":
        return "AI Advisor is unavailable due to missing API configuration."

    context = _build_field_context(
        field_name=field_name,
        area_ha=area_ha,
        ndvi=ndvi,
        ndvi_trend=ndvi_trend,
        soil_data=soil_data,
        sensor_summary=sensor_summary,
        weather=weather,
        crop_type=crop_type,
        plantation_date=plantation_date,
        recent_recommendations=recent_recommendations,
        chat_history=chat_history
    )

    try:
        model = genai.GenerativeModel(
            model_name="gemini-1.5-flash",
            system_instruction="You are AgriVision's autonomous expert agronomist AI assistant. Answer the user's chat message using all provided field context, crop details, plant dates, and memory of past predictions. Keep responses extremely helpful, professional, and directly tied to the sensor and weather data."
        )

        prompt = f"Field Context (Memory & Data):\n{context}\n\nUSER MESSAGE:\n{user_message}"

        response = model.generate_content(
            prompt,
            generation_config=genai.types.GenerationConfig(temperature=0.5)
        )
        return response.text.strip()
    except Exception as e:
        logger.error(f"AI Advisor Chat failed: {e}")
        return "I'm sorry, I'm having trouble analyzing your field data at the moment."

def _generate_rule_based_recommendations(
    ndvi: Optional[float],
    soil_data: Optional[dict],
    weather: Optional[dict]
) -> list[dict]:
    """
    Deterministic fallback recommendations based on threshold rules.
    Used when GOOGLE_API_KEY is not configured or Gemini is unavailable.
    """
    recs = []

    # NDVI-based plant health
    if ndvi is not None:
        if ndvi < 0.2:
            recs.append({
                "category": "Plant Health",
                "priority": "high",
                "advice": f"Critical: NDVI is {ndvi:.2f}, indicating severe crop stress or bare soil. Inspect the field immediately for disease, pest damage, or irrigation failure.",
                "confidence": 0.85,
                "icon": "🌿"
            })
        elif ndvi < 0.4:
            recs.append({
                "category": "Plant Health",
                "priority": "medium",
                "advice": f"NDVI is {ndvi:.2f}, suggesting moderate crop stress. Consider a nutrient top-dressing and check soil moisture levels.",
                "confidence": 0.78,
                "icon": "🌿"
            })
        else:
            recs.append({
                "category": "Plant Health",
                "priority": "low",
                "advice": f"Crop health looks good (NDVI: {ndvi:.2f}). Continue current management practices and monitor weekly.",
                "confidence": 0.82,
                "icon": "🌿"
            })
    
    # Soil moisture based irrigation
    moisture = soil_data.get("moisture") if soil_data else None
    if moisture is not None:
        if moisture < 0.2:
            recs.append({
                "category": "Irrigation",
                "priority": "high",
                "advice": f"Soil moisture is critically low at {moisture:.2f} m³/m³. Irrigate as soon as possible to prevent permanent wilting.",
                "confidence": 0.90,
                "icon": "💧"
            })
        elif moisture < 0.35:
            recs.append({
                "category": "Irrigation",
                "priority": "medium",
                "advice": f"Soil moisture is {moisture:.2f} m³/m³ — approaching the lower threshold. Schedule light irrigation within the next 24 hours.",
                "confidence": 0.80,
                "icon": "💧"
            })
        else:
            recs.append({
                "category": "Irrigation",
                "priority": "low",
                "advice": f"Soil moisture is adequate at {moisture:.2f} m³/m³. No irrigation needed for the next 48 hours.",
                "confidence": 0.85,
                "icon": "💧"
            })

    # Weather alert
    if weather:
        for day in weather.get("forecast_days", []):
            if day.get("rain_mm", 0) > 10:
                recs.append({
                    "category": "Weather Alert",
                    "priority": "medium",
                    "advice": f"Heavy rain of {day['rain_mm']}mm is forecast on {day.get('date', 'an upcoming day')}. Postpone any fertilizer or pesticide applications.",
                    "confidence": 0.75,
                    "icon": "⛈️"
                })
                break
    
    # Ensure we always have 3 recommendations
    while len(recs) < 3:
        recs.append({
            "category": "Fertilizer Window",
            "priority": "low",
            "advice": "Insufficient data to generate a fertilizer recommendation. Register IoT sensors to improve accuracy.",
            "confidence": 0.40,
            "icon": "🌱"
        })

    return recs[:3]
