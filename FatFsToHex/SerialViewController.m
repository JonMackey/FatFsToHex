//
//  SerialViewController.m
//
//  Created by Jon on 1/2/18.
//  Copyright © 2018 Jon. All rights reserved.
//
//
//  Originally named : ORSSerialPortDemoController.m
//  from ORSSerialPortDemo
//
//  Original Created by Andrew R. Madsen on 6/27/12.
//	Copyright (c) 2012-2014 Andrew R. Madsen (andrew@openreelsoftware.com)
//
//	Permission is hereby granted, free of charge, to any person obtaining a
//	copy of this software and associated documentation files (the
//	"Software"), to deal in the Software without restriction, including
//	without limitation the rights to use, copy, modify, merge, publish,
//	distribute, sublicense, and/or sell copies of the Software, and to
//	permit persons to whom the Software is furnished to do so, subject to
//	the following conditions:
//
//	The above copyright notice and this permission notice shall be included
//	in all copies or substantial portions of the Software.
//
//	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
//	OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
//	MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
//	IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
//	CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
//	TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
//	SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
/*
*	Many more features added by Jon Mackey 2018
*	Copyright © 2018 Jon Mackey. All rights reserved.
*	Added:
*	- Support for UTF-8 octets (original code would crash if received packet
*		ended with an incomplete octet sequence.)
*	- Support for colored text
*	- Support for sending and recieving binary non-printing values
*	- Hex dump feature
*	- automatic scrolling to the end of the log
*/

#import "SerialViewController.h"

@interface SerialViewController ()

@end

@implementation SerialViewController


/********************************* dealloc ************************************/
- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[self unbind:@"doUTF8Buffering"];
	[self unbind:@"checkForNonPrintableChars"];
	[self unbind:@"sendAsHex"];
}

/****************************** viewDidLoad ***********************************/
- (void)viewDidLoad
{
    [super viewDidLoad];

	[self bind:@"doUTF8Buffering" toObject:[NSUserDefaults standardUserDefaults] withKeyPath:@"checkUTF8" options:NULL];
	[self bind:@"checkForNonPrintableChars" toObject:[NSUserDefaults standardUserDefaults] withKeyPath:@"checkForNonPrintChars" options:NULL];
	[self bind:@"sendAsHex" toObject:[NSUserDefaults standardUserDefaults] withKeyPath:@"binaryIO" options:NULL];
	
	self.serialPortManager = [ORSSerialPortManager sharedSerialPortManager];

	NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
	[nc addObserver:self selector:@selector(serialPortsWereConnected:) name:ORSSerialPortsWereConnectedNotification object:nil];
	[nc addObserver:self selector:@selector(serialPortsWereDisconnected:) name:ORSSerialPortsWereDisconnectedNotification object:nil];

#if (MAC_OS_X_VERSION_MAX_ALLOWED > MAC_OS_X_VERSION_10_7)
	[[NSUserNotificationCenter defaultUserNotificationCenter] setDelegate:self];
#endif


	NSString*	portName = [[NSUserDefaults standardUserDefaults] objectForKey:@"portName"];
	if (portName && portName.length)
	{
		NSUInteger index = [self.serialPortManager.availablePorts indexOfObjectPassingTest:
            ^BOOL(ORSSerialPort* inSerialPort, NSUInteger inIndex, BOOL *outStop)
            {
            	return ([inSerialPort.name isEqualToString:portName]);
            }];
		if (index != NSNotFound)
		{
			self.serialPort = self.serialPortManager.availablePorts[index];
		}
	}
}

#pragma mark - Actions
/****************************** awakeFromNib **********************************/
- (void)awakeFromNib
{
	[super awakeFromNib];
}

