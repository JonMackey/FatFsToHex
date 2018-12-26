
/*
*	Varmint Detector board code, Copyright Jonathan Mackey 2018
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
*	Libraries used:
*	- a modified version of Felix Rusu's RFM69 library.
*	Copyright Felix Rusu 2016, http://www.LowPowerLab.com/contact
*
*	The RFM69 library modifications allow it to be used on an ATtiny84 MCU.
*	I shedded some code (about 1K), adjusted the SPI speed, and made some
*	optimizations.
*
*	-  a modified version of Jack Christensen's tinySPI Library.
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
#include <DFPlayer.h>
#include <avr/sleep.h>
#include <avr/wdt.h>

/*
*	IMPORTANT RADIO SETTINGS
*/
#define NODEID            2		// Unique for each node on same network
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

#define SolarPin		0	// PA0 Solar voltage sense pin used to determine when it's near dark
#define PowerPin		1	// PA1 Controls power for both the sensor and radio
#define RxPin			2	// PA2
#define TxPin			3	// PA3
#define RadioSelectPin	7	// PA7
#define MP3PowerPin		9	// PB1 Controls the power to the MP3 player and associated ICs
#define SensorPin		10	// PB0 Connected to the PIR sensor

#include <SoftwareSerial0.h>  // << A modified version of SoftwareSerial for PortA pins only.
SoftwareSerial0 swSerial(RxPin, TxPin); // RX, TX
DFPlayer dfPlayer(swSerial);

// The Arduino gcc configuration limits literal constants to 2 bytes so they
// have to be defined as regular hex values
const uint32_t	kVAStandby =	0x534E4259;	// 'SNBY';
const uint32_t	kVAMute =		0x4D555445;	// 'MUTE';
const uint32_t	kVAQuiet =		0x51494554;	// 'QIET',
const uint32_t	kVAQuery =		0x51455259;	// 'QERY'
const uint32_t	kVAlertPrefix =	0x41000000;	// 'A'

//#define DEBUG_NO_SHUTDOWN	1
//#define DEBUG_NO_SOUND	1
//#define DEBUG_MP3_POWER	1
/*
*	When in standby or quiet modes, the mcu goes to sleep for 2 seconds after
*	loop is called.
*/
#ifdef DEBUG_NO_SOUND
#define QUIET_DELAY	1	// Wait 2 seconds (one loop) before switching to standby
#else
#define QUIET_DELAY	10	// Wait 20 seconds (ten loops) before switching to standby
#endif
#define SLAVE_QUERY_TIMEOUT		2000	// Send a query to the master every 2 seconds
#define ALERT_TIMEOUT	10000	// 10 seconds
#define MASTER_TO_STANDBY_TIMEOUT	4000	// 4 seconds to let any other VAs to move to standby
static uint16_t	sMP3Index = 1;
static uint16_t	sMP3Count = 10;	// Not the actual count.  A query to the player will get the actual.
static uint32_t	sAlertStart;
static uint32_t	sLastSlaveQueryTime;
static uint8_t	sQuietToStandbyCountdown;
enum
{
	// Note that the enum values/position should not be changed without updating the code.
	// Anything <= eStandby goes to sleep after each loop
	// Anything >= eSlave is assumed to be playing
	eShutdown,	// Shutdown due to darkness
	eMute,		// Waiting to move to eStandby when kVAStandby is received
	eStandby,	// Waiting for the PIR to trip or any message from a master
	eQuiet,		// Waiting to move to eStandby when sAlertStart or kVAStandby is received
	eSlave,		// Playing and waiting to move to eStandby when kVAStandby is received
	eMaster		// Playing and waiting to move to eStandby when sAlertStart or any message from another master
};
static uint8_t	sMode;

#define PLAY_TRACK			3
#define SET_VOLUME			6
#define VOLUME				29	// << SET_VOLUME param (1 to 30)
#define STOP_PLAY			0x16
#define QUERY_NUM_FLASH_FILES_CMD		0x49

