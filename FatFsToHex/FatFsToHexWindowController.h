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
//  FatFSToHexWindowController.h
//  FatFsToHex
//
//  Created by Jon Mackey on 1/1/18.
//  Copyright © 2018 Jon Mackey. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "FatFsSerialViewController.h"
#import "FatFsTableViewController.h"

@interface FatFsToHexWindowController : NSWindowController
{
	IBOutlet NSView *rootView;
	IBOutlet NSView *serialView;
}
@property (nonatomic, strong) NSData *savedBM;
@property (nonatomic, strong) NSURL *archiveURL;
@property (nonatomic, strong) FatFsSerialViewController *fatFsSerialViewController;
@property (nonatomic, strong) FatFsTableViewController *fatFsTableViewController;
@property (nonatomic, strong) NSViewController *formatViewController;
@property (nonatomic, weak) NSSavePanel *savePanel; // valid only while panel is open

- (void)doOpen:(NSURL*)inDocURL;
@end
