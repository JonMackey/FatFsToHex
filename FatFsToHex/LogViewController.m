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
//  LogViewController.m
//  FatFsToHex
//
//  Created by Jon Mackey on 1/3/18.
//  Copyright © 2018 Jon Mackey. All rights reserved.
//

#import "LogViewController.h"

@interface LogViewController ()

@end

@implementation LogViewController

/****************************** viewDidLoad ***********************************/
- (void)viewDidLoad
{
	[super viewDidLoad];
	[self initialize];
}

#pragma mark - Actions
/****************************** awakeFromNib **********************************/
- (void)awakeFromNib
{
	[super awakeFromNib];
	[self initialize];
}

/******************************* initialize ***********************************/
- (void)initialize
{
	if (!_blackColor)
	{
		self.blackColor = [NSColor blackColor];
		self.redColor = [NSColor colorWithDeviceRed:0.92 green:0 blue:0 alpha:1];
		self.greenColor = [NSColor colorWithDeviceRed:0 green:0.65 blue:0 alpha:1];
		self.blueColor = [NSColor blueColor];
		self.greyColor = [NSColor colorWithDeviceRed:0.25 green:0.25 blue:0.25 alpha:1];
		self.lightBrownColor = [NSColor colorWithDeviceRed:0.61 green:0.4 blue:0.2 alpha:1];
		self.lightPurpleColor = [NSColor colorWithDeviceRed:0.4 green:0.2 blue:0.61 alpha:1];
		self.skyBlueColor = [NSColor colorWithDeviceRed:0.5 green:0.65 blue:0.85 alpha:1];
		self.lightBlueColor = [NSColor colorWithDeviceRed:0 green:0.61 blue:1 alpha:1];
		self.darkGreenColor = [NSColor colorWithDeviceRed:0.29 green:0.32 blue:0 alpha:1];
		self.yellowColor = [NSColor colorWithDeviceRed:1 green:0.61 blue:0 alpha:1];
		self.pinkColor = [NSColor colorWithDeviceRed:1 green:0.4 blue:0.5 alpha:1];
		self.purpleColor = [NSColor colorWithDeviceRed:0.5 green:0 blue:0.5 alpha:1];
		self.slateBlueColor = [NSColor colorWithDeviceRed:0.2 green:0.4 blue:0.61 alpha:1];
		self.font = [NSFont fontWithName:@"Menlo-Regular" size:12];
		self.currentColorRange = NSMakeRange(0,0);
		self.currentRange = NSMakeRange(0,0);
		_firstApply = YES;
		self.logText = [[NSMutableAttributedString alloc] initWithString:@""];
		_tabDepth = 0;
		self.currentColor = self.blackColor;
		self.currentParaStyle = NULL;
	}
}

/************************************* clear ****************************************/
- (IBAction)clear:(id)sender
{
	self.firstApply = YES;
	[self.receivedDataTextView.textStorage.mutableString setString:@" "];
	[self.receivedDataTextView setNeedsDisplay:YES];
}


/***************************** postErrorString ********************************/
/*
*	Immediately post a time stamped error string to the log of the form:
*	[date]: %@\n
*/
- (LogViewController*)postErrorString:(NSString*)inString
{
	[[[[[[[[self setColor:self.redColor] appendString:@"["] appendDate] appendString:@"] Error:"] setColor:self.blackColor] appendFormat:@"   %@", inString] appendNewLine] post];
	return(self);
}

/***************************** postWarningString ******************************/
/*
*	Immediately post a time stamped error string to the log of the form:
*	[date]: %@\n
*/
- (LogViewController*)postWarningString:(NSString*)inString
{
	[[[[[[[[self setColor:self.yellowColor] appendString:@"["] appendDate] appendString:@"] Warning:"] setColor:self.blackColor] appendFormat:@"   %@", inString] appendNewLine] post];
	return(self);
}

/***************************** postInfoString *********************************/
/*
*	Immediately post a time stamped error string to the log of the form:
*	<happy face> [date] %@\n
*/
- (LogViewController*)postInfoString:(NSString*)inString
{
	[[[[[[[[self setColor:self.greenColor] appendString:@"["] appendDate] appendString:@"]"] setColor:self.blackColor] appendFormat:@"   %@", inString] appendNewLine] post];
	return(self);
}

