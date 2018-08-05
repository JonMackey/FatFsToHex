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
//  FatFsSerialViewController.h
//  FatFsToHex
//
//  Created by Jon Mackey on 1/2/18.
//  Copyright © 2018 Jon Mackey. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "SerialViewController.h"

@interface FatFsSerialViewController : SerialViewController
@property (nonatomic, strong) NSString* progressTextTemplate;
@property (nonatomic, strong) NSString* progressText;
@property (nonatomic) double progressMax;
@property (nonatomic) double progressValue;
@property (nonatomic) uint32_t blockCount;
@property (nonatomic) uint32_t blockSize;
@property (nonatomic) uint32_t blocksSent;


- (void)sendHexFile:(NSURL*)inURL;
- (void)fatFsCreated:(uint32_t)inBlockSize blockCount:(uint32_t)inBlockCount;

@property (nonatomic) BOOL eraseBeforeWrite;

@end
