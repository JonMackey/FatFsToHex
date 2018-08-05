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
//  FatFsSerialViewController.m
//  FatFsToHex
//
//  Created by Jon Mackey on 1/3/18.
//  Copyright © 2018 Jon Mackey. All rights reserved.
//

#import "FatFsSerialViewController.h"
#import "SendHexIOSession.h"

@interface FatFsSerialViewController ()

@end

@implementation FatFsSerialViewController

/********************************* dealloc ************************************/
- (void)dealloc
{
	[self unbind:@"eraseBeforeWrite"];
}

/****************************** viewDidLoad ***********************************/
- (void)viewDidLoad
{
    [super viewDidLoad];
	[self bind:@"eraseBeforeWrite" toObject:[NSUserDefaults standardUserDefaults] withKeyPath:@"eraseBeforeWrite" options:NULL];
	self.progressMax = 1;
	self.progressTextTemplate = @"%d of %d"; //[NSString stringWithString:self.progressText];
	self.progressText = @""; // [NSString string];
}

/******************************* sendHexFile **********************************/
- (void)sendHexFile:(NSURL*)inDocURL
{
	if ([self portIsOpen:YES])
	{
		NSError* error;
		NSData *dataToSend = [NSData dataWithContentsOfURL:inDocURL options:0 error:&error];
		self.serialPortSession = [[SendHexIOSession alloc] initWithData:dataToSend port:self.serialPort];
		((SendHexIOSession*)self.serialPortSession).eraseBeforeWrite = self.eraseBeforeWrite;
		[self.serialPortSession begin];
	}
}

/******************************* fatFsCreated *********************************/
- (void)fatFsCreated:(uint32_t)inBlockSize blockCount:(uint32_t)inBlockCount
{
	self.progressText = [NSString stringWithFormat:self.progressTextTemplate, 0, inBlockCount];
	self.blockSize = inBlockSize;	// For progress text
	self.blockCount = inBlockCount;	// For progress text
	self.blocksSent = 0;
	self.progressMax = inBlockCount * inBlockSize;
	self.progressValue = 0;
}

/****************************** updateProgress ********************************/
-(void)updateProgress
{
	// blocksSent is nth block, 1 to N, with 0 meaning nothing sent
	uint32_t	blocksSent = (((SendHexIOSession*)self.serialPortSession).currentAddress / self.blockSize) +1;
	if (blocksSent != self.blocksSent)
	{
		self.blocksSent = blocksSent;
		self.progressText = [NSString stringWithFormat:self.progressTextTemplate, blocksSent, self.blockCount];
	}
	self.progressValue = ((SendHexIOSession*)self.serialPortSession).currentAddress;
}

/****************************** sessionIsDone *********************************/
-(BOOL)sessionIsDone
{
	[self updateProgress];
	BOOL wasStopped = [self.serialPortSession wasStopped];
	BOOL isDone = [super sessionIsDone];
	if (isDone && wasStopped)
	{
		[self appendNewLine];
		[self postWarningString:@"Send FatFs session stopped by user"];
		/*
		*	Tell the HexLoader to stop, assuming it's not hung.
		*/
		uint8_t	stopChar = 'S';
		NSData*	stopData = [NSData dataWithBytes:&stopChar length:1];
		[self.serialPort sendData:stopData];
	}
	return(isDone);
}

@end