/*********************************** post *************************************/
- (LogViewController*)post
{
	if ([self.logText length] > 0)
	{
		[self setParaStyle:NULL];
		[self setColor:NULL];
		[self.receivedDataTextView.textStorage appendAttributedString:self.logText];
		NSRange	endRange = NSMakeRange([self.receivedDataTextView.textStorage length], 0);
		// The following will work reliably only on the main thread.
		// For automator actions doing this was randomly crashing.
		// See https://stackoverflow.com/questions/21396034/nstextview-setneedsdisplay-not-working-under-mavericks
		[self.receivedDataTextView setSelectedRange:endRange];
		[self.receivedDataTextView scrollRangeToVisible:endRange];
		[self.receivedDataTextView setNeedsDisplay:YES];
		[self flush];
	}
	return(self);
}

/***************************** postWithoutScroll ******************************/
- (LogViewController*)postWithoutScroll
{
	if ([self.logText length] > 0)
	{
		[self setParaStyle:NULL];
		[self setColor:NULL];
		[self.receivedDataTextView.textStorage appendAttributedString:self.logText];
		[self.receivedDataTextView setNeedsDisplay:YES];
		[self flush];
	}
	return(self);
}

/*********************************** flush ************************************/
- (LogViewController*)flush
{
	NSUInteger	textLen = [self.logText length];
	if (textLen)
	{
		self.logText = [[NSMutableAttributedString alloc] initWithString:@""];
		//[logText deleteCharactersInRange:NSMakeRange(0, textLen)];
	}
	_tabDepth = 0;
	self.currentColorRange = NSMakeRange(0, 0);
	self.currentRange = NSMakeRange(0, 0);
	self.firstApply = YES;
	return(self);
}


/********************************* setFont ************************************/
/*
*	Sets the font for all text. The log should be empty when this is called.
*/
- (void)setFont:(NSFont*)inFont
{
	//NSLog(@"setFont = %@\n", inFont.displayName);
	_font = inFont;
	_firstApply = YES;
}

/********************************* setColor ***********************************/
/*
*	Sets the current color.
*/
- (LogViewController*)setColor:(NSColor*)inColor
{
	/*
	*	If the color has changed AND
	*	there are characters that haven't had the current color applied yet THEN
	*	apply the color now.
	*/
	if (self.currentColor != inColor &&
		self.currentColorRange.length > 0)
	{
		[self.logText addAttribute:NSForegroundColorAttributeName value:self.currentColor range:self.currentColorRange];
		if (_firstApply)
		{
			_firstApply = NO;
			if (_font)
			{
				[self.logText addAttribute:NSFontAttributeName value:_font range:self.currentColorRange];
			}
		}
		self.currentColorRange = NSMakeRange(self.currentColorRange.location + self.currentColorRange.length, 0);
	}
	if (inColor != NULL)
	{
		self.currentColor = inColor;
	}
	return(self);
}

/******************************* resetParaStyle *******************************/
/*
*	Resets the current paragraph style back to the default.  (should be called before setColor)
*/
- (LogViewController*)resetParaStyle
{
	if (self.currentParaStyle != NULL)
	{
		self.currentParaStyle = [NSParagraphStyle defaultParagraphStyle];
	}
	return(self);
}

/***************************** resetCurrentRange ******************************/
/*
*	Resets the current paragraph style back to the default.  (should be called before setColor)
*/
- (LogViewController*)resetCurrentRange
{
	self.currentRange = NSMakeRange(self.currentRange.location + self.currentRange.length, 0);
	return(self);
}

/****************************** setParaStyle **********************************/
/*
*	Sets the current paragraph style.  (should be called before setColor)
*/
- (LogViewController*)setParaStyle:(NSParagraphStyle*)inParaStyle
{
	if (self.currentParaStyle != NULL)
	{
		if (self.currentParaStyle != inParaStyle &&
			self.currentRange.length > 0)
		{
			[self.logText addAttribute:NSParagraphStyleAttributeName value:self.currentParaStyle range:self.currentRange];
		}
	}
	if (inParaStyle != NULL)
	{
		self.currentParaStyle = inParaStyle;
	}
	return(self);
}

