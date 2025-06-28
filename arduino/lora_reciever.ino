#include <ESPAsyncWebServer.h>
#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <SPI.h>
#include <LoRa.h>
#include <PubSubClient.h>
#include <AsyncTCP.h>

#define SS 5
#define RST 14
#define DIO0 2

#define MSG_TYPE_GPS "GPS"
#define MSG_TYPE_ACCEL "ACC"
#define MSG_TYPE_EVENT "EVT"

const char* WIFI_SSID = "wifinname";
const char* WIFI_PASSWORD = "wifipassword";

const char* AP_SSID = "ESP32_Pet_Tracker";
const char* AP_PASSWORD = "9876543210";

const char* MQTT_BROKER_CLOUD = "4e8b407740ce42b18fba5f234af6b314.s1.eu.hivemq.cloud";
const int MQTT_PORT_CLOUD = 8883;
const char* MQTT_TOPIC_GPS = "gps/tracker";
const char* MQTT_TOPIC_ACCEL = "accel/tracker";
const char* MQTT_TOPIC_EVENT = "event/tracker";
const char* MQTT_USERNAME = "hivemqusername";
const char* MQTT_PASSWORD = "hivemqpassword";

const char* MQTT_TOPIC_SIGNAL = "signal/tracker";

unsigned long lastRssiReport = 0;
int lastRssi = 0;
float lastSnr = 0;

AsyncWebServer server(80);
AsyncWebSocket ws("/ws");

WiFiClientSecure cloudClient;
PubSubClient cloudMQTT(cloudClient);
bool useCloudMQTT = false;

String gpsData = "No GPS data received yet.";
String accelData = "No accelerometer data received yet.";
String eventData = "No event data received yet.";

String clientID = "ESP32_Tracker_" + String(random(1000, 9999));

unsigned long lastLoopTime = 0;
const unsigned long loopInterval = 10;

void setup() {
    Serial.begin(115200);
    WiFi.mode(WIFI_STA);
    WiFi.disconnect();
    delay(100);
    WiFi.begin(WIFI_SSID, WIFI_PASSWORD);

    Serial.print("Connecting to WiFi...");
    int attempts = 0;

    while (WiFi.status() != WL_CONNECTED && attempts < 10) {
        delay(500);
        Serial.print(".");
        attempts++;
    }

    if (WiFi.status() == WL_CONNECTED) {
        Serial.println("\nWiFi Connected! Using HiveMQ Cloud MQTT...");
        useCloudMQTT = true;
        cloudClient.setInsecure();
        cloudMQTT.setServer(MQTT_BROKER_CLOUD, MQTT_PORT_CLOUD);
        reconnectMQTT_Cloud();
    } else {
        Serial.println("\n Failed to connect. Switching to AP Mode...");
        useCloudMQTT = false;
        WiFi.mode(WIFI_AP);
        WiFi.softAP(AP_SSID, AP_PASSWORD);
        Serial.print("ESP32 AP IP Address: ");
        Serial.println(WiFi.softAPIP());
        startLocalServer();
    }

    LoRa.setPins(SS, RST, DIO0);
    if (!LoRa.begin(868E6)) {
        Serial.println("LoRa init failed!");
        while (1);
    }
    Serial.println("LoRa Receiver Ready!");
}

void reconnectMQTT_Cloud() {
    while (useCloudMQTT && !cloudMQTT.connected()) {
        Serial.print("Connecting to HiveMQ Cloud...");
        if (cloudMQTT.connect(clientID.c_str(), MQTT_USERNAME, MQTT_PASSWORD)) {
            Serial.println("Connected to MQTT Cloud!");
            cloudMQTT.subscribe(MQTT_TOPIC_GPS);
            cloudMQTT.subscribe(MQTT_TOPIC_ACCEL);
            cloudMQTT.subscribe(MQTT_TOPIC_EVENT);
            return;
        } else {
            Serial.println("Failed, retrying...");
            delay(5000);
        }
    }
}

