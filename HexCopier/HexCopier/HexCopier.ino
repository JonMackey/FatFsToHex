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
*	HexCopier.ino
*	Copyright (c) 2018 Jonathan Mackey
*
*	Copies data onto a NOR Flash chip from the hex file "FLASH.HEX" on a SD card.
*	The copy starts when a 'C' is received on the serial port.
*
*	Example session:
*	- wait for serial
*	- wait for SD card
*	- receive 'C' to start copy of SD file flash.hex to NOR Flash chip
*	- returns "Hex file opened, size = 6912192"
*			  "Copy starting..."
*	- process the hex file. one '=' sent for each 64K cleared
*	- returns "Success!" when done otherwise an error message is sent.
*
*	Line processing:
*	- On first line for a new block (256 or 512 bytes), clear the block by
*	filling it with nulls.
*	- Once a block is full OR the address changes to a new block, then write the
*	current block to the device.
*
*/
#include <SPI.h>

#ifdef __AVR_ATmega644P__
const uint8_t SdChipSelect = 3;
#else
// ATmega328p or pb
const uint8_t SdChipSelect = 9;
#endif
const uint8_t NORFlashChipSelect = SS;

#include <SdFat.h>
#include "SPIMem.h"

Sd2Card card;
SdVolume vol;
SPIMem norFlash(NORFlashChipSelect);
#define BAUD_RATE	19200

enum EIntelHexLineState
{
	// Start code   Byte count   Address H/L   Record type   Data   Checksum
	eGetByteCount,
	eGetAddressH,
	eGetAddressL,
	eGetRecordType,
	eGetData,
	eGetChecksum
};

enum EIntelHexRecordType
{
	eRecordTypeData,		// 0
	eRecordTypeEOF,			// 1
	eRecordTypeExSegAddr,	// 2
	eRecordTypeStSegAddr,	// 3
	eRecordTypeExLinAddr,	// 4
	eRecordTypeStLinAddr	// 5
};

enum EIntelHexStatus
{
	eProcessing,
	eDone,
	eError
};

const uint32_t	kBlockSize = 512;
static uint8_t	sBuffer[kBlockSize];
static bool		sVerifyAfterWrite = true;
static bool		sEraseBeforeWrite;
static uint32_t	sCurrent64KBlk;
#ifdef __AVR_ATmega644P__
const uint32_t	kHexFileBufferSize = 512;
#else
const uint32_t	kHexFileBufferSize = 128;
#endif
static uint8_t	sHexFileBuffer[kHexFileBufferSize];
static uint8_t*	sHexFileBufferPtr;
static uint8_t*	sHexFileEOBPtr;

#define MAX_HEX_LINE_LEN	45
static uint8_t	sLineBuffer[MAX_HEX_LINE_LEN];
static uint8_t*	sLineBufferPtr;
static uint8_t*	sEndOfLineBufferPtr;
static SdFile	hexFile;

void HexCopy(void);
void FullErase(void);

/******************************* DumpJDECInfo *********************************/
void DumpJDECInfo(void)
{
	uint32_t capacity = norFlash.GetCapacity();
	if (capacity > 0xFF)
	{
		if (norFlash.GetManufacturerID() == 0xEF)
		{
			Serial.print(F("Winbond"));
		} else
		{
			Serial.print(F("Unknown manufacturer = 0x"));
			Serial.print(norFlash.GetManufacturerID(), HEX);
		}
		if (norFlash.GetMemoryType() == 0x40)
		{
			Serial.print(F(", NOR Flash"));
		} else
		{
			Serial.print(F(", unknown type = 0x"));
			Serial.print(norFlash.GetMemoryType(), HEX);
		}
		Serial.print(F(", capacity = "));
		Serial.print(capacity/0x100000);
		Serial.println(F("MB"));
	} else
	{
		Serial.println(F("?failed to read the JEDEC ID"));
	}
}

/********************************** setup *************************************/
void setup(void)
{
	Serial.begin(BAUD_RATE);
	if (card.init(SPI_FULL_SPEED, SdChipSelect) &&
		vol.init(&card))
	{
		Serial.println(F("SD card initialized."));
	} else
	{
		Serial.println(F("SD card not initialized."));
	}
	norFlash.begin();
	DumpJDECInfo();
}

/*********************************** loop *************************************/
void loop()
{
	while (!Serial.available());
	switch (Serial.read())
	{
		case 'C':	// Initiate Copy
		{
			sEraseBeforeWrite = true;
			sCurrent64KBlk = 0xF0000000;
			bool	success = false;
			{
				SdFile	root;
				if (root.openRoot(&vol))
				{
					success = hexFile.open(&root, "/FLASH.HEX", O_READ);
					root.close();
				} else
				{
					Serial.println(F("Unable to open the root folder."));
				}
			
			}
			if (success)
			{
				Serial.print(F("Hex file opened, size = "));
				Serial.println(hexFile.fileSize());
				Serial.println(F("Copy starting..."));
				sHexFileEOBPtr = sHexFileBufferPtr = sHexFileBuffer;
				HexCopy();
				hexFile.close();
			} else
			{
				Serial.println(F("FLASH.HEX open failed: file not found or hw error."));
			}
			break;
		}
		case 'E':
			FullErase();
			break;
		case 'V':
			sVerifyAfterWrite = true;
			Serial.println(F("Verify after write ON"));
			break;
		case 'v':
			sVerifyAfterWrite = false;
			Serial.println(F("Verify after write OFF"));
			break;
		case 'j':
			norFlash.LoadJEDECInfo();
			DumpJDECInfo();
			break;
	}
}