/******************************** toBinary ************************************/
/*
*	Converts the passed 2-byte hex ascii string  to binary.  Whitespace is
*	ignored between 2-byte hex digits but not within.
*	Invalid characters !(0-9 A-F a-f) will result in an error and an NULL NSData
*	object being returned.
*/
- (NSData*)toBinary:(NSString*)inString
{
	const char* buffer = [inString UTF8String];
	const char* bufferPtr = buffer;
	uint8_t 	binary[1024];
	uint32_t	binaryIndex = 0;
	uint8_t		hexVal;
	NSString*	error = NULL;
	for (char thisChar = *(bufferPtr++); thisChar != 0; thisChar = *(bufferPtr++))
	{
		if (!isspace(thisChar))
		{
			char nextChar = *(bufferPtr++);
			if (nextChar)
			{
				if (thisChar >= '0' && thisChar <= '9')
				{
					hexVal = (thisChar - '0');
				} else
				{
					thisChar |= 0x20;
					if ((thisChar >= 'a' && thisChar <= 'f'))
					{
						hexVal = (thisChar - 'a' + 10);
					} else
					{
						// Error, invalid character
						binaryIndex = 0;
						error = [NSString stringWithFormat:@"Invalid character '%c' at offset %ld", thisChar, bufferPtr-buffer-2];
						break;
					}
				}
				hexVal <<= 4;
				if (nextChar >= '0' && nextChar <= '9')
				{
					hexVal += (nextChar - '0');
				} else
				{
					nextChar |= 0x20;
					if ((nextChar >= 'a' && nextChar <= 'f'))
					{
						hexVal += (nextChar - 'a' + 10);
					} else
					{
						// Error, invalid character
						binaryIndex = 0;
						error = [NSString stringWithFormat:@"Invalid character '%c' at offset %ld", nextChar, bufferPtr-buffer-1];
						break;
					}
				}
				binary[binaryIndex++] = hexVal;
			} else
			{
				// Error odd hex count
				binaryIndex = 0;
				error = [NSString stringWithFormat:@"Incomplete hex digit (not 2 chars) at offset %ld", bufferPtr-buffer-1];
				break;
			}
		}
	}
	NSData *dataToSend = NULL;
	if (error)
	{
		[[[[[[self setColor:self.redColor] appendString:@">>Error:"] setColor:self.blackColor] appendFormat:@" %@", error] appendNewLine] post];
	}
	if (binaryIndex)
	{
		// DFPlayer debugging...
		if (binaryIndex == 10)
		{
			fprintf(stderr, "%02hhX %02hhX %02hhX %02hhX %02hhX %02hhX %02hhX %02hhX %02hhX %02hhX\n",
				binary[0], binary[1], binary[2], binary[3], binary[4], binary[5], binary[6], binary[7], binary[8], binary[9]);
		}
		dataToSend = [NSData dataWithBytes:binary length:binaryIndex];
	}
	return(dataToSend);
}


/******************************* portIsOpen ***********************************/
- (BOOL)portIsOpen:(BOOL)inReportIfNoConnection
{
	BOOL	isOpen = self.serialPort.isOpen;
	if (!isOpen &&
		inReportIfNoConnection)
	{
		[[[[[[self setColor:self.yellowColor] appendString:@">>Warning:"] setColor:self.blackColor] appendString:@" Not connected, no port open."] appendNewLine] post];
	}
	return(isOpen);
}

/********************************** send **************************************/
- (IBAction)send:(id)sender
{
	if ([self portIsOpen:YES])
	{
		NSData *dataToSend = NULL;
		NSString *string = self.sendTextField.stringValue;
		
		if (self.sendAsHex)
		{
			dataToSend = [self toBinary:string];
		} else
		{
			if (self.lineEndingPopUpButton.selectedTag)
			{
				string = [string stringByAppendingString:[@[@"", @"\n", @"\r", @"r\n"] objectAtIndex:self.lineEndingPopUpButton.selectedTag]];
			}
			dataToSend = [string dataUsingEncoding:NSUTF8StringEncoding];
		}
		if (dataToSend &&
			dataToSend.length != 0)
		{
			[self.serialPort sendData:dataToSend];
		}
	}
}

/******************************** openOrClosePort **********************************/
- (IBAction)openOrClosePort:(id)sender
{
	if (self.serialPort.isOpen)
	{
		[self.serialPort close];
		self.baudRatePopUpButton.enabled = YES;	// Tried binding to self.serialPort.isOpen but it didn't work
	} else
	{
		self.serialPort.baudRate = [NSNumber numberWithUnsignedInteger: [[NSUserDefaults standardUserDefaults] integerForKey:@"baudRate"]];
		self.baudRatePopUpButton.enabled = NO;
		[self.serialPort open];
	}
}

