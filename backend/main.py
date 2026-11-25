import os
import joblib
import numpy as np
from datetime import date
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from supabase import create_client, Client
from typing import List, Dict
import base64
import smtplib
from email.message import EmailMessage
from google import genai
from google.genai import types
from dotenv import load_dotenv

load_dotenv()

app = FastAPI(title="SensorHub AI Predictive Engine")

@app.get("/")
def health_check():
    return {"status": "online", "service": "SensorHub AI Predictive Engine"}

import warnings
warnings.filterwarnings("ignore", message="X does not have valid feature names")

# ==========================================
# 1. SUPABASE SETUP
# ==========================================
SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_KEY = os.getenv("SUPABASE_KEY")
supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)

# ==========================================
# 2. LOAD MODELS
# ==========================================
try:
    irrigation_model = joblib.load("random_forest_irrigation.pkl")
    ventilation_model = joblib.load("random_forest_ventilation.pkl")
    print("Models loaded successfully with Joblib!")
except FileNotFoundError as e:
    print(f"Error: Missing model file - {e}")
    irrigation_model, ventilation_model = None, None

class SensorTelemetry(BaseModel):
    temperature: float
    humidity: float
    soil_moisture: int
    ph_value: float

def calculate_health_index(temp, hum, soil, ph):
    score = 100.0
    # Temperature Penalties (Ideal: 24-28C)
    if temp < 24.0: score -= (24.0 - temp) * 4  
    elif temp > 28.0: score -= (temp - 28.0) * 4 
    # Humidity Penalties (Ideal: 70-80%)
    if hum < 70.0: score -= (70.0 - hum) * 0.5   
    elif hum > 80.0: score -= (hum - 80.0) * 0.5 
    # Soil Moisture Penalties (Ideal: 60-80%)
    if soil < 60: score -= (60 - soil) * 0.5     
    elif soil > 80: score -= (soil - 80) * 0.5   
    # pH Penalties (Ideal: 5.5-6.5)
    if ph < 5.5: score -= (5.5 - ph) * 15        
    elif ph > 6.5: score -= (ph - 6.5) * 15
    
    return max(0, min(100, int(score)))

def generate_growth_forecast(planting_date_str: str, health_index: int) -> str:
    try:
        planted = date.fromisoformat(str(planting_date_str))
        days_grown = max(1, (date.today() - planted).days + 1)
    except Exception:
        days_grown = 1

    target_harvest_day = 40
    days_left = max(0, target_harvest_day - days_grown)

    if days_grown <= 14:
        stage = "Rooting & Establishment"
        harvest_info = f"Est. first leaf harvest in {days_left} days"
        stage_note = "Roots are anchoring into the soil."
    elif days_grown <= 30:
        stage = "Vine & Canopy Expansion"
        harvest_info = f"Est. first leaf harvest in {days_left} days"
        stage_note = "Vines are spreading actively."
    elif days_grown < target_harvest_day:
        stage = "Pre-Harvest Maturation"
        harvest_info = f"First harvest in {days_left} days"
        stage_note = "Leaves are filling out and nearly ready."
    else:
        stage = "Active Harvest Stage"
        harvest_info = "Ready to harvest now"
        stage_note = "Snip tender top shoots every 7–14 days for continuous regrowth."

    if health_index < 60:
        health_note = "Current stress may slow leaf growth—check AI Suggestions."
    elif health_index < 80:
        health_note = "Minor environmental tweaks will keep growth on track."
    else:
        health_note = "Optimal conditions are supporting strong leaf growth."

    # Separated by '|' so Flutter can display each part neatly
    day_badge = f"Day {days_grown}/{target_harvest_day}" if days_grown <= target_harvest_day else f"Day {days_grown} • Ready"
    return f"{day_badge}|{stage}|{harvest_info}|{stage_note} {health_note}"

