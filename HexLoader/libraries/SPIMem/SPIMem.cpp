/*******************************************************************************
	License
	****************************************************************************
	This program is free software; you can redistribute it
	and/or modify it under the terms of the GNU General
	Public License as published by the Free Software
	Foundation; either version 3 of the License, or
	(at your option) any later version.
 
	This program is distributed in the hope that it will
	be useful, but WITHOUT ANY WARRANTY; without even the
	implied warranty of MERCHANTABILITY or FITNESS FOR A
	PARTICULAR PURPOSE. See the GNU General Public
	License for more details.
 
	Licence can be viewed at
	http://www.gnu.org/licenses/gpl-3.0.txt
//
	Please maintain this license information along with authorship
	and copyright notices in any redistribution of this code
*******************************************************************************/
/*
*	SPIMem.cpp
*	Copyright (c) 2018 Jonathan Mackey
*
*	Class to r/w from/to NOR Flash memory (bare minimum)
*/
#include "Arduino.h"
#include <SPI.h>
#include "SPIMem.h"

#ifdef F_CPU
	#if F_CPU >= 16000000L
		#define SPI_CLOCK_DIV SPI_CLOCK_DIV4
	#else // 8 MHz
		#define SPI_CLOCK_DIV SPI_CLOCK_DIV2
	#endif
#else
	#define SPI_CLOCK_DIV SPI_CLOCK_DIV4
#endif

enum
{
	ePageProgCmd	= 2,
	eReadDataCmd,
	eWriteDisableCmd,
	eReadStat1Cmd,
	eWriteEnableCmd,
	eEraseSectorCmd	= 0x20,
	eErase32KBlkCmd	= 0x52,
	eChipEraseCmd	= 0x60,
	eErase64KBlkCmd	= 0xD8,
	eReadJEDECIDCmd	= 0x9F,
	
	eChipBusyBit	=	1,
	eWriteEnabledBit
};

/*********************************** SPIMem ************************************/
SPIMem::SPIMem(
	uint8_t		inCSPin)
	: mCSPin(inCSPin)
{
}

/*********************************** begin ************************************/
void SPIMem::begin(void)
{
	digitalWrite(mCSPin, HIGH);
	pinMode(mCSPin, OUTPUT);
	SPI.begin();
	LoadJEDECInfo();
}

/********************************** Select ************************************/
void SPIMem::Select(void)
{
	noInterrupts();
#if defined (SPCR) && defined (SPSR)
	// Save SPI settings
	mSPCR = SPCR;
	mSPSR = SPSR;
#endif
	SPI.setDataMode(SPI_MODE0);
	SPI.setBitOrder(MSBFIRST);
	SPI.setClockDivider(SPI_CLOCK_DIV);
	digitalWrite(mCSPin, LOW);
}

/********************************* Unselect ***********************************/
void SPIMem::Unselect(void)
{
	digitalWrite(mCSPin, HIGH);
#if defined (SPCR) && defined (SPSR)
	// Restore SPI settings
	SPCR = mSPCR;
	SPSR = mSPSR;
#endif
	interrupts();
}

/******************************* LoadJEDECInfo ********************************/
void SPIMem::LoadJEDECInfo(void)
{
	SendCmd(eReadJEDECIDCmd);
	mManufacturerID = SPI.transfer(0);
	mMemoryType = SPI.transfer(0);
	mCapacity = 1L<<(SPI.transfer(0));
	Unselect();
}

/********************************** SendCmd ***********************************/
void SPIMem::SendCmd(
	uint8_t	inCmd)
{
	Select();
	SPI.transfer(inCmd);
}

/******************************* WaitTillReady ********************************/
bool SPIMem::WaitTillReady(
	uint32_t	inTimeout)
{
	uint8_t  status;
	uint32_t timeout = millis() + inTimeout;

	do {
		SendCmd(eReadStat1Cmd);
		status = SPI.transfer(0);
		Unselect();
		if (millis() < timeout)
		{
			continue;
		}
		return(false);
	} while(status & eChipBusyBit);

	return(true);
}

