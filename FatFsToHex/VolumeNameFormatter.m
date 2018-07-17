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
//  VolumeNameFormatter.m
//  FatFsToHex
//
//  Created by Jon Mackey on 1/4/18.
//  Copyright © 2018 Jon Mackey. All rights reserved.
//

#import "VolumeNameFormatter.h"

@implementation VolumeNameFormatter

/***************************** getObjectValue *********************************/
-(BOOL)getObjectValue:(id *)objectRef
            forString:(NSString *)string
	 errorDescription:(NSString **)errorDescription
{
	if ( objectRef != NULL )
		*objectRef = string;
	return YES;
}

/************************** stringForObjectValue ******************************/
-(NSString *)stringForObjectValue:(id)object
{
	if ( object == nil )
		return nil;
	if ( [object isKindOfClass:[NSString class]] )
		return object;
	return nil;
}

#if 1
/************************** isPartialStringValid ******************************/
/*
*	Not the greatest, but it will keep the volume name valid.  It most likely
*	is too limiting, and when inserting a lowercase character in the middle of
*	the string the insertion point jumps to the end of the string when it's
*	changed to uppercase.
*/
- (BOOL)isPartialStringValid:(NSString *)partialString
		newEditingString:(NSString * _Nullable *)newString
		errorDescription:(NSString * _Nullable *)error
{
	if (partialString.length > 0)
	{
		unichar	bufferIn[11];
		unichar	bufferOut[11];
		NSUInteger	lengthOut = 0;
		BOOL	changeMade = NO;
		NSUInteger	length = partialString.length;
		if (length > 11)
		{
			changeMade = YES;
			length = 11;
		}
		[partialString getCharacters:bufferIn range:NSMakeRange(0, length)];
		for (NSUInteger i = 0; i < length; i++)
		{
			unichar	thisChar = bufferIn[i];
			if (thisChar == ' ' ||
				(thisChar >= '0' && thisChar <= '9') ||
				(thisChar >= 'a' && thisChar <= 'z') ||
				(thisChar >= 'A' && thisChar <= 'Z'))
			{
				if (thisChar >= 'a' && thisChar <= 'z')
				{
					changeMade = YES;
					thisChar -= ' ';	// Change to uppercase
				}
				bufferOut[lengthOut++] = thisChar;
			} else
			{
				changeMade = YES;
			}
		}
		if (changeMade)
		{
			*newString = [NSString stringWithCharacters:bufferOut length:lengthOut];
			return NO;
		}
	}
	return YES;
}
#else
-(BOOL)isPartialStringValid:(NSString **)partialStringRef
      proposedSelectedRange:(NSRangePointer)proposedSelectedRangeRef
             originalString:(NSString *)originalString
      originalSelectedRange:(NSRange)originalSelectedRange
           errorDescription:(NSString **)errorDescription
{
	NSString *partialString = *partialStringRef;
	if (partialString.length == 0)
	{
		return YES; // Allow the user to clear the field
	}
	
	NSScanner *scanner = [NSScanner scannerWithString:partialString];
	[scanner setCharactersToBeSkipped:nil];
	NSCharacterSet *characterSet = [NSCharacterSet decimalDigitCharacterSet];
	if ( [scanner scanCharactersFromSet:characterSet intoString:NULL] && [scanner isAtEnd] )
		return YES;
	
	// Can't simply return originalString,
	// because of AppKit bug that allows partial string through.
	*partialStringRef = [originalString copy];

	
	NSUInteger endLocation = originalSelectedRange.location + originalSelectedRange.length;
	*proposedSelectedRangeRef = NSMakeRange( endLocation, 0 );
	
	return NO;
}
#endif
@end
