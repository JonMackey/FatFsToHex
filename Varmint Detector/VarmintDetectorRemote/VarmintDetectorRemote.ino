
/*
*	Varmint Detector Remote Control board code, Copyright Jonathan Mackey 2018
*
*
*	GNU license:
*	This program is free software: you can redistribute it and/or modify
*	it under the terms of the GNU General Public License as published by
*	the Free Software Foundation, either version 3 of the License, or
*	(at your option) any later version.
*
*	This program is distributed in the hope that it will be useful,
*	but WITHOUT ANY WARRANTY; without even the implied warranty of
*	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
*	GNU General Public License for more details.
*
*	You should have received a copy of the GNU General Public License
*	along with this program.  If not, see <http://www.gnu.org/licenses/>.
*
*	Please maintain this license information along with authorship and copyright
*	notices in any redistribution of this code.
*
*	This code uses a modified version of Felix Rusu's RFM69 library.
*	Copyright Felix Rusu 2016, http://www.LowPowerLab.com/contact
*
*	The RFM69 library modifications allow it to be used on an ATtiny84 MCU.
*	I shedded some code (about 1K), adjusted the SPI speed, and made some
*	optimizations.
*
*	This code also uses a modified version of Jack Christensen's tinySPI Library.
*	Copyright 2018 Jack Christensen https://github.com/JChristensen/tinySPI
*
*	The tinySPI Library modification allows for 800KHz, 2MHz and 4MHz SPI speeds
*	when used with an 8MHz cpu clock.  The original code allowed for only a
*	single speed of approximately 666KHz with a 8MHz clock.
*
*
*/
#include <Arduino.h>
#include <avr/interrupt.h>
#include <RFM69.h>    // https://github.com/LowPowerLab/RFM69
#include <tinySPI.h>
#include <avr/sleep.h>

/*
*	IMPORTANT RADIO SETTINGS
*/
#define NODEID            1		// Unique for each node on same network
#define NETWORKID         0xc1	// The same on all nodes that talk to each other
//Frequency of the RFM69 module:
#define FREQUENCY         RF69_433MHZ
//#define FREQUENCY         RF69_868MHZ
//#define FREQUENCY         RF69_915MHZ

/*
*	The Varmint Detector code goes to sleep for n clock cycles if no alert has been
*	triggered to save power.
*	When the VA code wakes up from sleep, it first waits for the channel to
*	clear, then sends a query message using the special broadcast ID.  This
*	asks any listener if there's a mode change.  Possible listeners are either
*	the remote control, or another VA board that has detected motion.
*
*	When a button is pressed on a remote, the message corresponding to the
*	button pressed is determined.  The remote will broadcast this message to
*	any VA boards that are awake.  After sending the message, the remote
*	control becomes a listener, responding with the message for any query
*	messages that are received (a VA board will send a query when it wakes).
*	
*	A VA becomes a listener when motion is detected.  Once detected, and alerts
*	are enabled, it goes into listener mode.  If it receives a query message it
*	responds with the alert message causing the sender to turn into alert slave
*	mode listener.  A slave will simply wait to be put back in standby by the
*	VA that detected motion.
*
*	Note that "wait" in the message descriptions below is means that it will do
*	what's described above in terms of sending a query to determine the current
*	group operational mode.
*
*	Possible messages:
*	- Standby - Silences the device.  The device waits for motion or a message
*				from another device.
*	- Alert - The device starts playing starting from the index contained in
*			the alert message.  The slave device will wait for a status change.
*	- Mute - Same as standby except the device is silenced and motion is ignored. 
*	- Quiet - Same as mute only the device will timeout and switch to standby
*			after the timeout period has elapsed.  This is the default mode
*			after reset to give the user a chance to move out of range of the
*			motion sensor.  When in this mode, the device timeout will be reset
*			if motion is sensed.  This allows the user to move in the area of a
*			device for an extended period of time before the automatic switch
*			to standby occurs.
*	- Query - if the device is a master (detected motion OR is a remote control),
*			the device will respond with the current mode.
*/