/********************************* WritePage **********************************/
bool SPIMem::WritePage(
	uint32_t		inAddr,
	const uint8_t*	inData)
{
	bool	success = inAddr < mCapacity && WaitTillReady() && WriteEnable();
	
	if (success)
	{
		SendCmd(ePageProgCmd);
		SPI.transfer(inAddr >> 16);
		SPI.transfer(inAddr >>  8);
		/*
		*	If an entire 256 byte page is to be programmed, the last address
		*	byte (the 8 least significant address bits) should be set to 0.
		*/
		SPI.transfer(0);
		for (int i=0; i<256; i++)
		{
			SPI.transfer(inData[i]);
		}
		Unselect();
		success = WaitTillReady();
		WriteDisable();
	}
	return(success);
}

/*********************************** Read *************************************/
bool SPIMem::Read(
	uint32_t	inAddr,
	uint32_t	inDataLen,
	uint8_t*	outData)
{
	bool	success = inAddr+inDataLen <= mCapacity && WaitTillReady();
	if (success)
	{
		SendCmd(eReadDataCmd);
		SPI.transfer(inAddr >> 16);
		SPI.transfer(inAddr >>  8);
		SPI.transfer(inAddr);
		for (uint32_t i = 0; i < inDataLen; i++)
		{
			outData[i] = SPI.transfer(0);
		}
		Unselect();
	}
	return(success);
}

/******************************** WriteEnable *********************************/
bool SPIMem::WriteEnable(void)
{
	SendCmd(eWriteEnableCmd);
	Unselect();
	SendCmd(eReadStat1Cmd);
	uint8_t status = SPI.transfer(0);
	Unselect();
	return((status & eWriteEnabledBit) != 0);
}

/******************************** WriteDisable ********************************/
void SPIMem::WriteDisable(void)
{
	SendCmd(eWriteDisableCmd);
	Unselect();
}

/********************************* EraseSector ********************************/
bool SPIMem::EraseSector(
	uint32_t	inAddr)
{

	bool success = WaitTillReady() && WriteEnable();
	if (success)
	{
		SendCmd(eEraseSectorCmd);
		SPI.transfer(inAddr >> 16);
		SPI.transfer(inAddr >>  8);
		SPI.transfer(inAddr);
		Unselect();
		success = WaitTillReady(1000);	// Max time to erase a sector is 400ms
		WriteDisable();
	}
	return success;
}

/******************************** Erase32KBlock ********************************/
bool SPIMem::Erase32KBlock(
	uint32_t	inAddr)
{

	bool success = WaitTillReady() && WriteEnable();
	if (success)
	{
		SendCmd(eErase32KBlkCmd);
		SPI.transfer(inAddr >> 16);
		SPI.transfer(inAddr >>  8);
		SPI.transfer(inAddr);
		Unselect();
		success = WaitTillReady(2000);	// Max time to erase a 32K block is 1.6s
		WriteDisable();
	}
	return success;
}

/******************************* Erase64KBlock ********************************/
bool SPIMem::Erase64KBlock(
	uint32_t	inAddr)
{

	bool success = WaitTillReady() && WriteEnable();
	if (success)
	{
		SendCmd(eErase64KBlkCmd);
		SPI.transfer(inAddr >> 16);
		SPI.transfer(inAddr >>  8);
		SPI.transfer(inAddr);
		Unselect();
		success = WaitTillReady(2500);	// Max time to erase a 64K block is 2s
		WriteDisable();
	}
	return success;
}

/********************************* ChipErase **********************************/
bool SPIMem::ChipErase(void)
{
	bool success = WaitTillReady() && WriteEnable();
	if (success)
	{
		SendCmd(eChipEraseCmd);
		Unselect();
		// From AC Electrical Characteristics:
		//	Chip Erase Time 08 = 6 seconds
		//	Chip Erase Time 32 = 15 seconds
		//	Chip Erase Time 64 = 100 seconds
		success = WaitTillReady(150 * 1000UL);	// Max time to erase a 8MB chip (W25Q64)
		WriteDisable();
	}
	return success;
}
