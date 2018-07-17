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


/******************************* sendHexFile **********************************/
- (void)sendHexFile:(NSURL*)inDocURL
{
	if ([self portIsOpen:YES])
	{
		NSError* error;
		NSData *dataToSend = [NSData dataWithContentsOfURL:inDocURL options:0 error:&error];
		self.serialPortSession = [[SendHexIOSession alloc] initWithData:dataToSend port:self.serialPort];
		[self.serialPortSession begin];
	}
}
@end
