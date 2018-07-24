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
//  SerialViewController.h
//
//  Created by Jon Mackey on 1/2/18.
//  Copyright © 2018 Jon Mackey. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <ORSSerial/ORSSerial.h>
#import "LogViewController.h"
#import "SerialPortIOSession.h"

@interface SerialViewController : LogViewController <ORSSerialPortDelegate, NSUserNotificationCenterDelegate>
- (IBAction)send:(id)sender;
- (IBAction)openOrClosePort:(id)sender;

- (BOOL)portIsOpen:(BOOL)inReportIfNoConnection;
- (void)stop;
-(BOOL)sessionIsDone;

@property (unsafe_unretained) IBOutlet NSTextField *sendTextField;
@property (unsafe_unretained) IBOutlet NSButton *openCloseButton;
@property (unsafe_unretained) IBOutlet NSPopUpButton *lineEndingPopUpButton;
@property (unsafe_unretained) IBOutlet NSPopUpButton *baudRatePopUpButton;

@property (nonatomic, strong) ORSSerialPortManager *serialPortManager;
@property (nonatomic, strong) SerialPortIOSession *serialPortSession;
@property (nonatomic, strong) ORSSerialPort *serialPort;
@property (nonatomic) BOOL sendAsHex;
@property (nonatomic) BOOL checkForNonPrintableChars;
@property (nonatomic) BOOL doUTF8Buffering;
@property (nonatomic, strong) NSMutableData *utf8Buffer;

@end
