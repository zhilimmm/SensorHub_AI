#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>
#include "DHT.h"
#include <WiFi.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>

// =====================================================
// 1. CREDENTIALS
// =====================================================
const char* ssid = "YOUR_2.4GHZ_WIFI_SSID";
const char* password = "YOUR_WIFI_PASSWORD";
const char* supabaseURL = "https://reszkykrwtcvnvpcmdzj.supabase.co";
const char* supabaseKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJlc3preWtyd3Rjdm52cGNtZHpqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ3ODQ0NjgsImV4cCI6MjA5MDM2MDQ2OH0.Gm4S2tqhU1A0oLC6-5qs9MFlj5WzUFP2eHt2pL90DI0";

// =====================================================
// 2. HARDWARE PINS & CALIBRATION
// =====================================================
#define DHTPIN 4
#define DHTTYPE DHT22

#define LIGHT_SENSOR_PIN 32
#define SOIL_MOISTURE_PIN 34
#define PH_SENSOR_PIN 35

#define FAN1_RELAY_PIN 25
#define FAN2_RELAY_PIN 26
#define FAN3_RELAY_PIN 27
#define PUMP_RELAY_PIN 18

#define BUZZER_PIN 2

#define SOIL_DRY 2357
#define SOIL_WET 1700

#define HIGH_TEMPERATURE 30.0
#define HIGH_HUMIDITY 70.0

#define SCREEN_WIDTH 128
#define SCREEN_HEIGHT 64
#define OLED_RESET -1
#define OLED_ADDR 0x3C

// =====================================================
// 3. TIMING & SAFETY
// =====================================================
const unsigned long SENSOR_INTERVAL = 5000;
const unsigned long SUPABASE_INTERVAL = 600000;
const unsigned long PUMP_RUN_TIME = 5000;
const unsigned long PUMP_COOLDOWN = 10000UL;

const float FUZZY_SCORE_THRESHOLD = 55.0f;
const float MAX_SAFE_SOIL_MOISTURE = 85.0f;

unsigned long previousSensorMillis = 0;
unsigned long previousSupabaseMillis = 0;
unsigned long pumpStartMillis = 0;
unsigned long lastPumpStartMillis = 0;

bool pumpOn = false;
bool sensorDataValid = false;

// =====================================================
// 4. OBJECTS & STATES
// =====================================================
Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, OLED_RESET);
DHT dht(DHTPIN, DHTTYPE);

float currentTemperature = 0.0;
float currentHumidity = 0.0;
int currentLight = 0;
int currentSoilMoisture = 0;
float currentPH = 0.0;
float irrigationScore = 0.0f;

bool currentFanOn = false;
int irrigationNeed = 0;
int ventilationNeed = 0;

// =====================================================
// 5. SETUP
// =====================================================
void setup() {
  Serial.begin(115200);

  // Initialize Sensors
  dht.begin();
  pinMode(LIGHT_SENSOR_PIN, INPUT);
  pinMode(SOIL_MOISTURE_PIN, INPUT);
  pinMode(PH_SENSOR_PIN, INPUT);
  pinMode(BUZZER_PIN, OUTPUT);
  digitalWrite(BUZZER_PIN, LOW);

  // Initialize Relays (Active LOW)
  pinMode(FAN1_RELAY_PIN, OUTPUT);
  pinMode(FAN2_RELAY_PIN, OUTPUT);
  pinMode(FAN3_RELAY_PIN, OUTPUT);
  pinMode(PUMP_RELAY_PIN, OUTPUT);

  digitalWrite(FAN1_RELAY_PIN, HIGH);
  digitalWrite(FAN2_RELAY_PIN, HIGH);
  digitalWrite(FAN3_RELAY_PIN, HIGH);
  digitalWrite(PUMP_RELAY_PIN, HIGH);

  // Initialize OLED
  if (!display.begin(SSD1306_SWITCHCAPVCC, OLED_ADDR)) {
    Serial.println("OLED initialization failed!");
    while (true) { delay(1000); }
  }
  display.clearDisplay();
  display.setTextColor(SSD1306_WHITE);
  display.setTextSize(1);
  display.setCursor(0, 0);
  display.println("Smart Plant System");
  display.setCursor(0, 15);
  display.println("Connecting to Wi-Fi...");
  display.display();

  // Initialize Wi-Fi
  WiFi.begin(ssid, password);
  unsigned long wifiStart = millis();
  while (WiFi.status() != WL_CONNECTED && millis() - wifiStart < 10000UL) {
    delay(250);
    Serial.print(".");
  }
  
  Serial.println("\nSystem Started");
}

