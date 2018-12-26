/*
*	NOTE: This is a modified version of Jack Christensen's code.
*	Jon Mackey 2018: The tinySPI Library modification allows for 800KHz, 2MHz
*	and 4MHz SPI speeds when used with an 8MHz cpu clock.  The original code
*	allowed for only a single speed of approximately 666KHz with a 8MHz clock.
*/

// Arduino tinySPI Library Copyright (C) 2018 by Jack Christensen and
// licensed under GNU GPL v3.0, https://www.gnu.org/licenses/gpl.html
//
// Arduino hardware SPI master library for
// ATtiny24/44/84, ATtiny25/45/85, ATtiny261/461/861, ATtiny2313/4313.
//
// https://github.com/JChristensen/tinySPI
// Jack Christensen 24Oct2013
//

#include <tinySPI.h>

static void tinySPI::begin()
{
    USICR &= ~(_BV(USISIE) | _BV(USIOIE) | _BV(USIWM1));
    USICR |= _BV(USIWM0) | _BV(USICS1) | _BV(USICLK);
    SPI_DDR_PORT |= _BV(USCK_DD_PIN);   // set the USCK pin as output
    SPI_DDR_PORT |= _BV(DO_DD_PIN);     // set the DO pin as output
    SPI_DDR_PORT &= ~_BV(DI_DD_PIN);    // set the DI pin as input
}

static void tinySPI::setDataMode(uint8_t spiDataMode)
{
    if (spiDataMode == SPI_MODE1)
        USICR |= _BV(USICS0);
    else
        USICR &= ~_BV(USICS0);
}

#define SPI_CLOCK_DIV4 0x00
//#define SPI_CLOCK_DIV16 0x01
//#define SPI_CLOCK_DIV64 0x02
//#define SPI_CLOCK_DIV128 0x03
#define SPI_CLOCK_DIV2 0x04
#define SPI_CLOCK_DIV8 0x05
//#define SPI_CLOCK_DIV32 0x06

#define SPI_CLOCK_XXX SPI_CLOCK_DIV4

static uint8_t tinySPI::transfer(uint8_t spiData)
{
    USIDR = spiData;					// Set the data to be shifted out
    USISR = _BV(USIOIF);                // clear counter and counter overflow interrupt flag
    ATOMIC_BLOCK(ATOMIC_RESTORESTATE)   // ensure a consistent clock period
    {
		// Timing notes are for an 8MHz clock
#if SPI_CLOCK_XXX == SPI_CLOCK_DIV8
    	// Keep writing a 1 to bit USITC of USICR.
    	// Each time a 1 is written the USI will shift out
    	// the MSB of USIDR to DO, shift in  a bit to the LSB of USIDR
    	// from DI, and toggle the USCK.
    	// Keep looping till the counter overflows (all 8 bits sent/received)
    	// 800KHz with ticktock, 666KHz with original code using |=.
		uint8_t ticktock = USICR | _BV(USITC);
        while ( !(USISR & _BV(USIOIF)) ) USICR = ticktock;
       // while ( !(USISR & _BV(USIOIF)) ) USICR |= _BV(USITC);  << original code
#elif SPI_CLOCK_XXX == SPI_CLOCK_DIV2 || SPI_CLOCK_XXX == SPI_CLOCK_DIV4
		// Based on ATtiny84A doc example.
		// 2MHz with nop's 4MHz without (as in doc example).
		uint8_t tick = USICR | _BV(USITC);
		tick &= ~_BV(USICLK);	// preserves setDataMode
		uint8_t tock = USICR | _BV(USITC) | _BV(USICLK);
	#if SPI_CLOCK_XXX == SPI_CLOCK_DIV2
		// No delay
		#define SPI_CLOCK_DELAY
	#else
		// Divide clock by 2
		#define SPI_CLOCK_DELAY __asm__("nop")
	#endif
		USICR = tick;
		SPI_CLOCK_DELAY; 
		USICR = tock;
		SPI_CLOCK_DELAY; 
		USICR = tick;
		SPI_CLOCK_DELAY; 
		USICR = tock;
		SPI_CLOCK_DELAY; 
		USICR = tick;
		SPI_CLOCK_DELAY; 
		USICR = tock;
		SPI_CLOCK_DELAY; 
		USICR = tick;
		SPI_CLOCK_DELAY; 
		USICR = tock;
		SPI_CLOCK_DELAY; 
		USICR = tick;
		SPI_CLOCK_DELAY; 
		USICR = tock;
		SPI_CLOCK_DELAY; 
		USICR = tick;
		SPI_CLOCK_DELAY; 
		USICR = tock;
		SPI_CLOCK_DELAY; 
		USICR = tick;
		SPI_CLOCK_DELAY; 
		USICR = tock;
		SPI_CLOCK_DELAY; 
		USICR = tick;
		SPI_CLOCK_DELAY; 
		USICR = tock;
#endif
    }
    return USIDR;
}

static void tinySPI::end()
{
    USICR &= ~(_BV(USIWM1) | _BV(USIWM0));
}

tinySPI SPI;