/********************************* setup **************************************/
void setup(void)
{    
	swSerial.begin(9600);	// <<< Must be 9600 for the MP3 chip
	dfPlayer.begin();
	delay(10);
#ifdef DEBUG_NO_SOUND
	swSerial.println(F("Starting..."));
#endif
	pinMode(SolarPin, INPUT);
	pinMode(PowerPin, OUTPUT);
	digitalWrite(PowerPin, LOW);	// Turn on the sensor and radio
	pinMode(SensorPin, INPUT);
	pinMode(MP3PowerPin, OUTPUT);
	PowerDownMP3();

	radio.initialize(FREQUENCY,NODEID,NETWORKID);
	radio.sleep();
	sMode = eQuiet;
	sQuietToStandbyCountdown = QUIET_DELAY;
	set_sleep_mode(SLEEP_MODE_PWR_DOWN);
	cli();					// Disable interrupts
	ADCSRA &= ~_BV(ADEN);	// Turn off ADC to save power.
	GIMSK |= _BV(PCIE1);	// Enable port B for pin change interrupts
    PCMSK1 |= _BV(PCINT8);	// Enable pin PB0 pin change interrupt
	sei();					// Enable interrupts
	GetMP3FileCount();
}

/****************************** Pin Change ISR ********************************/
/*
*	Very basic ISR that is only used to wake up the MCU when the PIR sensor
*	is tripped or cleared.
*/
ISR(PCINT1_vect)
{
}

/******************************** watchdog ************************************/
/*
*	This gets triggered to wake up from power down to check to see if another
*	alert detector has been triggered.  This check isn't done here, it's done
*	in the loop function.
*/
ISR(WATCHDOG_vect)
{
	WDTCSR |= _BV(WDIE);	// Set WDIE.  WDIE gets cleared when the interrupt
							// is called It needs to be set back to 1 otherwise
							// the next timeout will reset the MCU
}

/************************ WaitForPlayerCommandCompeted ************************/
bool WaitForPlayerCommandCompeted(
	uint32_t	inTimeout)
{
	uint32_t	duration;
	uint32_t	start = millis();
	while (dfPlayer.CommandCompleted() == false)
	{
	#if 1
		// This is off by at most one ms if millis() has wrapped around since
		// start was initialized.  (which is accurate enough)
		duration = millis() - start;
	#else
		uint32_t	timeNow = millis();
		if (timeNow > start)
		{
			// Note that the compiler optimization of this is quite good.
			// The subtraction of timeNow - start is performed  when timeNow is
			// compared to start above.  Setting duration to the result is only
			// a move.
			duration = timeNow - start;
		} else
		{
			// Handles the case where the millis wraps around back to zero.
			duration = ~(start) + timeNow; // Same as (0xFFFFFFFFU - start) + timeNow
		}
	#endif
		if (duration < inTimeout)
		{
			continue;
		}
		// timeout occured
		return(false);
	}
	return(true);
}

/******************************** PowerUpMP3 **********************************/
void PowerUpMP3(void)
{
#ifdef DEBUG_NO_SOUND
	swSerial.println(F("PowerUpMP3"));
#elif !defined DEBUG_MP3_POWER
	// Clear the serial buffer
	while (swSerial.available())
	{
		swSerial.read();
	}
	dfPlayer.ClearReplyCommand();
	digitalWrite(MP3PowerPin, LOW);	// Turn on MP3 section
	digitalWrite(RxPin, HIGH);
	digitalWrite(TxPin, HIGH);
	dfPlayer.SendCommand(STOP_PLAY, 0, true);	// For debugging, so the startup time can be measured
												// using the DFPlayerDebug sketch.  DFPlayerDebug will
												// report the time between command/responses.
	/*
	*	On startup the MP3 chip will try to start playing, so first try to
	*	silence it by sending a stop command.  And, even though the player
	*	responds with OK, it may not stop, so preload the current track, then
	*	immediately stop it.another stop command is sent
	*	Without this odd combination of commands the first request to play a track
	*	may result in playing a different track than what was requested.  The
	*	only pattern I've noticed is that this bug is more likely after a cold
	*	start where the MP3 player section has been powered down for more than
	*	10 seconds (meaning the caps have completely drained.)
	*/
	WaitForPlayerCommandCompeted(2000); // Wait for the player to initialize, timeout 2 seconds
	dfPlayer.SendCommand(STOP_PLAY, 0, true);	// Tell it to stop playing (it automatically starts playing)
	WaitForPlayerCommandCompeted(50);
	delay(100);
	dfPlayer.SendCommand(PLAY_TRACK, sMP3Index, true);	// Preload the current track
	WaitForPlayerCommandCompeted(50);
	dfPlayer.SendCommand(STOP_PLAY, 0, true);	// Tell it to stop playing
	WaitForPlayerCommandCompeted(50);
	delay(100);
	// The default volume at startup is full volume (30)
#if defined VOLUME && VOLUME < 30
	dfPlayer.SendCommand(SET_VOLUME, VOLUME, true);
	WaitForPlayerCommandCompeted(100);		
#endif
#endif
}

