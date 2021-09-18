// SPDX-FileCopyrightText: 2021 2021 Max Reznik <reznikmm@gmail.com>
//
// SPDX-License-Identifier: MIT

#include "heltec.h"

struct packet {
  int32_t lat;  //  x / 360.0 * 2E9
  int32_t lng;  //  y / 360.0 * 2E9
  uint16_t tm_sat;
  uint8_t pwr;
};


#define BAND    433375000  //you can set band here directly,e.g. 868E6,915E6
void setup() {
    //WIFI Kit series V1 not support Vext control
  Heltec.begin(false /*DisplayEnable Enable*/, true /*Heltec.LoRa Disable*/, true /*Serial Enable*/, true /*PABOOST Enable*/, BAND /*long BAND*/);
  LoRa.setSpreadingFactor(8);
  LoRa.setSignalBandwidth(125E3);
  LoRa.setCodingRate4(4);
  LoRa.setSyncWord(0x12);
  LoRa.setPreambleLength(8);
  LoRa.onReceive(onReceive);
  LoRa.receive();
}

void onReceive(int packetSize)
{
  struct packet pkg;
  char *p = (char*)&pkg;
  if (packetSize != sizeof (pkg)) return;

  // read packet
  for (int i = 0; i < packetSize; i++)
  {
    *p++ = (char)LoRa.read();
  }
    Serial.print("{\"lat\":");
    Serial.print(double(pkg.lat)/2E9*360.0, 8);
    Serial.print(",\"lng\":");
    Serial.print(double(pkg.lng)/2E9*360.0, 8);
    Serial.print(",\"tm\":\"");
    Serial.print(pkg.tm_sat/16/60);
    Serial.print(":");
    Serial.print(pkg.tm_sat/16%60);
    Serial.print("\",\"sat\":");
    Serial.print(pkg.tm_sat%16);
    Serial.print(",\"pwr\":");
    Serial.print(3.0+double(pkg.pwr)/128.0);
  // print RSSI of packet
    Serial.print(",\"rssi\":");
    Serial.print(LoRa.packetRssi());
    Serial.println("}");
}

void loop() {
  // try to parse packet
}