/*
*	Uploading a new sketch:
*	The board has a standard ICSP header and a PROG/RUN DPDT switch.  Pin 1
*	of the ICSP header is as marked on the board.  When programming, the switch
*	should be in the PROG position (away from the ICSP header.)  Any 3v3 ISP
*	can be used.  Do not use a 5 volt ISP or you will damage the RFM69.  Note
*	that the ICSP connector can supply 3v3 to the board when the cable used
*	includes this pin.   If you use a 6 wire cable then disconnect the board's
*	power source.
*/

RFM69 radio;

#define SolarPin		0	// PA0	not used
#define PowerPin		1	// PA1
#define Button1Pin		2	// PA2 marked RXD
#define Button2Pin		3	// PA3 marked TXD
#define RFM69SelectPin	7	// PA7
#define MP3PowerPin		9	// PB1 not used
#define Button3Pin		10	// PB0 middle pin of the Sensor connector

//#define HAS_SERIAL
#ifdef HAS_SERIAL
#include <SendOnlySoftwareSerial.h>
SendOnlySoftwareSerial swSerial(Button2Pin); // TX
#define BAUD_RATE	19200
#endif

#define DEBOUNCE_DELAY	20	// ms
static uint8_t	sStartPinsState = 0;
static uint8_t	sLastPinsState = 0;
static uint32_t	sDebounceStartTime = 0;
static bool	sButtonsChecked = false;

// The Arduino gcc configuration limits literal constants to 2 bytes so they
// have to be defined as regular hex values
const uint32_t	kVAStandby = 0x534E4259;	// 'SNBY';
const uint32_t	kVAMute = 0x4D555445;		// 'MUTE';
const uint32_t	kVAQuiet = 0x51494554;		// 'QIET',
const uint32_t	kVAQuery = 0x51455259;		// 'QERY'

#define MESSAGE_TIMEOUT 4000	// 4 seconds
static uint32_t	sMessage;
static uint32_t	sMessageTimeout;


/********************************* setup **************************************/
void setup(void)
{    
#ifdef HAS_SERIAL
	swSerial.begin(BAUD_RATE);
	delay(10);
	swSerial.print(F("Starting..."));
#endif
	pinMode(PowerPin, OUTPUT);
	digitalWrite(PowerPin, LOW);	// Turn on the radio (P-Channel MOSFET)
#ifndef HAS_SERIAL
	pinMode(Button1Pin, INPUT_PULLUP);
#endif
	pinMode(Button2Pin, INPUT_PULLUP);
	pinMode(Button3Pin, INPUT_PULLUP);
	// Any unused pins as set as inputs pulled high to have
	// less of an impact on battery life.
	pinMode(SolarPin, INPUT_PULLUP);
	pinMode(MP3PowerPin, INPUT_PULLUP);

	radio.initialize(FREQUENCY, NODEID, NETWORKID);
	radio.sleep();
	set_sleep_mode(SLEEP_MODE_PWR_DOWN);
	/*
	*	Setup pin interrupts to detect pressing one of the 3 buttons.
	*/
	cli();
	ADCSRA &= ~_BV(ADEN);		// Turn off ADC to save power.
	GIMSK |= (_BV(PCIE0) + _BV(PCIE1));	// Enable both ports for pin change interrupts
    PCMSK0 |= (_BV(PCINT2) + _BV(PCINT3)); // Enable pin PA2 & PA3 interrupts
    PCMSK1 |= _BV(PCINT8); // Enable pin PB0 interrupt
	sei();
}

volatile uint8_t sWakeUp=0;
/***************************** Pin Change ISRs ********************************/
/*
*	Very basic ISRs that are only used to wake up the MCU when a button
*	is pressed.
*/
ISR(PCINT0_vect)
{
	sWakeUp = 1;
}
ISR(PCINT1_vect)
{
	sWakeUp = 2;
}