/******************************* appendString *********************************/
- (LogViewController*)appendString:(NSString*)inString
{
	[[self.logText mutableString] appendString:inString];
	self.currentColorRange = NSMakeRange(self.currentColorRange.location, self.currentColorRange.length + [inString length]);
	self.currentRange = NSMakeRange(self.currentRange.location, self.currentRange.length + [inString length]);
	return(self);
}

/************************** appendAttributedString ****************************/
- (LogViewController*)appendAttributedString:(NSAttributedString*)inString
{
	[self setColor:NULL];	// Apply the current color
	[self.logText appendAttributedString:inString];
	self.currentColorRange = NSMakeRange(self.currentColorRange.location, self.currentColorRange.length + [inString length]);
	self.currentRange = NSMakeRange(self.currentRange.location, self.currentRange.length + [inString length]);
	return(self);
}

/**************************** appendCharacters ********************************/
- (LogViewController*)appendCharacters:(const unichar*)inUniChars length:(UInt32)inLength
{
	[self appendString:[NSString stringWithCharacters:inUniChars length:inLength]];
	return(self);
}

/***************************** appendUTF8String *******************************/
- (LogViewController*)appendUTF8String:(const char*)inUTF8Chars
{
	[self appendString:[NSString stringWithUTF8String:inUTF8Chars]];
	return(self);
}

/************************* appendColoredCharacters ****************************/
- (LogViewController*)appendColoredCharacters:(NSColor*)inColor chars:(const unichar*)inUniChars length:(UInt32)inLength
{
	NSColor*	savedCurrentColor = self.currentColor;
	[self setColor:inColor];
	[self appendString:[NSString stringWithCharacters:inUniChars length:inLength]];
	[self setColor:savedCurrentColor];
	return(self);
}

/************************** appendColoredString *******************************/
/*
*	This routine appendString only appends a string without affecting the current color
*/
- (LogViewController*)appendColoredString:(NSColor*)inColor string:(NSString*)inString
{
	NSColor*	savedCurrentColor = self.currentColor;
	[self setColor:inColor];
	[self appendString:inString];
	[self setColor:savedCurrentColor];
	return(self);
}

/****************************** appendFormat **********************************/
- (LogViewController*)appendFormat:(NSString *)inFormat, ...
{
	va_list		argList;
	va_start(argList, inFormat);
	[self appendFormatAndArguments:inFormat arguments:argList];
	va_end(argList);
	return(self);
}

/**************************** appendColoredFormat *****************************/
- (LogViewController*)appendColoredFormat:(NSColor*)inColor format:(NSString *)inFormat, ...
{
	va_list		argList;
	va_start(argList, inFormat);
	NSColor*	savedCurrentColor = self.currentColor;
	[self setColor:inColor];
	[self appendFormatAndArguments:inFormat arguments:argList];
	[self setColor:savedCurrentColor];
	va_end(argList);
	return(self);
}

/************************* appendFormatAndArguments ***************************/
- (LogViewController*)appendFormatAndArguments:(NSString *)inFormat arguments:(va_list)inArguments
{
	NSMutableString*	mutableString = [self.logText mutableString];
	CFIndex	lengthBefore = [mutableString length];
	[mutableString appendString:[[NSString alloc] initWithFormat:inFormat arguments:inArguments]];
//	CFStringAppendFormatAndArguments((CFMutableStringRef)mutableString, NULL, (CFStringRef)inFormat, inArguments);
	NSUInteger	lengthDelta =  ([mutableString length] - lengthBefore);
	self.currentColorRange = NSMakeRange(self.currentColorRange.location, self.currentColorRange.length + lengthDelta);
	self.currentRange = NSMakeRange(self.currentRange.location, self.currentRange.length + lengthDelta);
	return(self);
}

/********************************** tabs **************************************/
- (LogViewController*)tabs:(int32_t)inDepthDelta
{
	_tabDepth += inDepthDelta;
	return(self);
}

/***************************** setTabDepth ************************************/
- (void)setTabDepth:(CFIndex)inDepth
{
	_tabDepth = inDepth;
}