void loop() {
    if (useCloudMQTT && !cloudMQTT.connected()) {
        reconnectMQTT_Cloud();
    }

    int packetSize = LoRa.parsePacket();
    if (packetSize) {
        String receivedData = "";
        while (LoRa.available()) {
            receivedData += (char)LoRa.read();
        }

        lastRssi = LoRa.packetRssi();
        lastSnr = LoRa.packetSnr();

        Serial.println("Received LoRa Data: " + receivedData);
        processData(receivedData);

        if (useCloudMQTT) {
            cloudMQTT.loop();
        }
    }
    unsigned long currentMillis = millis();
    if (currentMillis - lastRssiReport > 10000) {  // 10 seconds
        lastRssiReport = currentMillis;
        
        if (lastRssi != 0) {  // Only if we've received at least one packet
            String signalData = "RSSI:" + String(lastRssi) + ",SNR:" + String(lastSnr);
            
            Serial.print("📶 RSSI: ");
            Serial.println(lastRssi);
            Serial.print("📡 SNR: ");
            Serial.println(lastSnr);
            
            if (useCloudMQTT) {
                cloudMQTT.publish(MQTT_TOPIC_SIGNAL, signalData.c_str());
                Serial.println("✅ Signal data sent to HiveMQ Cloud!");
            }
            else if (!useCloudMQTT) {
                ws.textAll("SIGNAL:" + signalData);  
            }
        }
    }
}

void processData(String receivedData) {
    int commaIndex = receivedData.indexOf(',');
    if (commaIndex > 0) {
        String messageType = receivedData.substring(0, commaIndex);
        String payload = receivedData.substring(commaIndex + 1);

        if (messageType == MSG_TYPE_GPS) {
            gpsData = payload;
            ws.textAll("GPS:" + gpsData);
            if (useCloudMQTT) {
                if (payload.indexOf("EMERGENCY") > 0) {
                    cloudMQTT.publish(MQTT_TOPIC_GPS, ("PRIORITY:" + gpsData).c_str());
                } else {
                    cloudMQTT.publish(MQTT_TOPIC_GPS, gpsData.c_str());
                }
                Serial.println(" GPS data sent to HiveMQ Cloud!");
            }
        } else if (messageType == MSG_TYPE_ACCEL) {
            accelData = payload;
            ws.textAll("ACCEL:" + accelData);
            if (useCloudMQTT) {
                cloudMQTT.publish(MQTT_TOPIC_ACCEL, accelData.c_str());
                Serial.println(" Accelerometer data sent to HiveMQ Cloud!");
            }
        } else if (messageType == MSG_TYPE_EVENT) {
            eventData = payload;
            ws.textAll("EVENT:" + eventData);
            if (useCloudMQTT) {
                cloudMQTT.publish(MQTT_TOPIC_EVENT, ("PRIORITY:" + eventData).c_str());
                if (payload.indexOf("LAT:") > 0 && payload.indexOf("LON:") > 0) {
                    cloudMQTT.publish(MQTT_TOPIC_GPS, ("EMERGENCY:" + eventData).c_str());
                }            
                Serial.println("Event data sent to HiveMQ Cloud with PRIORITY flag!");
                delay(200);
                cloudMQTT.publish(MQTT_TOPIC_EVENT, ("PRIORITY:" + eventData).c_str());
                delay(100);
            }
        } else {
            Serial.println("❗ Unrecognized message type: " + messageType);
        }
    }
}

void startLocalServer() {
    server.on("/status", HTTP_GET, [](AsyncWebServerRequest *request){
    request->send(200, "application/json", "{\"internet\":false}");
    });

    server.on("/gps", [](AsyncWebServerRequest *request) {
        request->send(200, "text/plain", gpsData);
    });

    server.on("/accel", [](AsyncWebServerRequest *request) {
        request->send(200, "text/plain", accelData);
    });

    server.on("/event", [](AsyncWebServerRequest *request) {
        request->send(200, "text/plain", eventData);
    });

    ws.onEvent([](AsyncWebSocket *server, AsyncWebSocketClient *client, AwsEventType type, void *arg, uint8_t *data, size_t len) {
        if (type == WS_EVT_CONNECT) {
            Serial.println("WebSocket client connected");
            client->text("GPS:" + gpsData);
            client->text("ACCEL:" + accelData);
            client->text("EVENT:" + eventData);
        }
    });

    server.addHandler(&ws);
    server.begin();
    Serial.println("Local Web Server + WebSocket started!");
}
