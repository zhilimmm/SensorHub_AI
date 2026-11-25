# SensorHub AI — AI-Driven Smart Greenhouse Indoor Plant Care System

**SensorHub AI** is an end-to-end IoT and machine learning smart greenhouse platform designed to monitor indoor microclimates in real time, evaluate plant health using Random Forest models, and automate irrigation and ventilation hardware.

---

## System Architecture & Tech Stack

* **Mobile Application (`lib/`, `android/`):** Built with **Flutter (Dart)** for Android, featuring real-time telemetry dashboards, multi-sensor historical overlay charts, PDF telemetry report generation, and hardware actuator controls.
* **AI & Inference Backend (`backend/`):** Built with **Python (FastAPI)** and **Scikit-Learn**, serving trained **Random Forest** models (`random_forest_irrigation.pkl` and `random_forest_ventilation.pkl`) for plant health scoring, irrigation/ventilation predictions, and historical trend analysis.
* **IoT Edge Firmware (`esp32_firmware/`):** Written in **Arduino C++ (`SensorHub_ESP32.ino`)** for the **ESP32** microcontroller, reading ambient temperature, relative humidity, light intensity, soil moisture, and soil pH while driving a 5V relay water pump and three 5V exhaust fans.
* **Cloud Database & Auth (`database/`):** Powered by **Supabase (PostgreSQL, Auth, and Storage)** (`supabase_schema.sql`) with per-user data isolation (`user_id`) and real-time synchronization.

---

## Repository Structure

```text
SensorHub_AI/
├── android/                  # Android platform configuration & manifest permissions
├── assets/                   # Application icons and visual assets
├── lib/                      # Flutter mobile application source code
│   ├── main.dart             # App entry point, Supabase init & authentication flow
│   ├── home_tab.dart         # Real-time environmental sensor dashboard
│   ├── data_tab.dart         # Historical sensor overlays, AI insights & PDF email export
│   ├── ai_tab.dart           # Random Forest plant health score & care recommendations
│   ├── controls_tab.dart     # AI automation, manual actuator overrides & emergency kill switch
│   └── settings_tab.dart     # User profile, avatar upload & crop configuration
├── backend/                  # FastAPI machine learning inference server
│   ├── main.py               # REST API endpoints (/api/predict, /api/analyze-trend, /api/email-report)
│   ├── random_forest_irrigation.pkl
│   ├── random_forest_ventilation.pkl
│   └── requirements.txt      # Python dependencies
├── esp32_firmware/           # Microcontroller firmware
│   └── SensorHub_ESP32.ino   # ESP32 sensor acquisition & actuator control sketch
├── database/                 # Cloud database schema
│   └── supabase_schema.sql   # PostgreSQL tables and storage bucket setup
└── pubspec.yaml              # Flutter package dependencies