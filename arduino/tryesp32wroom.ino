#include <SPI.h>
#include <LoRa.h>
#include <TinyGPS++.h>
#include <HardwareSerial.h>
#include <MPU6050_tockn.h>
#include <Wire.h>
#include <WiFi.h>
#include <esp_wifi.h>

MPU6050 mpu6050(Wire); // Accelerometer

#define RXD2 16
#define TXD2 17
#define GPS_BAUD 9600

#define SS 5
#define RST 14
#define DIO0 2

// Message type identifiers
#define MSG_TYPE_GPS "GPS"
#define MSG_TYPE_ACCEL "ACC"
#define MSG_TYPE_EVENT "EVT"

// Activity thresholds - adjusted for more sensitive detection
#define ACTIVITY_THRESHOLD_SLEEP 0.020   // Almost no movement - reduced from 0.15
#define ACTIVITY_THRESHOLD_WALK 0.2   // Walking pattern - reduced from 0.5
#define ACTIVITY_THRESHOLD_RUN 0.25    // Running pattern - reduced from 1.8

// Fall and impact detection
#define FALL_THRESHOLD 0.8            // Sudden acceleration change indicating potential fall
#define IMPACT_THRESHOLD 1.35          // High acceleration indicating impact
#define STATIONARY_AFTER_FALL 0.3       // Low movement after fall event
#define FALL_DETECTION_WINDOW 1000      // Window to check for post-fall stillness (ms)

// Emergency mode settings
bool emergencyEventInProgress = false;
unsigned long emergencyStartTime = 0;
const unsigned long EMERGENCY_TIMEOUT = 30000; // 30 seconds of priority mode

// Calibration values
float accelCalibrationOffset = 0.0;     // Will be determined during calibration
float noiseThreshold = 0.0;             // Will be determined during calibration

unsigned long lastGPSUpdateTime = 0;//for fixing stuck gps transmission
float lastLat = 0, lastLon = 0;
unsigned long lastValidGPS = millis();

TinyGPSPlus gps;
HardwareSerial gpsSerial(2);

// Activity detection variables
float accelBuffer[10][3];  // Buffer to store recent acceleration readings [x,y,z]
int bufferIndex = 0;
int sampleCount = 0;
unsigned long lastActivityTime = 0;
unsigned long lastGPSTime = 0;
unsigned long lastAccelRawTime = 0;
String currentActivity = "SLEEP";  // Default to SLEEP instead of UNKNOWN
bool fallDetected = false;
unsigned long fallTimestamp = 0;
bool calibrated = false;

bool accelAvailable = true;//for cases when it gets broken like my case 

#include <esp_sleep.h>
//RTC_DATA_ATTR String lastActivityBeforeSleep = "SLEEP"; //for deep sleep mode
#define SLEEP_TRIGGER_DURATION 60000     // 90 sec de inactivitate
#define DEEP_SLEEP_DURATION_SEC 30       // doarme 30 sec

bool gpsInStandby = false;
unsigned long lastGPSActivity = 0;
const unsigned long GPS_STANDBY_TIMEOUT = 120000; // 2 minutes of inactivity before GPS standby
const unsigned long GPS_WAKEUP_INTERVAL = 300000; // 5 minutes - wake GPS to check position
unsigned long lastGPSWakeup = 0;

void setGPSStandby() {
  if (!gpsInStandby && !emergencyEventInProgress) {
    Serial.println("Putting GPS in standby mode...");
    gpsSerial.println("$PMTK161,0*28"); // Standby mode
    delay(100);
    gpsSerial.println("$PMTK225,4*2F"); // Backup mode
    delay(100);
    gpsInStandby = true;
    Serial.println("GPS in standby mode");
  }
}

void wakeGPSFromStandby() {
  if (gpsInStandby || emergencyEventInProgress) {
    Serial.println("Waking GPS from standby...");
    gpsSerial.println("$PMTK225,0*2B"); // Exit backup mode
    delay(200);
    gpsSerial.println("$PMTK161,1*29"); // Exit standby mode
    delay(200);
    // Hot restart for faster acquisition
    gpsSerial.println("$PMTK101*32"); // Hot restart
    delay(100);
    gpsInStandby = false;
    lastGPSWakeup = millis();
    lastGPSActivity = millis();
    Serial.println("GPS wakened from standby");
  }
}