#pragma mark - ORSSerialPortDelegate Methods

- (void)serialPortWasOpened:(ORSSerialPort *)serialPort
{
	self.openCloseButton.title = @"Close";
	[self postInfoString: [NSString stringWithFormat:@"%@ opened", [self.serialPort name]]];
}

- (void)serialPortWasClosed:(ORSSerialPort *)serialPort
{
	self.serialPortSession = NULL;
	self.openCloseButton.title = @"Open";
	[self postInfoString: [NSString stringWithFormat:@"%@ closed", [self.serialPort name]]];
}

- (void)serialPort:(ORSSerialPort *)serialPort didReceiveData:(NSData *)data
{
	if (self.serialPortSession)
	{
		data = [self.serialPortSession didReceiveData:data];
		if ([self.serialPortSession isDone])
		{
			self.serialPortSession = NULL;
		}
	}
	if (data.length)
	{
		if (self.checkForNonPrintableChars &&
			[self containsNonPrintableChars:data.bytes length:data.length])
		{
			[self appendHexDump:data.bytes length:data.length addPreamble:NO];
		} else
		{
			/*
			*	When UTF-8 strings are being received we don't want to break
			*	any UTF-8 octet sequences, which can happen depending on
			*	when the receive code decides to call didReceiveData.
			*
			*	If the doUTF8Buffering flag is set THEN
			*	prepend any existing buffer from the last call to didReceiveData.
			*	Then if the buffer contains a broken octet sequence at the end
			*	then buffer it (don't display anything) till the next call
			*	to didReceiveData (which there has to be if the sequence is
			*	broken).
			*/
			if (self.doUTF8Buffering)
			{
				if (self.utf8Buffer)
				{
					[self.utf8Buffer appendData:data];
					data = self.utf8Buffer;
					self.utf8Buffer = NULL;
				}
				NSUInteger length = data.length;
				const uint8_t *bufferStart = (const uint8_t *)data.bytes;
				const uint8_t *bufferEnd = &bufferStart[length];
				const uint8_t *bufferPtr = bufferEnd-1;
				while (bufferPtr >= bufferStart)
				{
					// If one of:
					// E0 80
					// E0
					// C0 THEN
					// Keep looping till the beginning of the sequence or the
					// beginning of the buffer, whichever occurs first.
					if ((*bufferPtr & 0xC0) == 0x80)
					{
						--bufferPtr;
						continue;
					}
					break;
				}
				if (*bufferPtr & 0x80)
				{
					NSUInteger sequenceLen = bufferEnd-bufferPtr;
					uint8_t	seqLenByte = *bufferPtr & 0xE0;	// Only supporting 16 bit codewords
					if ((seqLenByte == 0xC0 && sequenceLen != 2) ||
						(seqLenByte == 0xE0 && sequenceLen != 3) ||
						seqLenByte == 0x80)
					{
					//	[self appendFormat:@"\n%X, sequenceLen = %d, length = %d\n", (int)*bufferPtr, (int)sequenceLen, (int)length];
						self.utf8Buffer = [NSMutableData dataWithCapacity:sequenceLen];
						[self.utf8Buffer setData:data];
						return;
					}
				}
			}
			NSString *string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
			if (string)
			{
				[self appendString:string];
			} else if (self.checkForNonPrintableChars)
			{
				[self appendFormat:@"\nlength = %d\n", (int)data.length];
				[self appendHexDump:data.bytes length:data.length addPreamble:NO];
			}
		}
		[self post];
		//[self.receivedDataTextView.textStorage.mutableString appendString:string];
		//[self.receivedDataTextView setNeedsDisplay:YES];
	}
}

- (void)serialPortWasRemovedFromSystem:(ORSSerialPort *)serialPort;
{
	// After a serial port is removed from the system, it is invalid and we must discard any references to it
	self.serialPort = nil;
	self.openCloseButton.title = @"Open";
}

- (void)serialPort:(ORSSerialPort *)serialPort didEncounterError:(NSError *)error
{
	//NSLog(@"Serial port %@ encountered an error: %@", serialPort, error);
	[self postErrorString: [NSString stringWithFormat:@"Serial port %@ encountered an error: %@", serialPort, error]];
}