/******************************* UInt32ToStr **********************************/
const char* UInt32ToStr(
	uint32_t	inValue,
	char*		outStr)
{
	outStr[0] = inValue >> 24;
	outStr[1] = inValue >> 16;
	outStr[2] = inValue >> 8;
	outStr[3] = inValue;
	outStr[4] = 0;
	return(outStr);
}

/******************************* StrToUInt32 **********************************/
uint32_t StrToUInt32(
	const char* inStr)
{
	uint32_t	value = 0;
	for (uint8_t i = 0; i < 4; i++)
	{
		value = (value << 8) + ((const uint8_t*)inStr)[i];
	}
	return(value);
}

/******************************* CheckButtons **********************************/
bool CheckButtons(void)
{
	if (!sButtonsChecked)
	{
		uint32_t	currentTime = millis();
		uint32_t	debounceDuration;
		if (currentTime > sDebounceStartTime)
		{
			debounceDuration = currentTime - sDebounceStartTime;
		} else
		{
			// Handles the case where the micros wraps around back to zero.
			debounceDuration = (0xFFFFFFFFU - sDebounceStartTime) + currentTime;
		}
		/*
		*	If a debounce period has passed
		*/
		if (debounceDuration >= DEBOUNCE_DELAY)
		{
			// The pin state of pin PB0 (bit 0), PA2 (bit 2), PA3 (bit 3)
			// These pins are low true.
			uint8_t		pinsState = (PINB & _BV(PINB0)) + (PINA & (_BV(PINA2) | _BV(PINA3)));
			/*
			*	If debounced
			*/
			if (sStartPinsState == pinsState)
			{
			#ifdef HAS_SERIAL
				swSerial.print(F("pinsState = "));
				swSerial.println(pinsState);
			#endif
				sButtonsChecked = true;
				uint32_t	message = 0;
				if (sLastPinsState != pinsState)
				{
					sLastPinsState = pinsState;
					switch (pinsState)
					{
						case 5:
						{
							message = kVAStandby;
							break;
						}
						case 9:
						{
							message = kVAMute;
							break;
						}
						case 12:
						{
							message = 0x41303131;
							//message = 'A011';	// 4 byte literal constants are not supported (Arduino)
							break;
						}
					}
				}
				/*
				*	If message THEN
				*	don't go to sleep till timeout occurs
				*/
				if (message)
				{
					sMessage = message;
					sMessageTimeout = millis();
					char messageStr[5];
					// Using send rather than sendWithRetry because we don't
					// want an acknowledgement.
					radio.send(RF69_BROADCAST_ADDR, UInt32ToStr(message, messageStr), 5);
					radio.send(RF69_BROADCAST_ADDR, messageStr, 5);
				#ifdef HAS_SERIAL
					swSerial.print(F("Message sent: "));
					swSerial.println(messageStr);
				#endif
				}
			}
			sStartPinsState = pinsState;
			sDebounceStartTime = currentTime;
		}
	}
	return(sButtonsChecked);
}

/********************************** loop **************************************/
void loop(void)
{
	if (sWakeUp)
	{
	#ifdef HAS_SERIAL
		swSerial.print(F("wakeup #"));
		swSerial.println(sWakeUp);
	#endif
		sWakeUp = 0;
		sDebounceStartTime = millis();
		sButtonsChecked = false;
	}
	if (CheckButtons())
	{
		if (millis() - sMessageTimeout > MESSAGE_TIMEOUT)
		{
		#ifdef HAS_SERIAL
			swSerial.println(F("Going to sleep"));
		#endif
			sMessage = 0;
			sWakeUp = 3;
			radio.sleep();
			sleep_mode();
		} else if (radio.receiveDone() &&
			StrToUInt32(radio.DATA) == kVAQuery)
		{
			char messageStr[5];
			UInt32ToStr(sMessage, messageStr);
			if (RFM69::ACK_REQUESTED)	// Respond to ACK even if it's a broadcast ID target
			{
				radio.sendACK(messageStr, 5);
			} else
			{
				radio.sendWithRetry(radio.SENDERID, messageStr, 5);
			}
		}
	}
}