/******************************* PowerDownMP3 *********************************/
void PowerDownMP3(void)
{
#ifdef DEBUG_NO_SOUND
	swSerial.println(F("PowerDownMP3"));
#endif
	// Set both serial lines low to avoid backfeeding power to the MP3 player
	digitalWrite(RxPin, LOW);
	digitalWrite(TxPin, LOW);
	digitalWrite(MP3PowerPin, HIGH);	// Turn off power to MP3 section
}

/****************************** GetMP3FileCount *******************************/
void GetMP3FileCount(void)
{
#if !defined DEBUG_NO_SOUND && !defined DEBUG_MP3_POWER
	PowerUpMP3();
	dfPlayer.SendCommand(QUERY_NUM_FLASH_FILES_CMD, 0, true);
	WaitForPlayerCommandCompeted(100);
	PowerDownMP3();
	if (dfPlayer.GetCommand() == QUERY_NUM_FLASH_FILES_CMD)
	{
		sMP3Count = dfPlayer.GetParam();
	}
	dfPlayer.ClearReplyCommand();
#endif
}

/***************************** PowerUpMP3AndPlay ******************************/
void PowerUpMP3AndPlay(void)
{
#if !defined DEBUG_NO_SOUND && !defined DEBUG_MP3_POWER
	PowerUpMP3();
	dfPlayer.PlayNthRootFile(sMP3Index);
#endif
}

/********************************** loop **************************************/
void loop(void)
{
	if (!ShutDownDueToDarkness())
	{
		if (radio.receiveDone())
		{
			HandleMessageRx(StrToUInt32((const char*)radio.DATA));
		}
	
		switch (sMode)
		{
			/*
			*	For modes, eQuiet, eStandby and eMute, the mcu goes to sleep
			*	for 2 seconds per call to loop.  For eSlave it's always awake
			*	therefore eSlave needs to test for a timeout.
			*/
			case eQuiet:
			#ifdef DEBUG_NO_SOUND
				swSerial.println(sQuietToStandbyCountdown);
			#endif
				/*
				*	As noted above, in eQuiet mode the mpu goes to sleep for 2
				*	seconds per loop. Because of this sQuietToStandbyCountdown is a
				*	loop count.
				*/
				if (sQuietToStandbyCountdown)
				{
					sQuietToStandbyCountdown--;
					break;
				}
				sMode = eStandby;
				// fall through
			case eStandby:
			case eMute:
			{
				char	messageStr[5];
				if (radio.sendWithRetry(RF69_BROADCAST_ADDR, UInt32ToStr(kVAQuery, messageStr), 5, 1))
				{
					HandleMessageRx(StrToUInt32((const char*)radio.DATA));
				}
				CheckForMotion();
				
				break;
			}
			case eSlave:
			{
				if ((millis() - sLastSlaveQueryTime) > MASTER_TO_STANDBY_TIMEOUT)
				{
					char	messageStr[5];
					sLastSlaveQueryTime = millis();
					if (radio.sendWithRetry(RF69_BROADCAST_ADDR, UInt32ToStr(kVAQuery, messageStr), 5, 1))
					{
						HandleMessageRx(StrToUInt32((const char*)radio.DATA));
					}
					// The mode may have changed within HandleMessageRx
					if (sMode == eStandby)
					{
						CheckForMotion();
					} else if (sMode == eSlave &&
						(millis() - sAlertStart) > ALERT_TIMEOUT)
					{
						sMode = eStandby;
						PowerDownMP3();
					}
				}
				break;
			}
			case eMaster:
			{
				CheckForMotion();
				/*
				*	If the sAlertStart + the time to allow slave VAs to move to
				*	standby has passed THEN
				*	move the master to standby
				*/
				if ((millis() - sAlertStart) > ALERT_TIMEOUT + MASTER_TO_STANDBY_TIMEOUT)
				{
					sMode = eStandby;
					PowerDownMP3();
				}
				break;
			}
		}
		/*
		*	If the mode is quiet, standby or mute THEN
		*	go to sleep for 2 seconds.  (Even though the eShutdown < eQuiet,
		*	the mode will never be eShutdown here.)
		*/
		if (sMode <= eQuiet)
		{
			GoToSleep(WDTO_2S);
		/*
		*	Else if the mode is master OR slave THEN
		*	update the sMP3Index
		*/
		} else if (sMode >= eSlave)
		{
			UpdateMP3Index();
		}
	}
}