# ==========================================
# 3. PREDICTION & DATABASE UPDATE
# ==========================================
@app.post("/api/predict")
def get_ai_prediction(data: SensorTelemetry):
    if irrigation_model is None or ventilation_model is None:
        raise HTTPException(status_code=500, detail="Models not loaded.")

    try:
        # 1. Run the AI predictions
        features = np.array([[data.temperature, data.humidity, data.soil_moisture]])
        irr_pred = int(irrigation_model.predict(features)[0])
        vent_pred = int(ventilation_model.predict(features)[0])

        # 2. Fetch the current toggle states from Supabase
        controls_data = supabase.table("device_controls").select("*").eq("id", 1).execute()
        controls = controls_data.data[0]
        
        auto_irr_enabled = controls.get("auto_irrigation_active", False)
        auto_vent_enabled = controls.get("auto_ventilation_active", False)

        # 3. Determine final hardware states based on user permission
        final_pump_state = True if irr_pred == 1 else False
        if not auto_irr_enabled:
            final_pump_state = controls.get("pump_manual_override", False) 

        final_fan_state = True if vent_pred == 1 else False
        if not auto_vent_enabled:
            final_fan_state = controls.get("fan_manual_override", False) 

        # 4. Push the hardware commands to device_controls
        supabase.table("device_controls").update({
            "pump_manual_override": final_pump_state, 
            "fan_manual_override": final_fan_state    
        }).eq("id", 1).execute()

        # 5. GENERATE SIMPLE UI STRINGS FOR FLUTTER APP
        # Irrigation Logic based on thresholds and AI prediction
        if data.soil_moisture > 85:
            irr_status, irr_title, irr_desc = "Warning", "Soil is Too Wet", "The soil has too much water. Please stop watering so the roots do not get sick."
        elif data.soil_moisture < 35 or irr_pred == 1:
            irr_status, irr_title, irr_desc = "Action Needed", "Soil is Too Dry", "The plants are thirsty. Please turn on the water pump."
        else:
            irr_status, irr_title, irr_desc = "All Good", "Perfect Moisture", "The soil has just the right amount of water for the sweet potatoes."

        # Ventilation Logic based on thresholds and AI prediction
        if data.temperature > 32:
            vent_status, vent_title, vent_desc = "Warning", "Too Hot", "It is too hot for the plants. Keep the fans on to cool down the area."
        elif data.temperature < 20:
            vent_status, vent_title, vent_desc = "Action Needed", "Too Cold", "It is getting chilly. Turn off the fans to keep the plants warm."
        elif data.humidity > 80:
            vent_status, vent_title, vent_desc = "Warning", "Air is Too Damp", "The air is very wet and can make the leaves sick. Keep the fans on to clear the air."
        elif data.humidity < 40:
            vent_status, vent_title, vent_desc = "Action Needed", "Air is Too Dry", "The air is very dry. Turn off the fans so the plants stay moist."
        else:
            vent_status, vent_title, vent_desc = "All Good", "Great Weather", "The temperature and humidity are perfect right now."

        # Generate Legacy Actions for old fields
        irr_action = "Irrigation Burst Required" if irr_pred == 1 else "Soil Moisture Optimal"
        irr_desc_legacy = "Root zone deficit detected." if irr_pred == 1 else "Water levels are stable."
        
        vent_action = "Active Exhaust Required" if vent_pred == 1 else "Climate Stable"
        vent_desc_legacy = "High heat or humidity detected." if vent_pred == 1 else "Atmospheric conditions ideal."

        if irr_pred == 1 and vent_pred == 1:
            health = "Critical Warning"
            issue = f"{irr_desc_legacy} AND {vent_desc_legacy}"
            action = "Tap Manual Pump and Manual Fan."
        elif irr_pred == 1:
            health = "Warning"
            issue = irr_desc_legacy
            action = f"{irr_action}. Tap Manual Pump."
        elif vent_pred == 1:
            health = "Warning"
            issue = vent_desc_legacy
            action = f"{vent_action}. Ensure fans are running."
        else:
            health = "Optimal"
            issue = "None detected."
            action = "No action required. Plant is thriving."

        # Calculate health index
        calculated_index = calculate_health_index(
            data.temperature, 
            data.humidity, 
            data.soil_moisture,
            data.ph_value
        )

        # Fetch planting_date from ai_insights and generate dynamic growth forecast
        ai_row = supabase.table("ai_insights").select("planting_date").eq("id", 1).execute()
        planting_date_str = ai_row.data[0].get("planting_date") if ai_row.data else str(date.today())
        forecast = generate_growth_forecast(planting_date_str, calculated_index)

        # 6. PUSH EVERYTHING TO SUPABASE (Including new UI strings & timeline forecast)
        update_data = {
            "crop_health_status": health,
            "predicted_issue": issue,
            "recommended_action": action,
            "growth_forecast": forecast,
            "health_index": calculated_index,
            # New Flutter UI Columns
            "irrigation_status": irr_status,
            "irrigation_title": irr_title,
            "irrigation_desc": irr_desc,
            "ventilation_status": vent_status,
            "ventilation_title": vent_title,
            "ventilation_desc": vent_desc
        }
        supabase.table("ai_insights").update(update_data).eq("id", 1).execute()

        return {
            "irrigation_code": irr_pred,
            "ventilation_code": vent_pred,
            "health_index": calculated_index,
            "growth_forecast": forecast,
            "database_sync": "Success"
        }

    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")
gemini_client = genai.Client(api_key=GEMINI_API_KEY)

class TrendRequest(BaseModel):
    selected_sensors: list[str]
    data_points: list[dict[str, float]]

# Simple in-memory cache so repeated demo clicks don't burn API quota
_insight_cache: dict[str, str] = {}

