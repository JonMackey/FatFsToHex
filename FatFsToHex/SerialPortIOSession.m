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
//  SerialPortIOSession.m
//  FatFsToHex
//
//  Created by Jon Mackey on 1/7/18.
//  Copyright © 2018 Jon Mackey. All rights reserved.
//

#import "SerialPortIOSession.h"

@implementation SerialPortIOSession
- (instancetype)initWithData:(NSData *)inData port:(ORSSerialPort *)inPort
{
	self = [super init];
	if (self)
	{
		_data = inData;
		_serialPort = inPort;
	}
	return(self);
}

- (void)dealloc
{
    fprintf(stderr, "dealloc SerialPortIOSession\n");
}

/********************************** begin *************************************/
- (void)begin
{
	_done = NO;
	_stopped = NO;
}

/********************************** begin *************************************/
- (NSData*)didReceiveData:(NSData *)inData
{
	return(inData);
}

/********************************* isDone *************************************/
- (BOOL)isDone
{
	return(_done);
}

/********************************** stop **************************************/
- (void)stop
{
	_done = YES;
	_stopped = YES;
}

/******************************* wasStopped ***********************************/
- (BOOL)wasStopped
{
	return(_stopped);
}

@end