#pragma mark - NSUserNotificationCenterDelegate

#if (MAC_OS_X_VERSION_MAX_ALLOWED > MAC_OS_X_VERSION_10_7)

- (void)userNotificationCenter:(NSUserNotificationCenter *)center didDeliverNotification:(NSUserNotification *)notification
{
	dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, 3.0 * NSEC_PER_SEC);
	dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
		[center removeDeliveredNotification:notification];
	});
}

- (BOOL)userNotificationCenter:(NSUserNotificationCenter *)center shouldPresentNotification:(NSUserNotification *)notification
{
	return YES;
}

#endif

#pragma mark - Notifications

- (void)serialPortsWereConnected:(NSNotification *)notification
{
	NSArray *connectedPorts = [notification userInfo][ORSConnectedSerialPortsKey];
	//NSLog(@"Ports were connected: %@", connectedPorts);
	[self postInfoString: [NSString stringWithFormat:@"Ports were connected: %@", connectedPorts]];
	[self postUserNotificationForConnectedPorts:connectedPorts];
}

- (void)serialPortsWereDisconnected:(NSNotification *)notification
{
	NSArray *disconnectedPorts = [notification userInfo][ORSDisconnectedSerialPortsKey];
	//NSLog(@"Ports were disconnected: %@", disconnectedPorts);
	[self postInfoString: [NSString stringWithFormat:@"Ports were disconnected: %@", disconnectedPorts]];
	[self postUserNotificationForDisconnectedPorts:disconnectedPorts];
	
}

- (void)postUserNotificationForConnectedPorts:(NSArray *)connectedPorts
{
#if (MAC_OS_X_VERSION_MAX_ALLOWED > MAC_OS_X_VERSION_10_7)
	if (!NSClassFromString(@"NSUserNotificationCenter")) return;
	
	NSUserNotificationCenter *unc = [NSUserNotificationCenter defaultUserNotificationCenter];
	for (ORSSerialPort *port in connectedPorts)
	{
		NSUserNotification *userNote = [[NSUserNotification alloc] init];
		userNote.title = NSLocalizedString(@"Serial Port Connected", @"Serial Port Connected");
		NSString *informativeTextFormat = NSLocalizedString(@"Serial Port %@ was connected to your Mac.", @"Serial port connected user notification informative text");
		userNote.informativeText = [NSString stringWithFormat:informativeTextFormat, port.name];
		userNote.soundName = nil;
		[unc deliverNotification:userNote];
	}
#endif
}

- (void)postUserNotificationForDisconnectedPorts:(NSArray *)disconnectedPorts
{
#if (MAC_OS_X_VERSION_MAX_ALLOWED > MAC_OS_X_VERSION_10_7)
	if (!NSClassFromString(@"NSUserNotificationCenter")) return;
	
	NSUserNotificationCenter *unc = [NSUserNotificationCenter defaultUserNotificationCenter];
	for (ORSSerialPort *port in disconnectedPorts)
	{
		NSUserNotification *userNote = [[NSUserNotification alloc] init];
		userNote.title = NSLocalizedString(@"Serial Port Disconnected", @"Serial Port Disconnected");
		NSString *informativeTextFormat = NSLocalizedString(@"Serial Port %@ was disconnected from your Mac.", @"Serial port disconnected user notification informative text");
		userNote.informativeText = [NSString stringWithFormat:informativeTextFormat, port.name];
		userNote.soundName = nil;
		[unc deliverNotification:userNote];
	}
#endif
}

#pragma mark - Properties
/***************************** setSerialPort **********************************/
/*
*	Override of setter function for _serialPort
*/
- (void)setSerialPort:(ORSSerialPort *)port
{
	if (port != _serialPort)
	{
		[_serialPort close];
		_serialPort.delegate = nil;
		
		_serialPort = port;
		_serialPort.allowsNonStandardBaudRates = YES;
		_serialPort.delegate = self;
		if (port)
		{
			[[NSUserDefaults standardUserDefaults] setObject:_serialPort.name forKey:@"portName"];
		}
	}
}

@end