bool testPin(int pin) {
  pinMode(pin, OUTPUT);
  digitalWrite(pin, HIGH);
  delay(100);
  digitalWrite(pin, LOW);
  delay(100);
  return true; // If no hardware conflict, this should execute
}

void setup() {
  Serial.begin(9600);
  esp_sleep_wakeup_cause_t wakeupReason = esp_sleep_get_wakeup_cause();
  setCpuFrequencyMhz(80);
  WiFi.mode(WIFI_OFF);
  btStop();
  esp_wifi_deinit();
  Serial.println("WiFi and Bluetooth disabled");
  if (wakeupReason == ESP_SLEEP_WAKEUP_TIMER) {
    Serial.println("Woke up from deep sleep.");
    wakeGPSFromStandby();
  } else {
    Serial.println("Normal turn on");
  }
  Wire.begin(21, 22, 400000); 
  mpu6050.begin();
  Wire.beginTransmission(0x68); 
  if (Wire.endTransmission() != 0) {
    Serial.println("MPU6050 not detected! Accelerometer disabled.");
    accelAvailable = false;
  } else {
    Serial.println("MPU6050 detected!");
      mpu6050.calcGyroOffsets(true);
  }
  gpsSerial.begin(GPS_BAUD, SERIAL_8N1, RXD2, TXD2);
  delay(1000);
  lastGPSActivity = millis();//for battery life longer 
  lastGPSWakeup = millis();
  Serial.println("Initializing LoRa...");
  LoRa.setPins(SS, RST, DIO0);
  if (!LoRa.begin(868E6)) {
    Serial.println("LoRa init failed!");
    while (1);
  }

  Serial.println("LoRa Initialized!");
  Serial.println("MPU6050 initialized!");
  
  // Initialize acceleration buffer
  for (int i = 0; i < 10; i++) {
    accelBuffer[i][0] = 0;
    accelBuffer[i][1] = 0;
    accelBuffer[i][2] = 0;
  }
  
  // Perform initial calibration
  if (accelAvailable) {
  calibrateAccelerometer();
  }
}

void calibrateAccelerometer() {
  Serial.println("Calibrating accelerometer... Keep device still!");
  
  // Collect samples to determine the noise floor
  float sumMagnitude = 0;
  float maxMagnitude = 0;
  float minMagnitude = 100;
  int samples = 50;
  
  for (int i = 0; i < samples; i++) {
    mpu6050.update();
    float ax = mpu6050.getAccX();
    float ay = mpu6050.getAccY();
    float az = mpu6050.getAccZ();
    
    
    float magnitude = sqrt(ax*ax + ay*ay + az*az);
    
    sumMagnitude += magnitude;
    maxMagnitude = max(maxMagnitude, magnitude);
    minMagnitude = min(minMagnitude, magnitude);
    
    delay(20);
  }
  
 
  float avgMagnitude = sumMagnitude / samples;
  accelCalibrationOffset = avgMagnitude - 1.0;  
  noiseThreshold = (maxMagnitude - minMagnitude) * 1.5; 
  
  Serial.println("Calibration complete!");
  Serial.print("Calibration offset: ");
  Serial.println(accelCalibrationOffset);
  Serial.print("Noise threshold: ");
  Serial.println(noiseThreshold);
  
  calibrated = true;
}
bool isSummerTime(int year, int month, int day, int hour) {
  int lastSundayMarch = 31;
  while ((year * 10000 + 3 * 100 + lastSundayMarch) % 7 != 0) {
    lastSundayMarch--;
  }

  int lastSundayOctober = 31;
  while ((year * 10000 + 10 * 100 + lastSundayOctober) % 7 != 0) {
    lastSundayOctober--;
  }

  if (month < 3 || month > 10) return false;
  if (month > 3 && month < 10) return true;

  if (month == 3) return (day > lastSundayMarch) || (day == lastSundayMarch && hour >= 3);
  if (month == 10) return (day < lastSundayOctober) || (day == lastSundayOctober && hour < 4);

  return false;
}

String getFormattedTime() {
  int timezoneOffset = isSummerTime(gps.date.year(), gps.date.month(), gps.date.day(), gps.time.hour()) ? 3 : 2;
  int localHour = gps.time.hour() + timezoneOffset;
  if (localHour >= 24) localHour -= 24;
  if (localHour < 0) localHour += 24;

  char timeBuffer[9];
  sprintf(timeBuffer, "%02d:%02d:%02d", localHour, gps.time.minute(), gps.time.second());
  return String(timeBuffer);
}

