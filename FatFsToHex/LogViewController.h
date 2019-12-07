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
//  LogViewController.h
//
//  Created by Jon Mackey on 1/2/18.
//  Copyright © 2018 Jon Mackey. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface LogViewController : NSViewController

@property (unsafe_unretained) IBOutlet NSTextView *receivedDataTextView;

@property (nonatomic, strong) NSColor *blackColor;
@property (nonatomic, strong) NSColor *redColor;
@property (nonatomic, strong) NSColor *greenColor;
@property (nonatomic, strong) NSColor *blueColor;
@property (nonatomic, strong) NSColor *greyColor;
@property (nonatomic, strong) NSColor *lightBrownColor;
@property (nonatomic, strong) NSColor *lightPurpleColor;
@property (nonatomic, strong) NSColor *skyBlueColor;
@property (nonatomic, strong) NSColor *lightBlueColor;
@property (nonatomic, strong) NSColor *darkGreenColor;
@property (nonatomic, strong) NSColor *yellowColor;
@property (nonatomic, strong) NSColor *pinkColor;
@property (nonatomic, strong) NSColor *purpleColor;
@property (nonatomic, strong) NSColor *slateBlueColor;
@property (nonatomic, strong) NSColor *currentColor;
@property (nonatomic, strong) NSMutableAttributedString *logText;
@property (nonatomic, strong) NSFont *font;
@property (nonatomic, strong) NSParagraphStyle *currentParaStyle;
@property (nonatomic, strong) NSDateFormatter *dateFormatter;
@property (nonatomic) NSRange currentColorRange;
@property (nonatomic) NSRange currentRange;
@property (nonatomic) BOOL firstApply;
@property (nonatomic) CFIndex tabDepth;

- (LogViewController*)postErrorString:(NSString*)inString;
- (LogViewController*)postWarningString:(NSString*)inString;
- (LogViewController*)postInfoString:(NSString*)inString;
- (LogViewController*)post;
- (LogViewController*)postWithoutScroll;
- (LogViewController*)flush;
- (void)setFont:(NSFont*)inFont;	// All text
- (LogViewController*)setColor:(NSColor*)inColor;
- (LogViewController*)resetParaStyle;
- (LogViewController*)resetCurrentRange;
- (LogViewController*)setParaStyle:(NSParagraphStyle*)inParaStyle;

- (void)setTabDepth:(CFIndex)inDepth;
- (CFIndex)getTabDepth;
- (LogViewController*)tabs:(int32_t)inDepthDelta;
- (LogViewController*)incTab;
- (LogViewController*)decTab;
- (LogViewController*)appendCharacters:(const unichar*)inUniChars length:(UInt32)inLength;
- (LogViewController*)appendUTF8String:(const char*)inUTF8Chars;
- (LogViewController*)appendColoredCharacters:(NSColor*)inColor chars:(const unichar*)inUniChars length:(UInt32)inLength;
- (LogViewController*)appendString:(NSString*)inString;
- (LogViewController*)appendAttributedString:(NSAttributedString*)inString;
- (LogViewController*)appendColoredString:(NSColor*)inColor string:(NSString*)inString;
- (LogViewController*)appendFormat:(NSString *)inFormat, ...;
- (LogViewController*)appendColoredFormat:(NSColor*)inColor format:(NSString *)inFormat, ...;
- (LogViewController*)appendFormatAndArguments:(NSString *)inFormat arguments:(va_list)inArguments;
- (LogViewController*)appendTabs;
- (LogViewController*)appendNewLine;
- (LogViewController*)appendNewLine:(int32_t)inTabDepthDelta;
- (LogViewController*)appendOpenBracket;
- (LogViewController*)appendClosedBracket;
- (LogViewController*)appendDate;
- (LogViewController*)appendDate:(NSDate*)inDate;
- (LogViewController*)appendColoredDate:(NSColor*)inColor;
- (LogViewController*)appendColoredDate:(NSColor*)inColor date:(NSDate*)inDate;
- (LogViewController*)appendHexDump:(const void*)inBuffer length:(NSUInteger)inLength addPreamble:(BOOL)inAddPreamble;
- (BOOL)containsNonPrintableChars:(const void*)inBuffer length:(NSUInteger)inLength;
- (IBAction)clear:(id)sender;

@end