// =====================================================
// 6. MAIN LOOP
// =====================================================
void loop() {
  unsigned long currentMillis = millis();

  // A. PUMP TIMER (Non-blocking)
  if (pumpOn && (millis() - lastPumpStartMillis >= PUMP_RUN_TIME)) {
  pumpOn = false;
  
  // ACTIVE LOW LOGIC: Send HIGH to turn the pump OFF
  digitalWrite(PUMP_RELAY_PIN, HIGH); 
  
  Serial.println("Pump turned OFF");

  resetManualPumpInDatabase();
}

  // B. 5-SECOND SENSOR & CONTROL LOOP
  if (currentMillis - previousSensorMillis >= SENSOR_INTERVAL) {
    previousSensorMillis = currentMillis;
    
    sensorDataValid = readSensors();
    if (sensorDataValid) {
      evaluateLocalFuzzyLogic();
      fetchManualControlsAndExecute();
      triggerAlerts();
      printSensorData();
      updateOLEDDisplay();
    }
  }

  // C. 10-MINUTE TELEMETRY LOOP
  if (currentMillis - previousSupabaseMillis >= SUPABASE_INTERVAL) {
    previousSupabaseMillis = currentMillis;
    uploadTelemetryData();
  }
  
  delay(50);
}

// =====================================================
// 7. CLOUD & MANUAL CONTROLS
// =====================================================
void fetchManualControlsAndExecute() {
  if (WiFi.status() != WL_CONNECTED) {
    executeLocalHardware(); // Fallback to local logic if offline
    return; 
  }

  HTTPClient http;
  String url = String(supabaseURL) + "/rest/v1/device_controls?id=eq.1&select=automation_active,pump_manual_override,fan_manual_override";
  http.begin(url);
  http.addHeader("apikey", supabaseKey);
  http.addHeader("Authorization", "Bearer " + String(supabaseKey));
  
  int httpCode = http.GET();
  if (httpCode == 200) {
    String payload = http.getString();
    DynamicJsonDocument doc(512);
    deserializeJson(doc, payload);
    
    bool autoMode = doc[0]["automation_active"];
    bool manualPump = doc[0]["pump_manual_override"];
    bool manualFan = doc[0]["fan_manual_override"];

    // Ensure database "automation_active" is FALSE to use manual switches
    if (autoMode == false) {
      // MODE 1: App Manual Control
      if (manualPump && !pumpOn && (millis() - lastPumpStartMillis >= PUMP_COOLDOWN)) {
        Serial.println("[APP OVERRIDE] Triggering Pump!");
        startPump();
      }
      
      controlFans(manualFan);
    } else {
      // MODE 2: Local Fuzzy AI Control
      executeLocalHardware();
    }
  } else {
    executeLocalHardware(); // Fallback if database fails
  }
  http.end();
}

void executeLocalHardware() {
  if (irrigationNeed == 1 && !pumpOn && (lastPumpStartMillis == 0 || millis() - lastPumpStartMillis >= PUMP_COOLDOWN)) {
    Serial.println("[LOCAL AUTO] Fuzzy Logic Triggered Pump!");
    startPump();
  }
  controlFans(currentFanOn); 
}

void startPump() {
  pumpOn = true;
  lastPumpStartMillis = millis();
  
  digitalWrite(PUMP_RELAY_PIN, LOW); 
  Serial.println("Pump turned ON");
}

void controlFans(bool turnOn) {
  if (turnOn) {
    digitalWrite(FAN1_RELAY_PIN, LOW);
    digitalWrite(FAN2_RELAY_PIN, LOW);
    digitalWrite(FAN3_RELAY_PIN, LOW);
    currentFanOn = true;
    ventilationNeed = 1;
  } else {
    digitalWrite(FAN1_RELAY_PIN, HIGH);
    digitalWrite(FAN2_RELAY_PIN, HIGH);
    digitalWrite(FAN3_RELAY_PIN, HIGH);
    currentFanOn = false;
    ventilationNeed = 0;
  }
}