void sendGPSData() {
 // int timezoneOffset = isSummerTime(gps.date.year(), gps.date.month(), gps.date.day(), gps.time.hour()) ? 3 : 2;
  String timeString = getFormattedTime();

  String gpsData = String(MSG_TYPE_GPS) + "," +
                   "LAT:" + String(gps.location.lat(), 6) +
                   ",LON:" + String(gps.location.lng(), 6) +
                   ",ALT:" + String(gps.altitude.meters()) +
                   ",SPD:" + String(gps.speed.kmph()) +
                   ",SAT:" + String(gps.satellites.value()) +
                   ",TIME:" + timeString;

  Serial.println("Sending GPS data: " + gpsData);

  if (emergencyEventInProgress) {
    LoRa.setTxPower(20); 
  } else {
    LoRa.setTxPower(17); 
  }

  LoRa.beginPacket();
  LoRa.print(gpsData);
  LoRa.endPacket();

  if (emergencyEventInProgress) {
    delay(250);
    LoRa.beginPacket();
    LoRa.print(gpsData);
    LoRa.endPacket();
  }
}

void sendActivityState(String state) {
  if (!accelAvailable) return;
  if (emergencyEventInProgress) {
  Serial.println("⚠️ Skipping normal activity send during EMERGENCY.");
  return;
}

// int timezoneOffset = isSummerTime(gps.date.year(), gps.date.month(), gps.date.day(), gps.time.hour()) ? 3 : 2;
  String timeString = getFormattedTime();

  String accelState = String(MSG_TYPE_ACCEL) + "," + state + 
                      ",TIME:" + timeString ;

  Serial.println("Sending accel state: " + accelState);

  LoRa.beginPacket();
  LoRa.print(accelState);
  LoRa.endPacket();
}

void sendAccelData() {
  if (!accelAvailable) return;
  //int timezoneOffset = isSummerTime(gps.date.year(), gps.date.month(), gps.date.day(), gps.time.hour()) ? 3 : 2;
 String timeString = getFormattedTime();

  // Calculate activity magnitude for debug purposes
  float ax = mpu6050.getAccX();
  float ay = mpu6050.getAccY();
  float az = mpu6050.getAccZ();
  float mag = sqrt(ax*ax + ay*ay + az*az);
  float actMag = abs(mag - 1.0 - accelCalibrationOffset);
  
  String accelData = String(MSG_TYPE_ACCEL) + "," +
                    "AX:" + String(ax, 3) +
                    ",AY:" + String(ay, 3) +
                    ",AZ:" + String(az, 3) +
                    ",GX:" + String(mpu6050.getGyroX(), 1) +
                    ",GY:" + String(mpu6050.getGyroY(), 1) +
                    ",GZ:" + String(mpu6050.getGyroZ(), 1) +
                    ",ANX:" + String(mpu6050.getAngleX(), 1) +
                    ",ANY:" + String(mpu6050.getAngleY(), 1) +
                    ",ANZ:" + String(mpu6050.getAngleZ(), 1) +
                    ",MAG:" + String(mag, 3) +
                    ",ACTMAG:" + String(actMag, 3) +
                    ",NOISE:" + String(noiseThreshold, 3) +
                    ",STATE:" + currentActivity +
                    ",TIME:" + timeString;
  
  Serial.println("Sending accel data: " + accelData);
  
  LoRa.beginPacket();
  LoRa.print(accelData);
  LoRa.endPacket();
}

void sendEventData(String eventType) {
 //int timezoneOffset = isSummerTime(gps.date.year(), gps.date.month(), gps.date.day(), gps.time.hour()) ? 3 : 2;
  String timeString = getFormattedTime();

  // Include location data with the event if available
  String locationData = "";
  if (gps.location.isValid()) {
    locationData = ",LAT:" + String(gps.location.lat(), 6) +
                   ",LON:" + String(gps.location.lng(), 6);
  }
  String eventData = String(MSG_TYPE_EVENT) + "," +
                     "TYPE:" + eventType +
                     locationData +
                     ",TIME:" + timeString ;
  
  Serial.println("Sending event data: " + eventData); 
  
  LoRa.setTxPower(20);

  LoRa.beginPacket();
  LoRa.print(eventData);
  LoRa.endPacket();

  delay(500); 
  LoRa.beginPacket();
  LoRa.print(eventData);
  LoRa.endPacket();
  
  delay(500);
  LoRa.beginPacket();
  LoRa.print(eventData);
  LoRa.endPacket();
  
  LoRa.setTxPower(17);
}