@app.post("/api/analyze-trend")
def analyze_trend(req: TrendRequest):
    if not req.data_points or not req.selected_sensors:
        return {"insight": "Select parameters with logged data to generate AI analysis."}

    # 1. Statistical Feature Extraction (Python computes exact numbers)
    stats_summary = []
    fallback_insight = "Conditions remain within acceptable ranges for sweet potato leaf growth."
    highest_severity = 0

    for sensor in req.selected_sensors:
        vals = [pt[sensor] for pt in req.data_points if sensor in pt]
        if not vals:
            continue

        avg_val = round(sum(vals) / len(vals), 1)
        min_val = round(min(vals), 1)
        max_val = round(max(vals), 1)
        stats_summary.append(f"{sensor}: avg={avg_val}, min={min_val}, max={max_val}")

        # Rule-based severity check (acts as both context and offline fallback)
        if sensor == "humidity" and avg_val > 88 and highest_severity < 3:
            highest_severity = 3
            fallback_insight = f"Key trend detected: Humidity averaged {avg_val}% (peaking at {max_val}%). Extended dampness raises fungal risk—increase airflow."
        elif sensor == "soil_moisture" and avg_val < 55 and highest_severity < 3:
            highest_severity = 3
            fallback_insight = f"Key trend detected: Soil moisture averaged {avg_val}% (dropping to {min_val}%). Root zone is drying—schedule irrigation."
        elif sensor == "temperature" and avg_val > 30 and highest_severity < 2:
            highest_severity = 2
            fallback_insight = f"Key trend detected: Temperature averaged {avg_val}°C (peaking at {max_val}°C). Heat stress slows leaf expansion—increase ventilation."

    stats_text = "; ".join(stats_summary)

    # Check cache first to avoid duplicate API requests
    cache_key = f"{','.join(sorted(req.selected_sensors))}|{stats_text}"
    if cache_key in _insight_cache:
        return {"insight": _insight_cache[cache_key]}

    # 2. Generative AI Synthesis via Gemini API (with model fallback + offline fallback)
    models_to_try = ["gemini-3.5-flash-lite", "gemini-3.5-flash"]

    for model_name in models_to_try:
        try:
            response = gemini_client.models.generate_content(
                model=model_name,
                contents=f"Selected sensors: {', '.join(req.selected_sensors)}. Telemetry summary: {stats_text}",
                config=types.GenerateContentConfig(
                    system_instruction=(
                        "You are an agronomist AI for a sweet potato leaf smart greenhouse. "
                        "Optimal ranges: Temp 24-30°C, Humidity 70-85%, Soil Moisture 60-80%, pH 5.8-6.8, Light 1500-3500 Lux. "
                        "Rules:\n"
                        "1. Address EVERY sensor listed in 'Selected sensors' so the user knows all selected metrics were analyzed.\n"
                        "2. Prioritize out-of-range anomalies first with exact numbers, then briefly note if the other selected sensor(s) remained optimal and how they interact.\n"
                        "3. End with one concrete greenhouse action.\n"
                        "4. Keep the response concise (2-3 sentences, under 55 words, plain text, no bullet points).\n\n"
                        "Example Input: Selected sensors: soil_moisture, temperature. Telemetry summary: soil_moisture: avg=80.9, min=35.0, max=95.0; temperature: avg=26.4, min=24.8, max=28.1\n"
                        "Example Output: Soil moisture averaged 80.9% (peaking at 95.0%), exceeding the 80% ceiling, while temperature remained stable at 26.4°C. Because moderate warmth slows soil evaporation, halt irrigation immediately to prevent root rot."
                    ),
                    temperature=0.2,
                    max_output_tokens=110,
                ),
            )
            if response and response.text:
                result_text = response.text.strip()
                _insight_cache[cache_key] = result_text
                return {"insight": result_text}

        except Exception as e:
            print(f"Model {model_name} failed ({e}), trying next...")

    # 3. Seamless offline fallback if all models hit quota or Wi-Fi drops
    return {"insight": fallback_insight}

class EmailReportRequest(BaseModel):
    recipient_email: str
    filename: str
    pdf_base64: str

@app.post("/api/email-report")
def email_pdf_report(req: EmailReportRequest):
    SENDER_EMAIL = os.getenv("SENDER_EMAIL")
    SENDER_APP_PASSWORD = os.getenv("SENDER_APP_PASSWORD")

    try:
        msg = EmailMessage()
        msg["Subject"] = f"SensorHub AI - Telemetry Report ({req.filename})"
        msg["From"] = SENDER_EMAIL
        msg["To"] = req.recipient_email
        msg.set_content(
            "Hello,\n\n"
            "Attached is your requested SensorHub AI telemetry report, including your selected "
            "sensor overlay chart, AI trend insight, and filtered metric logs.\n\n"
            "Best regards,\nSensorHub AI"
        )

        # Decode base64 PDF and attach it
        pdf_bytes = base64.b64decode(req.pdf_base64)
        msg.add_attachment(
            pdf_bytes,
            maintype="application",
            subtype="pdf",
            filename=req.filename
        )

        # Send via Gmail SMTP
        with smtplib.SMTP_SSL("smtp.gmail.com", 465) as smtp:
            smtp.login(SENDER_EMAIL, SENDER_APP_PASSWORD)
            smtp.send_message(msg)

        return {"status": "sent", "recipient": req.recipient_email}

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to send email: {str(e)}")