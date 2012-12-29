#include <OneWire.h>
#include <DallasTemperature.h>

#define USBSERIAL 9600
#define UPPIN 11
#define DOWNPIN 12
#define ONE_WIRE_BUS 10 //OneWire Pin
#define TEMPERATURE_PRECISION 9

#define VL 38 //Set Temperature

// pre setup 
OneWire oneWire(ONE_WIRE_BUS); //Setup oneWire instance

// Pass our oneWire reference to Dallas Temperature. 
DallasTemperature sensors(&oneWire);

// arrays to hold device addresses
//DeviceAddress vorlauf, ruecklauf, kessel;
DeviceAddress kessel = { 0x10, 0x39, 0x6A, 0x9C, 0x01, 0x08, 0x00, 0x02 }; // Marker zero
DeviceAddress vorlauf = { 0x10, 0x6D, 0x34, 0x9C, 0x01, 0x08, 0x00, 0xC7 }; // Marker one
DeviceAddress ruecklauf = { 0x10, 0x02, 0x21, 0x9C, 0x01, 0x08, 0x00, 0x8E }; // Marker two



// functions used 

// function to print a device address
void printAddress(DeviceAddress deviceAddress)
{
  for (uint8_t i = 0; i < 8; i++)
  {
    // zero pad the address if necessary
    if (deviceAddress[i] < 16) Serial.print("0");
    Serial.print(deviceAddress[i], HEX);
  }
}

void mixer(int up,int down) {
    digitalWrite(UPPIN  ,up);      
    digitalWrite(DOWNPIN,down);
}

float getTemperature(DeviceAddress deviceAddress)
{
  float tempC = sensors.getTempC(deviceAddress);
  if (tempC == -127.00) {
    Serial.println("Error getting temperature");
  } else {
    return (tempC);
  }
}

void printAll(void)
{
      Serial.println("Requesting temperatures...");
  sensors.requestTemperatures();
  Serial.print("Kessel : ");  // Boiler Circuit
  Serial.println(getTemperature(kessel));
  Serial.print("Vorlauf : "); // to Radiators
  Serial.println(getTemperature(vorlauf));
  Serial.print("Ruecklauf : "); // from Radiators
  Serial.println(getTemperature(ruecklauf));
}

void PrintTemp(float TempK, float TempV, float TempR) {
  Serial.print("Kessel: ");
  Serial.print(TempK);
  Serial.print(" Vorlauf: ");
  Serial.print(TempV);
  Serial.print(" Ruecklauf: ");
  Serial.println(TempR);
}


void setup(void) {
    pinMode( UPPIN       , OUTPUT );
    pinMode( DOWNPIN     , OUTPUT );
    mixer(0,0); // stops the mixer
    Serial.begin(USBSERIAL);        // init USB Serial (console)

    sensors.begin();
    sensors.setResolution(kessel, 12);
    sensors.setResolution(vorlauf, 12);
    sensors.setResolution(ruecklauf, 12);
    
    // report parasite power requirements
    Serial.print("Parasite power is: "); 
    if (sensors.isParasitePowerMode()) Serial.println("ON");
    else Serial.println("OFF");
    //   taken from example, but never worked 
    //   kessel = { 0x10, 0x39, 0x6A, 0x9C, 0x01, 0x08, 0x00, 0x02 }; // Marker zero
    //   vorlauf = { 0x10, 0x6D, 0x34, 0x9C, 0x01, 0x08, 0x00, 0xC7 }; // Marker one
    //   ruecklauf = { 0x10, 0x02, 0x21, 0x9C, 0x01, 0x08, 0x00, 0x8E }; // Marker two

    if (!sensors.getAddress(kessel, 0)) Serial.println("Unable to find address for Kessel"); 
    if (!sensors.getAddress(vorlauf, 1)) Serial.println("Unable to find address for Vorlauf"); 
    if (!sensors.getAddress(ruecklauf, 2)) Serial.println("Unable to find address for Ruecklauf"); 

    Serial.print("Device Kessel Address: ");
    printAddress(kessel);
    Serial.println();

    Serial.print("Device Vorlauf Address: ");
    printAddress(vorlauf);
    Serial.println();

    Serial.print("Device Ruecklauf Address: ");
    printAddress(ruecklauf);
    Serial.println();
    
    // set the resolution to 9 bit
    sensors.setResolution(kessel, TEMPERATURE_PRECISION);
    sensors.setResolution(vorlauf, TEMPERATURE_PRECISION);
    sensors.setResolution(ruecklauf, TEMPERATURE_PRECISION);

    Serial.print("Kessel Resolution: ");
    Serial.print(sensors.getResolution(kessel), DEC); 
    Serial.println();

    Serial.print("Vorlauf Resolution: ");
    Serial.print(sensors.getResolution(vorlauf), DEC); 
    Serial.println();
  
    Serial.print("Ruecklauf Resolution: ");
    Serial.print(sensors.getResolution(ruecklauf), DEC); 
    Serial.println();
}


void loop() {
  sensors.requestTemperatures();       // get Data
  float Tk = getTemperature(kessel);   
  float Tv = getTemperature(vorlauf); 
  float Tr = getTemperature(ruecklauf); 
  
  PrintTemp(Tk, Tv, Tr);              // print DS1820 values
  
  
  if (Tk + 4 < VL)                    // Tk Sensor is reporting incorrect Data, ugly fix
    { 
      Serial.println("Boiler too cold, waiting for ignition"); // Boiler too cold
      mixer(1,0);                     // open mixer Valve
      delay(1000); 
      mixer(0,0);
      delay(10000);                   // wait for ignition 
    }
  else {
      if ((Tv - VL) > 0)              // too hot cool down !
      {
        Serial.print("cool down");
        if ((Tv - VL) > 10)           // way too hot, drive mixer valve down
          {
            Serial.println(" fast");
            mixer(0,1); 
            delay(10000); 
            mixer(0,0);
          }
        else if ((Tv - VL) > 5)       // too hot
          {
            Serial.println("");
            mixer(0,1);
            delay(5000);
            mixer(0,0);
          }
        else if ((Tv - VL) > 0.75)    // a bit to warm
          {
            Serial.println(" slow");
            mixer(0,1);
            delay(2500);
            mixer(0,0);
          }
        else 
          {
            Serial.println("\r\nTemp within upper hysteresis");
          }
            
      }
      else if ((Tv - VL < 0))
      {
       Serial.print("heat up");
       if ((Tv - VL) < -10)           // way too cold, drive mixer valve up
          {
            Serial.println(" fast");
            mixer(1,0); 
            delay(10000); 
            mixer(0,0);
          }
        else if ((Tv - VL) < -5)
          {
            Serial.println("");
            mixer(1,0);
            delay(5000);
            mixer(0,0);
          }
          
         else if ((Tv -VL) < - 0.75)
          {
            Serial.println(" slow");
            mixer(1,0);
            delay(2500);
            mixer(0,0);
          }
        else 
          {
            Serial.println("\r\nTemp within lower hysteresis");
          }
      }
      else {
        Serial.println(" Temp ok !");
      }
  }

delay(7000);                       // wait, system is reacting slow
    
   
}
