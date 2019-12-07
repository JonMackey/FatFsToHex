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
//  SerialPortIOSession.h
//  FatFsToHex
//
//  Created by Jon Mackey on 1/7/18.
//  Copyright © 2018 Jon Mackey. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <ORSSerial/ORSSerial.h>

NS_ASSUME_NONNULL_BEGIN

@protocol LogDelegate;
@interface SerialPortIOSession : NSObject

@property (getter=isDone, nonatomic) BOOL done;
@property (getter=wasStopped, nonatomic) BOOL stopped;
@property (nonatomic) BOOL stoppedDueToTimeout;
@property (nonatomic) BOOL stoppedDueToError;
@property (nonatomic, strong) ORSSerialPort* serialPort;
@property (nullable, strong) NSData* data;
@property (nullable, strong) NSString* beginMsg;
@property (nullable, strong) NSString* completedMsg;
@property (nonatomic) NSUInteger	idleTime;
@property (nonatomic) NSUInteger	timeout;
@property (nullable, weak) id<LogDelegate> delegate;

@property (nonatomic, copy, nullable) void (^completionBlock)(SerialPortIOSession* ioSession);
@property NSInteger completionTag;

- (instancetype)initWithData:(NSData * _Nullable)inData port:(ORSSerialPort *)inPort;
- (void)begin;
- (NSData*)didReceiveData:(NSData *)inData;
- (void)stop;
- (void)timeoutCheck;
@end

@protocol LogDelegate <NSObject>

@required
- (void)logErrorString:(NSString*)inString;
- (void)logWarningString:(NSString*)inString;
- (void)logInfoString:(NSString*)inString;
@end

NS_ASSUME_NONNULL_END