// =====================================================
// 8. SENSORS & ALERTS
// =====================================================
bool readSensors() {
  float humidity = dht.readHumidity();
  float temperature = dht.readTemperature();

  if (isnan(temperature) || isnan(humidity) || humidity < 0 || temperature < 0) {
    return false;
  }
  currentTemperature = temperature;
  currentHumidity = humidity;
  currentLight = analogRead(LIGHT_SENSOR_PIN);

  int soilADC = analogRead(SOIL_MOISTURE_PIN);
  currentSoilMoisture = map(soilADC, SOIL_DRY, SOIL_WET, 0, 100);
  currentSoilMoisture = constrain(currentSoilMoisture, 0, 100);

  int phADC = analogRead(PH_SENSOR_PIN);
  float phVoltage = (phADC / 4095.0) * 3.3;
  float phValue = (-5.814 * phVoltage) + 15.032;
  currentPH = constrain(phValue, 0.0, 14.0);

  return true;
}

void triggerAlerts() {
  if (currentTemperature > HIGH_TEMPERATURE || currentHumidity > HIGH_HUMIDITY || 
      currentHumidity < 40.0 || currentSoilMoisture < 30) {
    digitalWrite(BUZZER_PIN, HIGH);
  } else {
    digitalWrite(BUZZER_PIN, LOW);
  }
}

// =====================================================
// 9. CUSTOM MAMDANI FUZZY LOGIC
// =====================================================
float triangle(float x, float a, float b, float c) {
  if (x <= a || x >= c) return 0.0f;
  if (x == b) return 1.0f;
  return max(0.0f, min((x-a)/(b-a), (c-x)/(c-b)));
}

float trapezoid(float x, float a, float b, float c, float d) {
  if (x < a || x > d) return 0.0f;
  if (x >= b && x <= c) return 1.0f;
  if (x < b) return (b == a) ? 1.0f : (x-a)/(b-a);
  return (d == c) ? 1.0f : (d-x)/(d-c);
}

void evaluateLocalFuzzyLogic() {
  float dry = trapezoid(currentSoilMoisture, 0, 0, 45, 65);
  float moderate = triangle(currentSoilMoisture, 50, 70, 85);
  float wet = trapezoid(currentSoilMoisture, 75, 90, 100, 100);
  float hot = trapezoid(currentTemperature, 28, 35, 50, 50);
  float optimal = triangle(currentTemperature, 22, 27, 32);
  float lowHum = trapezoid(currentHumidity, 0, 0, 45, 65);
  float midHum = triangle(currentHumidity, 55, 70, 85);

  float highStrength = max(dry, min(moderate, min(hot, lowHum)));
  float mediumStrength = max(moderate, max(min(moderate, hot), min(moderate, lowHum)));
  float lowStrength = max(wet, min(moderate, min(optimal, midHum)));

  float weightedArea = 0.0f;
  float totalArea = 0.0f;
  float previousMembership = 0.0f;
  for (int x = 0; x <= 100; x++) {
    float lowOutput = triangle(x, 0, 15, 40);
    float medOutput = triangle(x, 30, 50, 70);
    float highOutput = triangle(x, 60, 85, 100);
    float membership = max(min(lowStrength, lowOutput),
                           max(min(mediumStrength, medOutput),
                               min(highStrength, highOutput)));
    if (x > 0) {
      float area = (previousMembership + membership) * 0.5f;
      totalArea += area;
      weightedArea += area * (x - 0.5f);
    }
    previousMembership = membership;
  }
  
  irrigationScore = totalArea > 0.0f ? weightedArea / totalArea : 0.0f;
  
  if (currentSoilMoisture < MAX_SAFE_SOIL_MOISTURE && irrigationScore >= FUZZY_SCORE_THRESHOLD) {
    irrigationNeed = 1;
  } else {
    irrigationNeed = 0;
  }

  if (currentTemperature > HIGH_TEMPERATURE || currentHumidity > HIGH_HUMIDITY) {
    currentFanOn = true;
  } else {
    currentFanOn = false;
  }
}