/******************************** FullErase ***********************************/
void FullErase(void)
{
	Serial.println(norFlash.ChipErase() ? F("*") : F("?Erase chip failed"));
}

/******************************* ClearBuffer **********************************/
uint8_t* ClearBuffer(void)
{
	uint8_t*	bufferPtr = sBuffer;
	uint8_t*	endBufferPtr = &bufferPtr[kBlockSize];
	while (bufferPtr < endBufferPtr)
	{
		*(bufferPtr++) = 0;
	}
	return(sBuffer);
}

/******************************* WriteBlock ***********************************/
bool WriteBlock(
	uint8_t*	inData,
	uint32_t	inBlockIndex)
{
	bool success = true;
	if (inData)
	{
		uint32_t	address = inBlockIndex*kBlockSize;
		/*
		*	If erase before write is enabled AND
		*	the address just stepped over a 64KB block boundary THEN
		*	Erase the block. (this assumes all addresses are increasing)
		*/
		//Serial.write('+');
		if (sEraseBeforeWrite &&
			(address/0x10000) != sCurrent64KBlk)
		{
			sCurrent64KBlk = address/0x10000;
			success = norFlash.Erase64KBlock(address);
			if (success)
			{
				Serial.write('=');
			}
		}
		//Serial.write('-');
		if (success)
		{
			success = norFlash.WritePage(address, inData) &&
						norFlash.WritePage(address+256, &inData[256]);
			if (sVerifyAfterWrite)
			{
				uint8_t	verifyBuff[256];
				#if 0
				success = norFlash.Read(address, 256, verifyBuff) &&
					memcmp(inData, verifyBuff, 256) == 0 &&
					norFlash.Read(address+256, 256, verifyBuff) &&
					memcmp(&inData[256], verifyBuff, 256) == 0;
				#else
				success = norFlash.Read(address, 256, verifyBuff);
				if (success)
				{
					success = memcmp(inData, verifyBuff, 256) == 0;
					if (success)
					{
						success = norFlash.Read(address+256, 256, verifyBuff);
						if (success)
						{
							success = memcmp(&inData[256], verifyBuff, 256) == 0;
							if (!success)
							{
								Serial.print(F("?Failed compare data[256]\n"));
								/*Serial.write((const char*)verifyBuff, 256);
								Serial.print("\n\n");
								Serial.write((const char*)&inData[256], 256);
								Serial.print("\n\n");*/
							}
						} else
						{
							Serial.print(F("?Failed reading data[256]\n"));
						}
					} else
					{
						Serial.print(F("?Failed compare data[0]\n"));
						/*Serial.write((const char*)verifyBuff, 256);
						Serial.print("\n\n");
						Serial.write((const char*)inData, 256);
						Serial.print("\n\n");*/
					}
				} else
				{
					Serial.print(F("?Failed reading data[0]\n"));
				}
				#endif
			}
		} else
		{
			Serial.print(F("?Block erase failed\n"));
		}		
	}

	return(success);
}

/****************************** HexAsciiToBin *********************************/
// Assumes 0-9, A-Z (uppercase)
uint8_t	HexAsciiToBin(
	uint8_t	inByte)
{
	 return (inByte <= '9' ? (inByte - '0') : (inByte - ('A' - 10)));
}

/********************************* GetChar ************************************/
uint8_t GetChar(void)
{
	if (sHexFileBufferPtr >= sHexFileEOBPtr)
	{
		int bytesRead = hexFile.read(sHexFileBuffer, kHexFileBufferSize);
		if (bytesRead)
		{
			sHexFileEOBPtr = &sHexFileBuffer[bytesRead];
			sHexFileBufferPtr = sHexFileBuffer;
		} else
		{
			return('O');	// Overrun, unexpected end of file
		}
	}
	return(*(sHexFileBufferPtr++));
}

/**************************** GetNexHextLineChar ******************************/
uint8_t GetNexHextLineChar(void)
{
	uint8_t	thisChar = sEndOfLineBufferPtr > sLineBufferPtr ? *(sLineBufferPtr++) : 'O';
	return(thisChar);
}

