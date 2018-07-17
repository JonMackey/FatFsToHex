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
	uint8_t command = 'H';
	[self.serialPort sendData:[NSData dataWithBytes:&command length:1]];
}

/***************************** didReceiveData *********************************/
- (NSData*)didReceiveData:(NSData *)inData
{
	if (inData.length >= 1 &&
		*(const uint8_t*)inData.bytes == '*')
	{
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
			[self.serialPort sendData:lineData];
		} else
		{
			//fprintf(stderr, "done - bytes >= bytesEnd\n");
			_done = YES;
		}
	} else
	{
		// Some error occured
		//fprintf(stderr, "done - Some error occured\n");
		_done = YES;
	}
	return(inData);
}

/********************************* isDone *************************************/
- (BOOL)isDone
{
	return(_done);
}

@end