/********************************* GoToSleep **********************************/
/*
*	Goes into a timed sleep
*/
void GoToSleep(
	uint8_t	inLength)
{
	radio.sleep();
	wdt_enable(inLength);
	WDTCSR |= _BV(WDIE);
	sleep_mode();	// Go to sleep
	wdt_disable();
}

/*************************** ShutDownDueToDarkness ****************************/
/*
*	Regardless of the current mode, shut down if it's too dark to power without
*	using the battery.
*/
bool ShutDownDueToDarkness(void)
{
#ifdef DEBUG_NO_SOUND
	if (sMode <= eQuiet)
		swSerial.println(F("."));	// Heartbeat
#endif
#ifndef DEBUG_NO_SHUTDOWN
	/*
	*	Measure the solar panel voltage.
	*	Because the solar panel can produce nearly 6 volts in full sun, and this
	*	is a 3v3 board, the voltage is divided by 2 on the board by R11 and R12.
	*	The reading represents 0 to almost 3 volts. 
	*/ 
	cli();					// Disable interrupts
	ADCSRA |= _BV(ADEN);	// Turn on ADC.
	sei();					// Enable interrupts
	int panelVoltage = analogRead(SolarPin); // a value from 0 to 1023
	cli();					// Disable interrupts
	ADCSRA &= ~_BV(ADEN);	// Turn off ADC to save power.
	sei();					// Enable interrupts
	/*
	*	If it's almost dark THEN
	*	shut everything down and wake every 8 seconds to see if it's light
	*	enough to start up.
	*	If the board had a RTC it could sleep for much longer periods, but the
	*	longest stretch is for the ATtiny84A is 8 seconds.
	*
	*	I don't think there's any need to take the other nodes out.  If they're
	*	also in darkness (or soon to be), then they'll go to standby or sleep
	*	on their own.
	*/
	if (panelVoltage < 300)
	{
		if (sMode != eShutdown)
		{
		#ifdef DEBUG_NO_SOUND
			swSerial.println(F("Going to sleep"));
		#endif
			cli();					// Disable interrupts
			GIMSK &= ~_BV(PCIE1);	// Disable port B for pin change interrupts
			sei();					// Enable interrupts
			sMode = eShutdown;
			// Seems odd, but you need to have the radio awake prior to removing
			// power otherwise the CS backfeeds if it's in sleep mode when pwoer
			// is removed.  Calling receiveDone (or pretty much anything) makes
			// sure it's not in sleep mode.
			radio.receiveDone();
			// Turn off the sensor and radio
			digitalWrite(PowerPin, HIGH);
			// Set the SPI pin modes to prevent backfeeding through radio
			// DO_DD_PIN & USCK_DD_PIN are defined in tinySPI.h
			// RF69_SPI_CS is defined in RFM69.h
			digitalWrite(DO_DD_PIN, LOW);
			pinMode(DO_DD_PIN, INPUT);		// MOSI
			digitalWrite(USCK_DD_PIN, LOW);
			pinMode(USCK_DD_PIN, INPUT);	// SCK
			
			PowerDownMP3();
		}
		wdt_enable(WDTO_8S);
		WDTCSR |= _BV(WDIE);
		sleep_mode();	// Go to sleep
		wdt_disable();
	} else if (sMode == eShutdown)
	{
	#ifdef DEBUG_NO_SOUND
		swSerial.println(F("Waking up"));
	#endif
		// Restore SPI pin modes
		pinMode(DO_DD_PIN, OUTPUT);
		pinMode(USCK_DD_PIN, OUTPUT);
		
		// Turn on the sensor and radio
		digitalWrite(PowerPin, LOW);
		delay(20);	// Let the radio power stablize before intialization
		radio.initialize(FREQUENCY,NODEID,NETWORKID);
		radio.sleep();
		sMode = eQuiet;
		sQuietToStandbyCountdown = QUIET_DELAY;	// Give the PIR time to stabilize
		cli();					// Disable interrupts
		GIMSK |= _BV(PCIE1);	// Enable port B for pin change interrupts
		sei();					// Enable interrupts
	}
#endif
	return(sMode == eShutdown);
}