// =====================================================
// 10. TELEMETRY & DISPLAY
// =====================================================
void uploadTelemetryData() {
  if (WiFi.status() != WL_CONNECTED) return;

  HTTPClient http;
  http.begin(String(supabaseURL) + "/rest/v1/sweet_potato_leave_data");
  http.addHeader("apikey", supabaseKey);
  http.addHeader("Authorization", "Bearer " + String(supabaseKey));
  http.addHeader("Content-Type", "application/json");
  http.addHeader("Prefer", "return=minimal");

  String jsonData = "{";
  jsonData += "\"temperature\":" + String(currentTemperature, 2) + ",";
  jsonData += "\"humidity\":" + String(currentHumidity, 2) + ",";
  jsonData += "\"light\":" + String(currentLight) + ",";
  jsonData += "\"soil_moisture\":" + String(currentSoilMoisture) + ",";
  jsonData += "\"ph_value\":" + String(currentPH, 2) + ",";
  jsonData += "\"ventilation_need\":" + String(ventilationNeed) + ",";
  jsonData += "\"irrigation_need\":" + String(irrigationNeed);
  jsonData += "}";

  int httpResponseCode = http.POST(jsonData);
  if (httpResponseCode >= 200 && httpResponseCode < 300) {
    Serial.println("Telemetry uploaded successfully.");
  } else {
    Serial.print("Upload failed. Code: ");
    Serial.println(httpResponseCode);
  }
  http.end();
}

void printSensorData() {
  Serial.println("==============================");
  Serial.printf("Temp: %.1fC  Hum: %.1f%%\n", currentTemperature, currentHumidity);
  Serial.printf("Light: %d  Soil: %d%%\n", currentLight, currentSoilMoisture);
  Serial.printf("pH: %.1f\n", currentPH);
  Serial.printf("Score: %.2f  Irrigation Need: %d\n", irrigationScore, irrigationNeed);
  Serial.printf("Fans: %s  Pump: %s\n", currentFanOn ? "ON" : "OFF", pumpOn ? "ON" : "OFF");
  Serial.println("==============================");
}

void updateOLEDDisplay() {
  display.clearDisplay();
  display.setTextSize(1);

  // Header
  display.setCursor(0, 0);
  display.println("Sweet Potato System");
  display.drawLine(0, 10, 127, 10, SSD1306_WHITE);

  // Row 1
  display.setCursor(0, 14);
  display.print("Temp:");
  display.print(currentTemperature, 1);
  display.print("C");

  display.setCursor(68, 14);
  display.print("Light:");
  display.print(currentLight);

  // Row 2
  display.setCursor(0, 27);
  display.print("Hum:");
  display.print(currentHumidity, 1);
  display.print("%");

  display.setCursor(68, 27);
  display.print("Soil:");
  display.print(currentSoilMoisture);
  display.print("%");

  // Row 3
  display.setCursor(0, 40);
  display.print("pH:");
  display.print(currentPH, 1);

  display.setCursor(68, 40);
  display.print("Fans:");
  display.print(currentFanOn ? "ON" : "OFF");

  // Row 4
  display.setCursor(0, 53);
  display.print("Pump:");
  display.print(pumpOn ? "ON" : "OFF");

  display.setCursor(68, 53);
  display.print("Irr:");
  display.print(irrigationNeed == 1 ? "YES" : "NO");

  display.display();
}

void resetManualPumpInDatabase() {
  if (WiFi.status() != WL_CONNECTED) return;

  HTTPClient http;
  // Targets the exact row in your device_controls table
  http.begin(String(supabaseURL) + "/rest/v1/device_controls?id=eq.1");
  http.addHeader("apikey", supabaseKey);
  http.addHeader("Authorization", "Bearer " + String(supabaseKey));
  http.addHeader("Content-Type", "application/json");
  http.addHeader("Prefer", "return=minimal");

  // Sends the command to flip the switch back to FALSE
  int httpResponseCode = http.PATCH("{\"pump_manual_override\":false}");
  
  if (httpResponseCode >= 200 && httpResponseCode < 300) {
    Serial.println("Cloud Sync: Pump switch reset to OFF in Supabase.");
  } else {
    Serial.print("Cloud Sync Failed. Code: ");
    Serial.println(httpResponseCode);
  }
  http.end();
}