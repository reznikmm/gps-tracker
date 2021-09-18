// SPDX-FileCopyrightText: 2021 2021 Max Reznik <reznikmm@gmail.com>
//
// SPDX-License-Identifier: MIT

#include "LoRa_APP.h"
#include "Arduino.h"
#include "GPS_Air530.h"
#include "CubeCell_NeoPixel.h"

CubeCell_NeoPixel pixels(1, RGB, NEO_GRB + NEO_KHZ800);

/*
 * set LoraWan_RGB to 1,the RGB active in loraWan
 * RGB red means sending;
 * RGB green means received done;
 */
#ifndef LoraWan_RGB
#define LoraWan_RGB 0
#endif

#define RF_FREQUENCY                                433375000 // Hz

#define TX_OUTPUT_POWER                             14        // dBm

#define LORA_BANDWIDTH                              0         // [0: 125 kHz,
                                                              //  1: 250 kHz,
                                                              //  2: 500 kHz,
                                                              //  3: Reserved]
#define LORA_SPREADING_FACTOR                       8         // [SF7..SF12]
#define LORA_CODINGRATE                             4         // [1: 4/5,
                                                              //  2: 4/6,
                                                              //  3: 4/7,
                                                              //  4: 4/8]
#define LORA_PREAMBLE_LENGTH                        8         // Same for Tx and Rx
#define LORA_SYMBOL_TIMEOUT                         0         // Symbols
#define LORA_FIX_LENGTH_PAYLOAD_ON                  false
#define LORA_IQ_INVERSION_ON                        false


struct packet {
  int32_t lat;  //  x / 360.0 * 2E9
  int32_t lng;  //  y / 360.0 * 2E9
  uint16_t tm_sat;
  uint8_t pwr;
};

#define BUFFER_SIZE                                 11 // Define the payload size here

struct packet txPacket;
// char txPacket[BUFFER_SIZE];

static RadioEvents_t RadioEvents;
void OnTxDone( void );
void OnTxTimeout( void );

typedef enum
{
    LOWPOWER,
    ReadVoltage,
    TX,
    ALLOFF
}States_t;

States_t state;
bool sleepMode = false;
uint16_t voltage;

void onKey() {
  if (state==TX) return;  // Ignore ReadVoltage
  else if (state!=ALLOFF) {
//    Serial.print("ALLOFF");
    Air530.end();
    digitalWrite(Vext, HIGH); //POWER OFF
    state=ALLOFF;
  }else{
    state=ReadVoltage;
    Air530.begin();
    Air530.setmode(MODE_GPS_GLONASS);
//    Air530.setNMEA(NMEA_GGA);
    digitalWrite(Vext, LOW); //POWER ON
     pixels.clear(); // Set all pixel colors to 'off'
     pixels.setPixelColor(0, pixels.Color(0, 0, 32));
     pixels.show();   // Send the updated pixel colors to the hardware.
  }
}

#define GPS_UPDATE_TIMEOUT 10000

void readGPS(){
  uint32_t starttime = millis();
  //  Read everything from GPS until fixed in a second
  while( (millis()-starttime) < GPS_UPDATE_TIMEOUT )
  {
    while (Air530.available() > 0)
    {
      Air530.encode(Air530.read());
    }

   // gps fixed in a second
    if( Air530.location.age() < 1000 )
    {
      break;
    }
  }
  
  if( Air530.location.age() < 1000 ){
    txPacket.lat = Air530.location.lat() / 360.0 * 2E9;
    txPacket.lng = Air530.location.lng() / 360.0 * 2E9;
    txPacket.tm_sat =
      (Air530.time.minute() * 60 + Air530.time.second()) * 16
      + (Air530.satellites.value() & 15);
  }else{
    txPacket.lat = 0;
    txPacket.lng = 0;
    txPacket.tm_sat = 0;
  }
  txPacket.pwr = (voltage - 3000.0) * 0.128;  // x/2000*256
}


void setup() {
    boardInitMcu( );
    pinMode(USER_KEY, INPUT);
    attachInterrupt(USER_KEY, onKey, FALLING);

    pinMode(Vext,OUTPUT);
    digitalWrite(Vext ,LOW); //SET POWER
    pixels.begin(); // INITIALIZE RGB strip object (REQUIRED)

    Air530.begin();
    Serial.begin(115200);
    Air530.setmode(MODE_GPS_GLONASS);
//    Air530.setNMEA(NMEA_GGA);

    voltage = 0;

    RadioEvents.TxDone = OnTxDone;
    RadioEvents.TxTimeout = OnTxTimeout;

    Radio.Init( &RadioEvents );
    Radio.SetChannel( RF_FREQUENCY );
    Radio.SetTxConfig( MODEM_LORA, TX_OUTPUT_POWER, 0, LORA_BANDWIDTH,
                                   LORA_SPREADING_FACTOR, LORA_CODINGRATE,
                                   LORA_PREAMBLE_LENGTH, LORA_FIX_LENGTH_PAYLOAD_ON,
                                   true, 0, 0, LORA_IQ_INVERSION_ON, 3000 );

    state=ReadVoltage;
}



void loop()
{
  switch(state)
  {
    case TX:
    {
//      Serial.print("in TX");
      state=LOWPOWER;
      pixels.clear(); // Set all pixel colors to 'off'
      pixels.setPixelColor(0, pixels.Color(32, 0, 0));
      pixels.show();
//      turnOnRGB(COLOR_SEND,0);
//      Serial.printf("\r\nsending packet \"%s\" , length %d\r\n",txPacket, strlen(txPacket));
      Radio.Send( (uint8_t *)&txPacket, sizeof(txPacket) );
      break;
    }
    case LOWPOWER:
    {
//      Serial.print("in LOWPOWER");
      state = ReadVoltage; 
      lowPowerHandler();
      delay(100);
      pixels.clear(); // Set all pixel colors to 'off'
      pixels.setPixelColor(0, pixels.Color(0, 0, 0));
      pixels.show();
//      turnOffRGB();
      delay(10000);  //LowPower time
      break;
    }
    case ALLOFF:
    {
//      Serial.print("in ALLOFF");
      lowPowerHandler();
      break;
    }
    case ReadVoltage:
    {
//      Serial.print("in ReadVoltage");
      state = TX;
      pinMode(VBAT_ADC_CTL,OUTPUT);
      digitalWrite(VBAT_ADC_CTL,LOW);
      voltage=analogRead(ADC)*2;

      /*
       * Board, BoardPlus, Capsule, GPS and HalfAA variants
       * have external 10K VDD pullup resistor
       * connected to GPIO7 (USER_KEY / VBAT_ADC_CTL) pin
       */
      pinMode(VBAT_ADC_CTL, INPUT);
      readGPS();

      break;
    }
     default:
//      Serial.print("in default");
          break;
  }
  Radio.IrqProcess();
}

void OnTxDone( void )
{
//  Serial.print("TX done!");
    Radio.Sleep( ); // ???
//  turnOnRGB(0,0);
      pixels.clear(); // Set all pixel colors to 'off'
      pixels.setPixelColor(0, pixels.Color(0, 0, 0));
      pixels.show();
}

void OnTxTimeout( void )
{
    Radio.Sleep( );
//    Serial.print("TX Timeout......");
    state=ReadVoltage;
}