void checkForFallOrImpact(float magnitude, float ax, float ay, float az) {
  static bool firstSample = true;
  static float lastMagnitude = 0;
  float accelChange = abs(magnitude - lastMagnitude);

  if (firstSample) {
    lastMagnitude = magnitude;
    firstSample = false;
    return;  // Nu compara la prima rundă
  }
  static unsigned long lastHighImpact = 0;
  
  if (magnitude > IMPACT_THRESHOLD) {
    emergencyEventInProgress = true;
    emergencyStartTime = millis();
    Serial.println("EMERGENCY MODE: Impact detected!");
    if (gpsInStandby) {
      wakeGPSFromStandby();
    }

    sendEventData("IMPACT");
    currentActivity = "EMERGENCY";

    lastHighImpact = millis();

    if (gps.location.isValid()) {
      sendGPSData(); 
  }
  }
  if (!fallDetected && accelChange > FALL_THRESHOLD) {
    emergencyEventInProgress = true;
    emergencyStartTime = millis();
    Serial.println("EMERGENCY MODE: Potential fall detected!");
    if (gpsInStandby) {
      wakeGPSFromStandby();
    }
  
    fallTimestamp = millis();
    fallDetected = true;
    currentActivity = "EMERGENCY";
  }

  if (fallDetected && (millis() - fallTimestamp > 500)) {
    float avgMovement = 0;
    for (int i = 0; i < sampleCount; i++) {
      float mx = accelBuffer[i][0];
      float my = accelBuffer[i][1];
      float mz = accelBuffer[i][2];
      avgMovement += sqrt(mx*mx + my*my + mz*mz);
    }
    avgMovement /= sampleCount;
    if (avgMovement > STATIONARY_AFTER_FALL + 0.5) {
      fallDetected = false;
      emergencyEventInProgress = false;
      Serial.println("Fall detection canceled - movement detected");
    }
  }
  lastMagnitude = magnitude;
  Serial.print("→ Magnitude: ");
Serial.print(magnitude);
Serial.print(", Last: ");
Serial.print(lastMagnitude);
Serial.print(", Change: ");
Serial.println(accelChange);

}

