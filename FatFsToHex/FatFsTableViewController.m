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
//  FatFsTableViewController.m
//  FatFsToHex
//
//  Created by Jon Mackey on 1/3/18.
//  Copyright © 2018 Jon Mackey. All rights reserved.
//

#import "FatFsTableViewController.h"

@interface FatFsTableViewController ()

@end

@implementation FatFsTableViewController

NSString *const kNameKey = @"name";
NSString *const kDosNameKey = @"dosName";
NSString *const kSourcePathKey = @"sourcePath";
NSString *const kSourceBMKey = @"sourceBM";
NSString *const kRowPasteboardType = @"kRowPasteboardType";

/****************************** viewDidLoad ***********************************/
- (void)viewDidLoad
{
    [super viewDidLoad];
	[_tableView registerForDraggedTypes:[NSArray arrayWithObjects: NSPasteboardTypeFileURL, kRowPasteboardType, nil]];
   	self.rootFiles = [NSMutableArray array];
   	//self.rootFiles = [NSMutableArray arrayWithContentsOfURL:[[NSBundle mainBundle] URLForResource:@"DummyFiles" withExtension:@"plist"]];
		//[_tableView registerForDraggedTypes:[NSArray arrayWithObjects:[self.arrayController entityName], nil]];

	//[_tableView setDraggingDestinationFeedbackStyle:NSTableViewDraggingDestinationFeedbackStyleRegular];
}

/********************************* keyDown ************************************/
- (void)keyDown:(NSEvent *)inEvent
{
    // Arrow keys are associated with the numeric keypad
    /*fprintf(stderr, "NSEventModifierFlagNumericPad = 0x%X\n", (int)NSEventModifierFlagNumericPad);
    fprintf(stderr, "NSEventModifierFlagFunction = 0x%X\n", (int)NSEventModifierFlagFunction);
    fprintf(stderr, "NSEventModifierFlagFunction = 0x%X, keyCode =0x%hX\n", (int)inEvent.modifierFlags, inEvent.keyCode);*/
    if ([inEvent modifierFlags] == 0x100 &&
    	[inEvent keyCode] == 0x33)
	{
		[self removeSelection:self];
	} else
	{
		[super keyDown:inEvent];
	}
}

/****************************** setRootFiles **********************************/
-(void)setRootFiles:(NSMutableArray<NSDictionary *> *)rootFiles
{
	_rootFiles = rootFiles;
    [self.tableView reloadData];
}

/***************************** removeSelection ********************************/
- (IBAction)removeSelection:(id)sender
{
	NSIndexSet *selection = self.tableView.selectedRowIndexes;
	[self.rootFiles removeObjectsAtIndexes:selection];
    [self.tableView reloadData];
}

/************************ numberOfRowsInTableView *****************************/
- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
	//fprintf(stderr, "numberOfRowsInTableView = %d\n", (int)self.rootFiles.count);
    return(self.rootFiles != NULL ? self.rootFiles.count : 0);
}

/******************************* tableView ************************************/
- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    NSDictionary *dictionary = self.rootFiles[row];
	NSTextField *textField = NULL;
	
    NSString *identifier = tableColumn.identifier;
	NSUInteger index = [@[@"nameCell", @"dosNameCell", @"sourcePathCell"] indexOfObjectPassingTest:
		^BOOL(NSString* inName, NSUInteger inIndex, BOOL *outStop)
		{
			return ([inName isEqualToString:identifier]);
		}];
	if (index != NSNotFound)
	{
		 textField = [tableView makeViewWithIdentifier:identifier owner:self];
		textField.objectValue = dictionary[textField.placeholderString];
    } else
    {
		NSAssert1(NO, @"Unhandled table column identifier %@", identifier);
    }
    return textField;
}

/****************************** draggingEntered *******************************/
- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender
{
	NSPasteboard *pasteboard;
	NSDragOperation sourceDragMask;

	sourceDragMask = [sender draggingSourceOperationMask];
	pasteboard = [sender draggingPasteboard];

	if ( [[pasteboard types] containsObject:NSPasteboardTypeFileURL] )
	{
		//fprintf(stderr, "draggingEntered ");
       /* NSURL *fileURL = [NSURL URLFromPasteboard:pasteboard];
        NSLog(@"extension = %@\n", [fileURL pathExtension]);
        [[fileURL pathExtension] isEqualToString:@"plist"];*/
		if (sourceDragMask & NSDragOperationLink)
		{
			//fprintf(stderr, "NSDragOperationLink\n");
			return NSDragOperationLink;
		} else if (sourceDragMask & NSDragOperationCopy)
		{
			//fprintf(stderr, "NSDragOperationCopy\n");
			return NSDragOperationCopy;
		}
	} else if ([[pasteboard types] containsObject:kRowPasteboardType])
	{
		//fprintf(stderr, "NSDragOperationMove\n");
		return NSDragOperationMove;
	}
	
			//fprintf(stderr, "NSDragOperationNone\n");
	return NSDragOperationNone;
}

/********************* stringByAbbreviatingWithTildeInPath ********************/
/*
*	Cleans up inPath to use a tilda rather than the username.
*	NSString's stringByAbbreviatingWithTildeInPath doesn't work for sandboxed
*	applications because the home directory of a sandboxed app
*	includes the container rather than /Users/un/...  (or maybe it does work,
*	just not how I'd like it to.)
*/
- (NSString*)stringByAbbreviatingWithTildeInPath:inPath
{
	NSArray* homePathComponents = [NSHomeDirectory() pathComponents];
	if (homePathComponents.count >= 3)
	{
		NSString* homePath = [NSString pathWithComponents:[NSArray arrayWithObjects:[homePathComponents objectAtIndex:0], [homePathComponents objectAtIndex:1], [homePathComponents objectAtIndex:2], nil]];
		if ([inPath hasPrefix:homePath])
		{
			inPath = [NSString stringWithFormat:@"~%@", [inPath substringFromIndex:homePath.length]];
		}
	}
	return(inPath);
}
/******************************* clearTable ***********************************/
- (void)clearTable
{
	[self.rootFiles removeAllObjects];
	[self.tableView reloadData];
}

