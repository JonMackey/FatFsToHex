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
//
//  SendHexIOSession.m
//  FatFsToHex
//
//  Created by Jon Mackey on 1/7/18.
//  Copyright © 2018 Jon Mackey. All rights reserved.
//

#import "SendHexIOSession.h"

@implementation SendHexIOSession

/****************************** initWithData **********************************/
- (instancetype)initWithData:(NSData *)inData port:(ORSSerialPort *)inPort
{
	self = [super initWithData:inData port:inPort];
	if (self)
	{
		_offset = 0;
	}
	return(self);
}

/********************************** begin *************************************/
- (void)begin
{
	[super begin];
	self.currentAddress = 0;
	uint8_t command = self.eraseBeforeWrite ? 'H':'h';
	[self.serialPort sendData:[NSData dataWithBytes:&command length:1]];
}

/***************************** didReceiveData *********************************/
- (NSData*)didReceiveData:(NSData *)inData
{
	if (!self.done)
	{
		//fprintf(stderr, "%.*s\n", (int)inData.length, inData.bytes);
		int	status = 0;
		if (inData.length >= 1)
		{
			const uint8_t*	recievedData = inData.bytes;
			NSUInteger	length = inData.length;
			
			for (NSUInteger i = 0; i < length && status >= 0; i++)
			{
				switch (recievedData[i])
				{
					case '*':	// Process next line request
						status = 1;
						continue;
					case '=':	// Ignore erase block successful char
					case '+':	// Ignore debug char
					case '-':	// Ignore debug char
						continue;
					default:	// Some error occured or garbage char returned
						status = -1;
						self.done = YES;
						break;
				}
			}
		}
		if (status == 1)
		{
			if (inData.length == 1)
			{
				inData = [NSData data];	// Don't need to see the '*'
			}
			// Find the end of the current line.
			const uint8_t* bytesStart = (const uint8_t*)self.data.bytes + _offset;
			const uint8_t* bytes = bytesStart;
			const uint8_t* bytesEnd =  (const uint8_t*)self.data.bytes + self.data.length;
			if (bytes < bytesEnd)
			{
				for (; bytes < bytesEnd; bytes++)
				{
					if (*bytes != '\n')
					{
						continue;
					}
					break;
				}
				NSRange	lineRange = NSMakeRange(_offset, (bytes - bytesStart) +1);
				NSData*	lineData = [self.data subdataWithRange:lineRange];
				//fprintf(stderr, "Sent %d bytes at offset %d\n%.*s\n", (int)lineData.length, (int)_offset, (int)lineData.length, lineData.bytes);
				_offset += lineRange.length;
				//fprintf(stderr, "lineRange.length = %d\n", (int)lineRange.length);
				[self processHexLine:lineData];
				[self.serialPort sendData:lineData];
			} else
			{
				//fprintf(stderr, "done - bytes >= bytesEnd\n");
				self.done = YES;
			}
		}
	}
	return(inData);
}

/***************************** processHexLine *********************************/
/*
*	Used to update a progress bar by extracting the current address of the line
*	being sent.
*/
- (void)processHexLine:(NSData *)inLineData
{
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

	const uint8_t* bytePtr = (const uint8_t*)inLineData.bytes;
	const uint8_t* bytesEnd =  (const uint8_t*)inLineData.bytes + inLineData.length;
	uint8_t	    thisChar;
	uint8_t		thisByte = 0;
	uint8_t		state = 0;
	uint8_t		status = eProcessing;
	uint32_t	byteCount = 0;
	uint32_t	addressOffset = 0;
	uint32_t	baseAddress = self.currentAddress & 0xFFFF0000;
	uint8_t		recordType = eRecordTypeData;
	uint8_t		checksum = 0;
	uint8_t		hiLow = 1;
	uint32_t	dataIndex = 0;
	
	if (bytePtr < bytesEnd)
	{
		thisChar = *(bytePtr++);
		if (thisChar != ':')
		{
			status = eError;
		} else
		{
			while(status == eProcessing &&
					bytePtr < bytesEnd)
			{
				thisChar = *(bytePtr++);
				hiLow++;	// nibble toggle
				/*
				*	If this is the high nibble THEN
				*	process the complete byte
				*/
				if (hiLow & 1)
				{
					thisByte = (thisByte << 4) + (thisChar <= '9' ? (thisChar - '0') : (thisChar - ('A' - 10)));
					checksum += thisByte;
					switch (state)
					{
						case eGetByteCount:
						{
							byteCount = thisByte;
							addressOffset = 0;
							state++;
							continue;
						}
						case eGetAddressH:
						case eGetAddressL:
							addressOffset = (addressOffset << 8) + thisByte;
							state++;
							continue;
						case eGetRecordType:
							recordType = thisByte;
							state++;
							dataIndex = 0;
							if (recordType == eRecordTypeData)
							{
								continue;
							} else if (recordType == eRecordTypeExLinAddr)
							{
								addressOffset = 0;	// The data contains the address
								if (byteCount != 2)
								{
									// byteCount for RecordTypeExLinAddr not 2
									status = eError;
								}
							} else if (recordType == eRecordTypeEOF)
							{
								state++;	// Skip eGetData
							} else
							{
								// Unsupported type
								status = eError;
							}
							continue;
						case eGetData:
							if (recordType == eRecordTypeExLinAddr)
							{
								addressOffset = (addressOffset << 8) + thisByte;
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
									baseAddress = addressOffset << 16;
								}
								status = eDone;
								break;
							}
							// Checksum error
							status = eError;
							break;
					}
					break;
				} else
				{
					thisByte = thisChar <= '9' ? (thisChar - '0') : (thisChar - ('A' - 10));
				}
			}
		}
	}
	if (status == eDone &&
		recordType != eRecordTypeEOF)
	{
		//fprintf(stderr, "0x%X 0x%X\n", baseAddress, addressOffset);
		self.currentAddress = baseAddress + addressOffset;
	}
}

@end