void detectActivity(float activityMagnitude) {
  // Calculate average and variance of recent accelerations (activity magnitude)
  float avgMagnitude = 0;
  float varMagnitude = 0;
  float maxVariation = 0;
  
  // Calculate average activity magnitude (excluding gravity)
  for (int i = 0; i < sampleCount; i++) {
    float mx = accelBuffer[i][0];
    float my = accelBuffer[i][1];
    float mz = accelBuffer[i][2];
    float mag = sqrt(mx*mx + my*my + mz*mz);
    float actMag = abs(mag - 1.0 - accelCalibrationOffset); // Remove gravity component
    avgMagnitude += actMag;
  }
  avgMagnitude /= sampleCount;
  
  // Calculate variance and find max variation
  for (int i = 0; i < sampleCount; i++) {
    float mx = accelBuffer[i][0];
    float my = accelBuffer[i][1];
    float mz = accelBuffer[i][2];
    float mag = sqrt(mx*mx + my*my + mz*mz);
    float actMag = abs(mag - 1.0 - accelCalibrationOffset);
    varMagnitude += (actMag - avgMagnitude) * (actMag - avgMagnitude);
    maxVariation = max(maxVariation, abs(actMag - avgMagnitude));
  }
  varMagnitude /= sampleCount;
  
  // Detect rhythmic pattern for walking/running by analyzing consecutive samples
  bool hasRhythm = false;
  int rhythmCount = 0;
  
  // Look for alternating patterns in the buffer that would indicate steps
  for (int i = 1; i < sampleCount; i++) {
    float prevMag = sqrt(accelBuffer[i-1][0]*accelBuffer[i-1][0] + 
                        accelBuffer[i-1][1]*accelBuffer[i-1][1] + 
                        accelBuffer[i-1][2]*accelBuffer[i-1][2]);
    float currMag = sqrt(accelBuffer[i][0]*accelBuffer[i][0] + 
                        accelBuffer[i][1]*accelBuffer[i][1] + 
                        accelBuffer[i][2]*accelBuffer[i][2]);
    
    if (abs(currMag - prevMag) > noiseThreshold * 1.5) { // Reduced threshold multiplier
      rhythmCount++;
    }
  }
  
  // More sensitive rhythm detection
  hasRhythm = (rhythmCount >= sampleCount / 4); // Changed from /3 to /4
  
  // Ignore very small movements that are likely just sensor noise
  if (avgMagnitude < noiseThreshold && maxVariation < noiseThreshold * 1.5) { // Reduced threshold
    avgMagnitude = 0;
    varMagnitude = 0;
  }

  String newActivity;  
  if (avgMagnitude < ACTIVITY_THRESHOLD_SLEEP) {
    newActivity = "SLEEP";
  } else if (avgMagnitude < ACTIVITY_THRESHOLD_WALK) {
    if (hasRhythm && varMagnitude > 0.005) {
      newActivity = "WALK";
    } else {
      newActivity = "SLEEP";
    }
  } else if (avgMagnitude < ACTIVITY_THRESHOLD_RUN) {
    if (varMagnitude > 0.005) { 
      newActivity = "RUN";
    } else {
      newActivity = "SLEEP"; 
    }
  } else {
    if (hasRhythm && varMagnitude > 0.02) { 
      newActivity = "RUN";
    } else {
      newActivity = "WALK"; 
    }
  }

  static String lastActivity = "SLEEP";
  static int activityCounter = 0;
  
  if (newActivity == lastActivity) {
    activityCounter++;
    if (activityCounter >= 2) { // Changed from 5 to 3
      currentActivity = newActivity;
      activityCounter = 2; // Cap the counter
    }
  } else {
    lastActivity = newActivity;
    activityCounter = 1;
  }
  
  // Enhanced debug info
  Serial.print("Activity: ");
  Serial.print(newActivity);
  Serial.print(" (current: ");
  Serial.print(currentActivity);
  Serial.print("), Mag: ");
  Serial.print(avgMagnitude, 4);
  Serial.print(", Var: ");
  Serial.print(varMagnitude, 4);
  Serial.print(", Rhythm: ");
  Serial.print(rhythmCount);
  Serial.print("/");
  Serial.print(sampleCount/4);
  Serial.print(" (hasRhythm=");
  Serial.print(hasRhythm ? "true" : "false");
  Serial.print("), Counter: ");
  Serial.println(activityCounter);
}