/******************************* CheckForMotion *******************************/
void CheckForMotion(void)
{
	bool isMovement = (PINB & _BV(PINB0)) != 0;
	if (isMovement &&
		(sMode == eStandby || sMode == eMaster))
	{
		// For master, if something is continuing to trip the motion sensor then
		// extend the timeout.
		sAlertStart = millis();
		/*
		*	If on standby THEN
		*	become the master and start playing.
		*/
		if (sMode == eStandby)
		{
			sMode = eMaster;
			sMP3Index++;
			if (sMP3Index > sMP3Count)
			{
				sMP3Index = 1;
			}
		#ifdef DEBUG_NO_SOUND
			swSerial.println(F("Motion Detected"));
		#endif
			PowerUpMP3AndPlay();
		}
	}
}

/***************************** HandleMessageRx ********************************/
void HandleMessageRx(
	uint32_t	inMessage)
{
#ifdef DEBUG_NO_SOUND
	{
		char messageRxStr[5];
		swSerial.print(F("inMessage = \'"));
		swSerial.print(UInt32ToStr(inMessage, messageRxStr));
		swSerial.print(F("\' / 0x"));
		swSerial.println(inMessage, HEX);
	}
#endif
	switch (inMessage)
	{
		case kVAQuery:
		{
			/*
			*	If master THEN
			*	respond to the query with the current message
			*/
			if (sMode == eMaster)
			{
				char	messageStr[5];
				/*
				*	If the alert is still playing THEN
				*	tell the sender to switch to slave mode, playing sMP3Index.
				*/
				if ((millis() - sAlertStart) < ALERT_TIMEOUT)
				{
					CreateAlertMsg(sMP3Index, messageStr);
				/*
				*	Else tell the slave to move to standby.
				*/
				} else
				{
					UInt32ToStr(kVAStandby, messageStr);
				}
				if (RFM69::ACK_REQUESTED)	// Respond to ACK even if it's a broadcast ID target
				{
					radio.sendACK(messageStr, 5);
				} else
				{
					radio.sendWithRetry(radio.SENDERID, messageStr, 5);
				}
			}
			break;
		}
		case kVAStandby:
		{
			if (sMode >= eSlave)
			{
				PowerDownMP3();
			}
			sMode = eStandby;
			break;
		}
		case kVAMute:
		{
			if (sMode >= eSlave)
			{
				PowerDownMP3();
			}
			sMode = eMute;
			break;
		}
		case kVAQuiet:
		{
			if (sMode >= eSlave)
			{
				PowerDownMP3();
			}
			sMode = eQuiet;	// Quiet eventually changes to standby
			// Set delay for moving to standby
			sQuietToStandbyCountdown = QUIET_DELAY;
			break;
		}
		default:
			if ((inMessage & 0xFF000000) == kVAlertPrefix)
			{
				sAlertStart = millis();	// Extend the timeout
				if (sMode != eSlave)
				{
					sMode = eSlave;
					sLastSlaveQueryTime = millis();
					sMP3Index = MP3IndexFromMessage(inMessage);
					PowerUpMP3AndPlay();
				}
			}
			break;
	}
}

/***************************** UpdateMP3Index *********************************/
void UpdateMP3Index(void)
{
	if (dfPlayer.CommandCompleted())
	{
		sMP3Index++;
		if (sMP3Index > sMP3Count)
		{
			sMP3Index = 1;
		}
		dfPlayer.PlayNthRootFile(sMP3Index);
	}
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

/**************************** MP3IndexFromMessage *****************************/
uint16_t MP3IndexFromMessage(
	uint32_t	inMessageRx)
{
	return(((((inMessageRx >> 16) & 0xFF) - '0') * 100) +
				((((inMessageRx >> 8) & 0xFF) - '0') * 10) +
					(inMessageRx & 0xFF) - '0');
}

/****************************** CreateAlertMsg ********************************/
const char* CreateAlertMsg(
	uint16_t	inMP3Index,
	char*		outStr)
{
	outStr[0] = 'A';
	if (inMP3Index > 999)inMP3Index = 999;
	outStr[1] = (inMP3Index/100) + '0';
	inMP3Index %= 100;
	outStr[2] = (inMP3Index/10) + '0';
	inMP3Index %= 10;
	outStr[3] = inMP3Index + '0';
	outStr[4] = 0;
	return(outStr);
}