/******************************* LoadHexLine **********************************/
bool LoadHexLine(void)
{
	uint8_t	thisChar = GetChar();
	uint8_t*	bufferPtr = sLineBuffer;
	uint8_t*	endBufferPtr = &sLineBuffer[MAX_HEX_LINE_LEN];
	sLineBufferPtr = sLineBuffer;
	while (thisChar != ':')
	{
		switch (thisChar)
		{
			case '\n':
			case '\r':
			case ' ':
			case '\t':
				thisChar = GetChar();
			continue;
		}
		sLineBuffer[0] = thisChar;
		sEndOfLineBufferPtr = &sLineBuffer[1];
		return(false);	// Start code not found
	}
	
	do
	{
		*(bufferPtr++) = thisChar;
		thisChar = GetChar();
		if (thisChar != '\n')
		{
			if (thisChar != 'O')
			{
				continue;
			}
			sLineBuffer[0] = 'O';
		}
		break;
	} while(bufferPtr < endBufferPtr);
	sEndOfLineBufferPtr = bufferPtr;
	/*
	*	See if the user wants to stop...
	*/
	if (Serial.available() &&
		Serial.read() == 'S')
	{
		sLineBuffer[0] = 'S';
	}
	return(thisChar == '\n');
}

/********************************** HexCopy ***********************************/
void HexCopy(void)
{
	uint8_t	    thisChar;
	uint8_t		thisByte = 0;
	uint8_t		state = 0;
	uint8_t		status = eProcessing;
	uint32_t	byteCount = 0;
	uint32_t	address = 0;
	uint32_t	currentBlockIndex = 0xFFFFFFFF;
	uint32_t	baseAddress = 0;
	uint8_t		recordType = eRecordTypeData;
	uint8_t		checksum = 0;
	uint8_t		hiLow = 1;
	uint8_t*	data = NULL;
	uint8_t*	dataPtr = NULL;
	uint32_t	dataIndex = 0;
	
	Serial.write('*');	// Tell the host the mode change was successful
	while(status == eProcessing)
	{
		LoadHexLine();
		thisChar = GetNexHextLineChar();
		if (thisChar != ':')
		{
			/*
			*	If this isn't the character 'S' for stop THEN
			*	report the invalid character.
			*/
			switch (thisChar)
			{
				case 'S':
					Serial.print(F("?Stopped by user\n"));
					break;
				case 'O':
					Serial.print(F("?Unexpected end of hex file\n"));
					break;
				default:
					Serial.print(F("?No Start Code\n"));
					break;
			}
			status = eError;
			break;
		} else
		{
			while(status == eProcessing)
			{
				thisChar = GetNexHextLineChar();
				hiLow++;	// nibble toggle
				/*
				*	If this is the high nibble THEN
				*	process the complete byte
				*/
				if (hiLow & 1)
				{
					thisByte = (thisByte << 4) + HexAsciiToBin(thisChar);
					checksum += thisByte;
					switch (state)
					{
						case eGetByteCount:
						{
							byteCount = thisByte;
							address = 0;
							state++;
							continue;
						}
						case eGetAddressH:
						case eGetAddressL:
							address = (address << 8) + thisByte;
							state++;
							continue;
						case eGetRecordType:
							recordType = thisByte;
							state++;
							dataIndex = 0;
							if (recordType == eRecordTypeData)
							{
								uint32_t newBlockIndex = (baseAddress + address) / kBlockSize;
								/*
								*	If the block changed THEN
								*	write the current block (if any) and
								*	initialize the new block data buffer.
								*/
								if (currentBlockIndex != newBlockIndex)
								{
									if (WriteBlock(data, currentBlockIndex))
									{
										currentBlockIndex = newBlockIndex;
										data = ClearBuffer();
									} else
									{
										Serial.print(F("?Failed writing data\n"));
										status = eError;
										break;
									}
								}
								dataPtr = &data[address % kBlockSize];
							} else if (recordType == eRecordTypeExLinAddr)
							{
								address = 0;	// The data contains the address
								if (byteCount != 2)
								{
									Serial.print(F("?byteCount for RecordTypeExLinAddr not 2\n"));
									status = eError;
								}
							} else if (recordType == eRecordTypeEOF)
							{
								state++;	// Skip eGetData
							} else
							{
								Serial.print(F("?Unsupported type\n"));
								status = eError;
							}
							continue;
						case eGetData:
							if (recordType == eRecordTypeData)
							{
								dataPtr[dataIndex] = thisByte;
							} else
							{
								address = (address << 8) + thisByte;
							}
							dataIndex++;
							if (dataIndex < byteCount)
							{
								continue;
							}
							state++;
							continue;
						case eGetChecksum:
							if (checksum == 0)
							{
								state = 0;
								if (recordType == eRecordTypeExLinAddr)
								{
									baseAddress = address << 16;
								} else if (recordType == eRecordTypeEOF)
								{
									status = eDone;
								}
								//Serial.write('*');
								break;
							}
							Serial.print(F("?Checksum error\n"));
							status = eError;
							break;
					}
					break;
				} else
				{
					thisByte = HexAsciiToBin(thisChar);
				}
			}
		}
	}
	if (status == eDone)
	{
		WriteBlock(data, currentBlockIndex);
		Serial.print(F("Success!\n"));
	}
	// Clean out the rest of the serial buffer, if any
	delay(1000);
	while (Serial.available())
	{
		Serial.read();
	}
}