/******************************* getTabDepth **********************************/
- (CFIndex)getTabDepth
{
	return(_tabDepth);
}

/******************************** incTab **************************************/
- (LogViewController*)incTab
{
	_tabDepth++;
	return(self);
}

/********************************** decTab ************************************/
- (LogViewController*)decTab
{
	if (_tabDepth > 0)
	{
		_tabDepth--;
	}
	return(self);
}

/****************************** appendNewLine *********************************/
- (LogViewController*)appendNewLine:(int32_t)inTabDepthDelta
{
	_tabDepth += inTabDepthDelta;
	[self appendNewLine];
	return(self);
}

/****************************** appendNewLine *********************************/
/*
*	Appends a new-line char
*/
- (LogViewController*)appendNewLine
{
	static const UniChar kNL = 10;
	[[self.logText mutableString] appendString:[[NSString alloc] initWithCharacters:&kNL length:1]];
	self.currentColorRange = NSMakeRange(self.currentColorRange.location, self.currentColorRange.length + 1);
	self.currentRange = NSMakeRange(self.currentRange.location, self.currentRange.length + 1);
	return(self);
}

/******************************** appendTabs **********************************/
/*
*	Sets up the line by appending tabs to the current depth
*/
- (LogViewController*)appendTabs
{
	static const UniChar kTabs[] = {9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9};	// 25 tabs
	CFIndex	charsToAppend = _tabDepth;
	if (charsToAppend)
	{
		if (charsToAppend > 26)
		{
			charsToAppend = 26;
		}
		[[self.logText mutableString] appendString:[[NSString alloc] initWithCharacters:kTabs length:charsToAppend]];
		self.currentColorRange = NSMakeRange(self.currentColorRange.location, self.currentColorRange.length + charsToAppend);
		self.currentRange = NSMakeRange(self.currentRange.location, self.currentRange.length + charsToAppend);
	}
	return(self);
}

/*************************** appendOpenBracket ********************************/
- (LogViewController*)appendOpenBracket
{
	[self appendNewLine];
	_tabDepth++;
	[self appendString:@"{"];
	return(self);
}

/************************** appendClosedBracket *******************************/
- (LogViewController*)appendClosedBracket
{
	_tabDepth--;
	[self appendNewLine];
	[self appendString:@"}"];
	return(self);
}

/**************************** appendColoredDate *******************************/
- (LogViewController*)appendColoredDate:(NSColor*)inColor
{
	NSColor*	savedCurrentColor = self.currentColor;
	[self setColor:inColor];
	[self appendDate:[NSDate date]];
	[self setColor:savedCurrentColor];
	return(self);
}

/**************************** appendColoredDate *******************************/
- (LogViewController*)appendColoredDate:(NSColor*)inColor date:(NSDate*)inDate
{
	NSColor*	savedCurrentColor = self.currentColor;
	[self setColor:inColor];
	[self appendDate:inDate];
	[self setColor:savedCurrentColor];
	return(self);
}

/****************************** appendDate ************************************/
- (LogViewController*)appendDate
{
	[self appendString:[NSDateFormatter localizedStringFromDate:[NSDate date] dateStyle:NSDateFormatterMediumStyle timeStyle:NSDateFormatterMediumStyle]];
	return(self);
}

/****************************** appendDate ************************************/
- (LogViewController*)appendDate:(NSDate*)inDate
{
	if (inDate)
	{
		[self appendString:[NSDateFormatter localizedStringFromDate:inDate dateStyle:NSDateFormatterMediumStyle timeStyle:NSDateFormatterMediumStyle]];
	}
	return(self);
}
/*********************** containsNonPrintableChars ****************************/
- (BOOL)containsNonPrintableChars:(const void*)inBuffer length:(NSUInteger)inLength
{
	const uint8_t*	bufferPtr = (const uint8_t*)inBuffer;
	NSUInteger index = 0;
	while (index < inLength)
	{
		uint8_t	thisByte = bufferPtr[index++];
		if ((thisByte >= 0x20/* && thisByte <= 0x7f*/) ||
			thisByte == '\t' ||
			thisByte == '\n' ||
			thisByte == '\r')
		{
			continue;
		}
		return(YES);
	}
	return(NO);
}

