/*
*	HexLoader.ino
*	Copyright (c) 2018 Jonathan Mackey
*
*	Loads data onto NOR Flash chips.
*	Receives data serially in Intel Hex format.
*
*	Example session:
*	- wait for serial
*	- receive an H for hex download, start waiting for lines
*	- respond with *
*	- receive a line/process a line
*	- respond with *
*	- loop till end hex command hit.
*
*	At any time if anything other than a line start is received when expected 
*	or an invalid character, respond with a ? follwed by an error message.
*
*	Line processing:
*	- On first line for a new block (256 or 512 bytes), clear the block by
*	filling it with nulls.
*	- Once a block is full OR the address changes to a new block, then write the
*	current block to the device.
*
*/
#include <SPI.h>

const uint8_t SdChipSelect = 10;

// Can also be used to load data onto an SD card treated as a block device.
//#define USE_SD	1
#ifdef USE_SD
#include <SdFat.h>

Sd2Card card;
SdVolume vol;
#define BAUD_RATE	9600
#else
#include "SPIMem.h"
SPIMem flash(SdChipSelect);
#define BAUD_RATE	9600	// At F_CPU == 8MHz you get Serial buffer overruns
							// at speeds > 9600 (and even when you don't there
							// is no great speed improvement.)
#endif


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
#ifndef USE_SD
static uint8_t	sBuffer[kBlockSize];
#endif
static bool		sVerifyAfterWrite = false;

#ifndef USE_SD
void DumpJDECInfo(void)
{
	uint32_t capacity = flash.GetCapacity();
	if (capacity > 0xFF)
	{
		if (flash.GetManufacturerID() == 0xEF)
		{
			Serial.print("Winbond");
		} else
		{
			Serial.print("Unknown manufacturer = 0x");
			Serial.print(flash.GetManufacturerID(), HEX);
		}
		if (flash.GetMemoryType() == 0x40)
		{
			Serial.print(", NOR Flash");
		} else
		{
			Serial.print(", unknown type = 0x");
			Serial.print(flash.GetMemoryType(), HEX);
		}
		Serial.print(", capacity = ");
		Serial.print(capacity/0x100000);
		Serial.println("MB");
	} else
	{
		Serial.println("?failed to read the JEDEC ID");
	}
}
#endif

/********************************** setup *************************************/
void setup(void)
{
	Serial.begin(BAUD_RATE);
#ifdef USE_SD
	if (card.init(SPI_HALF_SPEED, SdChipSelect) &&
		vol.init(&card))
	{
		Serial.println("SD card initialized.");
	} else
	{
		Serial.println("SD card not initialized.");
	}
#else
	flash.begin();
	DumpJDECInfo();
#endif
}

/*********************************** loop *************************************/
void loop()
{
	while (!Serial.available());
	switch (Serial.read())
	{
		case 'H':
			HexDownload();
			break;
	#ifndef USE_SD
		case 'E':
			FullErase();
			break;
		case 'V':
			sVerifyAfterWrite = true;
			Serial.println("Verify after write ON");
			break;
		case 'v':
			sVerifyAfterWrite = false;
			Serial.println("Verify after write OFF");
			break;
		case 'j':
			flash.LoadJEDECInfo();
			DumpJDECInfo();
			break;
	#endif
	}
}

/******************************** FullErase ***********************************/
void FullErase(void)
{
#ifndef USE_SD
	Serial.println(flash.ChipErase() ? "*" : "?Erase chip failed");
#endif
}

/******************************* ClearBuffer **********************************/
uint8_t* ClearBuffer(void)
{
	uint8_t*	buffer;
#ifdef USE_SD
	cache_t*	cache = vol.cacheClear();
	buffer = cache->data;
#else
	buffer = sBuffer;
#endif
	uint8_t*	bufferPtr = buffer;
	uint8_t*	endBufferPtr = &bufferPtr[kBlockSize];
	while (bufferPtr < endBufferPtr)
	{
		*(bufferPtr++) = 0;
	}
	return(buffer);
}

/******************************* WriteBlock ***********************************/
bool WriteBlock(
	uint8_t*	inData,
	uint32_t	inBlockIndex)
{
	bool success = true;
	if (inData)
	{
	#ifdef USE_SD
		success = card.writeBlock(inBlockIndex, inData);
	#else
		uint32_t	address = inBlockIndex*kBlockSize;
		success = flash.WritePage(address, inData) &&
					flash.WritePage(address+256, &inData[256]);
		if (sVerifyAfterWrite)
		{
			uint8_t	verifyBuff[256];
			#if 1
			success = flash.Read(address, 256, verifyBuff) &&
				memcmp(inData, verifyBuff, 256) == 0 &&
				flash.Read(address+256, 256, verifyBuff) &&
				memcmp(&inData[256], verifyBuff, 256) == 0;
			#else
			success = flash.Read(address, 256, verifyBuff);
			if (success)
			{
				success = memcmp(inData, verifyBuff, 256) == 0;
				if (success)
				{
					success = flash.Read(address+256, 256, verifyBuff);
					if (success)
					{
						success = memcmp(&inData[256], verifyBuff, 256) == 0;
						if (!success)
						{
							Serial.print("?Failed compare data[256]\n");
							/*Serial.write((const char*)verifyBuff, 256);
							Serial.print("\n\n");
							Serial.write((const char*)&inData[256], 256);
							Serial.print("\n\n");*/
						}
					} else
					{
						Serial.print("?Failed reading data[256]\n");
					}
				} else
				{
					Serial.print("?Failed compare data[0]\n");
					/*Serial.write((const char*)verifyBuff, 256);
					Serial.print("\n\n");
					Serial.write((const char*)inData, 256);
					Serial.print("\n\n");*/
				}
			} else
			{
				Serial.print("?Failed reading data[0]\n");
			}
			#endif
		}
	#endif
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
	while (!Serial.available());
	return(Serial.read());
}

/******************************* HexDownload **********************************/
void HexDownload(void)
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
		thisChar = GetChar();
		if (thisChar != ':')
		{
			switch (thisChar)
			{
				case '\n':
				case '\r':
				case ' ':
				case '\t':
				continue;
			}
			Serial.print("?Invalid Character\n");
			status = eError;
			break;
		} else
		{
			while(status == eProcessing)
			{
				thisChar = GetChar();
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
										Serial.print("?Failed writing data\n");
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
									Serial.print("?byteCount for RecordTypeExLinAddr not 2\n");
									status = eError;
								}
							} else if (recordType == eRecordTypeEOF)
							{
								state++;	// Skip eGetData
							} else
							{
								Serial.print("?Unsupported type\n");
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
								Serial.write('*');
								break;
							}
							Serial.print("?Checksum error\n");
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
		Serial.print("* success!\n");
	}
	// Clean out the rest of the serial buffer, if any
	delay(1000);
	while (Serial.available())
	{
		Serial.read();
	}
}