void loop() {
  unsigned long currentMillis = millis();

  if (gpsInStandby && (currentMillis - lastGPSWakeup > GPS_WAKEUP_INTERVAL)) {
    wakeGPSFromStandby();
  }

  if (!gpsInStandby && !emergencyEventInProgress && 
        currentActivity == "SLEEP" && 
        (currentMillis - lastGPSActivity > GPS_STANDBY_TIMEOUT)) {
      setGPSStandby();
    }
  if (emergencyEventInProgress && gpsInStandby) {
      wakeGPSFromStandby();
    }

  while (gpsSerial.available() > 100) {
  gpsSerial.read(); // Clear backlog if buffer is too full
}

    if(!gpsInStandby){
      while (gpsSerial.available()) {
      char c = gpsSerial.read();
      gps.encode(c);
      Serial.write(c);//nmea pt date brute pt testare si depanare
     }
    }
 Serial.print("Numar sateliti: "); Serial.println(gps.satellites.value());
 Serial.print("Precizie HDOP: "); Serial.println(gps.hdop.hdop());
Serial.print("GPS fix: ");
Serial.print(gps.location.isValid() ? "VALID" : "INVALID");
if (gps.location.isValid()&& gps.satellites.value() > 3) {
  Serial.print(", Lat: ");
  Serial.print(gps.location.lat(), 6);
  Serial.print(", Lon: ");
  Serial.println(gps.location.lng(), 6);
  lastValidGPS = millis();
  lastGPSActivity = millis();
}

// Send GPS data if:
// - Location is valid AND
// - (Emergency is active OR it's been more than X seconds since last send)
//unsigned long currentMillis = millis();
unsigned long gpsInterval = emergencyEventInProgress ? 500 : 1000;  // Send every 0,5s in emergency, 1s normally

if (gps.location.isValid()|| gps.charsProcessed() > 0) {
    if (currentMillis - lastGPSTime > gpsInterval) {
      sendGPSData();
      lastLat = gps.location.lat();
      lastLon = gps.location.lng();
      lastGPSTime = currentMillis;
      lastGPSUpdateTime = currentMillis;
      lastGPSActivity = currentMillis;
      Serial.println("GPS sent due to interval trigger.");
    }
  } else if (millis() - lastValidGPS > 30000) {
    Serial.println(" WARNING: No valid GPS data for 30 seconds!");
  }else {
    Serial.println("GPS in standby mode - skipping GPS processing");
  }
  
  if(accelAvailable){
      mpu6050.update();
      float ax = mpu6050.getAccX();
      float ay = mpu6050.getAccY();
      float az = mpu6050.getAccZ();
      
      // Calculate raw magnitude (with gravity)
      float rawMagnitude = sqrt(ax*ax + ay*ay + az*az);
      
      // Apply calibration offset to compensate for sensor bias
      float calibratedMagnitude = rawMagnitude - accelCalibrationOffset;
      
      // Subtract gravity component (approximately 1.0)
      // This helps isolate user movement from constant gravity
      float activityMagnitude = abs(calibratedMagnitude - 1.0);
      
      // Enhanced debug output
      Serial.print("Raw: ");
      Serial.print(rawMagnitude, 4);
      Serial.print(", Calibrated: ");
      Serial.print(calibratedMagnitude, 4);
      Serial.print(", Activity: ");
      Serial.print(activityMagnitude, 4);
      Serial.print(", Threshold: ");
      Serial.println(ACTIVITY_THRESHOLD_WALK, 4);
      
      // Add to buffer
      accelBuffer[bufferIndex][0] = ax;
      accelBuffer[bufferIndex][1] = ay;
      accelBuffer[bufferIndex][2] = az;
      bufferIndex = (bufferIndex + 1) % 10;
      if (sampleCount < 10) sampleCount++;
      
      // Check for fall or impact
      checkForFallOrImpact(rawMagnitude, ax, ay, az);
      
      if (!fallDetected && calibrated && sampleCount >= 5) {
        detectActivity(activityMagnitude);
      }
      if (emergencyEventInProgress && (millis() - emergencyStartTime > EMERGENCY_TIMEOUT)) {
        emergencyEventInProgress = false;
        fallDetected = false;
        currentActivity = "SLEEP";
        Serial.println("Emergency mode ended");
      }
      static String lastStateSent = "";
      if (millis() - lastActivityTime > 1000) {
        if (fallDetected) {
          sendEventData("FALL");
          if (millis() - fallTimestamp > FALL_DETECTION_WINDOW) {
            fallDetected = false;
          }
        } else {
          if (currentActivity != lastStateSent) {
              sendActivityState(currentActivity);
              lastActivityTime = millis();  
              lastStateSent = currentActivity;
            }
          }
          //sendActivityState(currentActivity);
          unsigned long accelSendInterval = 5000;
          if (currentActivity == "SLEEP") {
            accelSendInterval = 15000;
          } else if (currentActivity == "RUN" || emergencyEventInProgress) {
            accelSendInterval = 2000;
          }

          if (millis() - lastAccelRawTime > accelSendInterval && !emergencyEventInProgress) {
            sendAccelData();
            lastAccelRawTime = millis();
          }
        }

        //lastActivityTime = millis();
      }
       if (accelAvailable && currentActivity == "SLEEP" && !emergencyEventInProgress) {
        if (millis() - lastActivityTime > SLEEP_TRIGGER_DURATION) {
          Serial.println("Inactivity. Deep sleep 30 seconds...");
          
          setGPSStandby();
          //mpu6050.setSleepEnabled(true);  
          delay(100);

          esp_sleep_enable_timer_wakeup(DEEP_SLEEP_DURATION_SEC * 1000000ULL);

          Serial.flush();
          pinMode(2, OUTPUT);
          digitalWrite(2, LOW);
          esp_deep_sleep_start();
          Serial.println(">>> SHOULD NOT SEE THIS IF DEEP SLEEP IS ACTIVE <<<");

        }
      }

    delay(emergencyEventInProgress ? 50 : 200);
  
}