/***************************** appendHexDump **********************************/
- (LogViewController*)appendHexDump:(const void*)inBuffer length:(NSUInteger)inLength addPreamble:(BOOL)inAddPreamble
{
	if (inAddPreamble)
	{
		[self appendNewLine];
		[self appendColoredFormat:self.greyColor format:@"----- %d bytes -----", inLength];
		[self appendNewLine:1];
	}
	NSMutableAttributedString*	asciiLine = [[NSMutableAttributedString alloc] initWithString:@"  "];
	NSColor*	currentColor = self.lightBrownColor;
	NSRange		currentColorRange = {0,2};
	BOOL		needsApplyFont = _font != NULL;

	const uint8_t*	bufferPtr = (const uint8_t*)inBuffer;
	int32_t index = 0;
	while (index < inLength)
	{
		uint8_t	thisByte = bufferPtr[index++];
		if (thisByte < 0x20 || thisByte > 0x7f)
		{
			if (currentColor != self.lightBrownColor)
			{
				if (currentColorRange.length > 0)
				{
					[asciiLine addAttribute:NSForegroundColorAttributeName value:currentColor range:currentColorRange];
					if (needsApplyFont)
					{
						needsApplyFont = NO;
						[asciiLine addAttribute:NSFontAttributeName value:self.font range:currentColorRange];
					}
					currentColorRange.location += currentColorRange.length;
					currentColorRange.length = 0;
				}
				currentColor = self.lightBrownColor;
			}
			[[asciiLine mutableString] appendString:@"."];
			currentColorRange.length++;
		} else
		{
			if (currentColor != self.slateBlueColor)
			{
				if (currentColorRange.length > 0)
				{
					[asciiLine addAttribute:NSForegroundColorAttributeName value:currentColor range:currentColorRange];
					if (needsApplyFont)
					{
						needsApplyFont = NO;
						[asciiLine addAttribute:NSFontAttributeName value:_font range:currentColorRange];
					}
					currentColorRange.location += currentColorRange.length;
					currentColorRange.length = 0;
				}
				currentColor = self.slateBlueColor;
			}
			[[asciiLine mutableString] appendFormat:@"%c", thisByte];
			currentColorRange.length++;
		}

		[self appendColoredFormat:currentColor format:@"%0.2X ", (int32_t)thisByte];

		if (index > 1)
		{
			if ((index % 16) == 0)
			{
				if (currentColorRange.length > 0)
				{
					[asciiLine addAttribute:NSForegroundColorAttributeName value:currentColor range:currentColorRange];
					if (needsApplyFont)
					{
						needsApplyFont = NO;
						[asciiLine addAttribute:NSFontAttributeName value:_font range:currentColorRange];
					}
				}
				[self appendAttributedString:asciiLine];
				[[asciiLine mutableString] setString:@"  "];
				currentColorRange.location = 0;
				currentColorRange.length = 2;
				[self appendNewLine];
			} else if ((index % 4) == 0)
			{
				[self appendString:@" "];
			}
		}
	}
	
	index = index % 16;
	if (index > 0)
	{
		if (currentColorRange.length > 0)
		{
			[asciiLine addAttribute:NSForegroundColorAttributeName value:currentColor range:currentColorRange];
			if (needsApplyFont)
			{
				needsApplyFont = NO;
				[asciiLine addAttribute:NSFontAttributeName value:_font range:currentColorRange];
			}
		}
		NSRange	endRange;
		endRange.location = (index*3) + (index/4);
		endRange.length = 51 - endRange.location;
		[self appendColoredString:self.greyColor string:[@".. .. .. ..  .. .. .. ..  .. .. .. ..  .. .. .. .. " substringWithRange:endRange]];
		[self appendAttributedString:asciiLine];
		[self appendNewLine:inAddPreamble ? -1:0];
	} else if (inAddPreamble)
	{
		[self tabs:-1];
	}
	if (inAddPreamble)
	{
		[self appendColoredString:self.greyColor string:@"----- end bytes -----"];
		[self appendNewLine];
	}
	return(self);
}

@end