/************************** setDosName:forIndex *******************************/
-(void)setDosName:(NSString*)inDosName forIndex:(NSUInteger)inIndex
{
	if (self.rootFiles && self.rootFiles.count > inIndex)
	{
		NSMutableDictionary* dictionary = [NSMutableDictionary dictionaryWithDictionary:[self.rootFiles objectAtIndex:inIndex]];
		[dictionary setObject:inDosName forKey:kDosNameKey];
		[self.rootFiles replaceObjectAtIndex:inIndex withObject:dictionary];
		[self.tableView reloadData];
	}
}

/******************************* acceptDrop ***********************************/
- (BOOL)tableView:(NSTableView *)tableView acceptDrop:(id<NSDraggingInfo>)sender row:(NSInteger)row dropOperation:(NSTableViewDropOperation)dropOperation
{
	BOOL success = NO;
    NSPasteboard *pasteboard = [sender draggingPasteboard];
	if ( [[pasteboard types] containsObject:NSPasteboardTypeFileURL] )
	{
		success = [self insertFile:[NSURL URLFromPasteboard:pasteboard] atIndex:row];
	} else if ([[pasteboard types] containsObject:kRowPasteboardType])
	{
		NSData* data = [pasteboard dataForType:kRowPasteboardType];
		NSIndexSet*	rowIndexes = [NSKeyedUnarchiver unarchiveObjectWithData:data];
		__block NSInteger	newRow = row;
		[rowIndexes enumerateIndexesUsingBlock:^(NSUInteger inIndex, BOOL *outStop)
			{
 				if (inIndex < row)
 				{
 					newRow--;
 				}
			}];
		NSArray* itemsToMove = [_rootFiles objectsAtIndexes:rowIndexes];
		[_rootFiles removeObjectsAtIndexes:rowIndexes];
		[itemsToMove enumerateObjectsUsingBlock:^(NSDictionary* inItem, NSUInteger inIndex, BOOL *outStop)
			{
				[_rootFiles insertObject:inItem atIndex:newRow++];
			}];

		[self.tableView reloadData];
		success = YES;
	}
	
	return (success);
}

/******************************** addFile *************************************/
- (BOOL)addFile:(NSURL*)inFileURL
{
	return([self insertFile:inFileURL atIndex:-1]);
}

/******************************* insertFile ***********************************/
- (BOOL)insertFile:(NSURL*)inFileURL atIndex:(NSInteger)inRow
{
	//if (![inFileURL hasDirectoryPath])
	{
		NSString* filePath = [inFileURL path];
		NSString*	name = filePath.lastPathComponent;
		NSUInteger index = [self.rootFiles indexOfObjectPassingTest:
            ^BOOL(NSDictionary* inFileRec, NSUInteger inIndex, BOOL *outStop)
            {
            	*outStop = [inFileRec[kNameKey] isEqualToString:name];
            	return (*outStop);
            }];
		if (index == NSNotFound)
		{
			NSString* sourcePath = [self stringByAbbreviatingWithTildeInPath:[[inFileURL path] stringByDeletingLastPathComponent]];
			NSError*	error;
			NSData*	sourceBM = [inFileURL bookmarkDataWithOptions:NSURLBookmarkCreationWithSecurityScope+NSURLBookmarkCreationSecurityScopeAllowOnlyReadAccess
							includingResourceValuesForKeys:NULL relativeToURL:NULL error:&error];
			if (!error)
			{
				NSDictionary* newItem = [NSDictionary dictionaryWithObjectsAndKeys:name, kNameKey, @"", kDosNameKey, sourcePath, kSourcePathKey, sourceBM, kSourceBMKey, nil];
				if (inRow < 0)
				{
					[self.rootFiles addObject:newItem];
				} else
				{
					[self.rootFiles insertObject:newItem atIndex:inRow];
				}
    			[self.tableView reloadData];
			}
			
			return (!error);
		}
	}
	return (NO);
}

/****************************** validateDrop **********************************/
- (NSDragOperation)tableView:(NSTableView*)tableView validateDrop:(id <NSDraggingInfo>)sender proposedRow:(NSInteger)row proposedDropOperation:(NSTableViewDropOperation)dropOperation
{
	//fprintf(stderr, "validateDrop, proposedDropOperation = %lu\n",(unsigned long)dropOperation);

	//Destination is self
	if ([sender draggingSource] == tableView)
	{
		//fprintf(stderr, "destination is self, and row is %li",(long)row);

		return NSDragOperationMove;
	}
	return NSDragOperationLink;
}

/*************************** writeRowsWithIndexes *****************************/
- (BOOL)tableView:(NSTableView *)tableView writeRowsWithIndexes:(NSIndexSet *)rowIndexes toPasteboard:(NSPasteboard *)pasteboard
{
    NSData* data = [NSKeyedArchiver archivedDataWithRootObject:rowIndexes];
    [pasteboard declareTypes:[NSArray arrayWithObject:kRowPasteboardType] owner:self];
    [pasteboard setData:data forType:kRowPasteboardType];
    return YES;
}
@end
