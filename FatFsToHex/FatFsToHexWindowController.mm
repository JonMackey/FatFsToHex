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
//  FatFsToHexWindowController.m
//  FatFsToHex
//
//  Created by Jon Mackey on 1/1/18.
//  Copyright © 2018 Jon Mackey. All rights reserved.
//

#import "FatFsToHexWindowController.h"
#include "StorageAccess.h"

@interface FatFsToHexWindowController ()

@end

@implementation FatFsToHexWindowController

- (void)windowDidLoad
{
    [super windowDidLoad];
	// Get the mainMenu->File menu->open item (tagged 999)
	NSMenuItem *openMenuItem = [[[NSApplication sharedApplication].mainMenu itemAtIndex:1].submenu itemWithTag:999];

	if (openMenuItem)
	{
		// Assign this object as the target.
		openMenuItem.target = self;
		openMenuItem.action = @selector(open:);
	}
	NSMenuItem *saveMenuItem = [[[NSApplication sharedApplication].mainMenu itemAtIndex:1].submenu itemWithTag:888];

	if (saveMenuItem)
	{
		// Assign this object as the target.
		saveMenuItem.target = self;
		saveMenuItem.action = @selector(save:);
	}

	NSMenuItem *addMenuItem = [[[NSApplication sharedApplication].mainMenu itemAtIndex:1].submenu itemWithTag:777];

	if (addMenuItem)
	{
		// Assign this object as the target.
		addMenuItem.target = self;
		addMenuItem.action = @selector(add:);
	}

	NSMenuItem *exportMenuItem = [[[NSApplication sharedApplication].mainMenu itemAtIndex:1].submenu itemWithTag:666];
	if (exportMenuItem)
	{
		// Assign this object as the target.
		exportMenuItem.target = self;
		exportMenuItem.action = @selector(exportHex:);
	}

	NSMenuItem *newMenuItem = [[[NSApplication sharedApplication].mainMenu itemAtIndex:1].submenu itemWithTag:555];
	if (newMenuItem)
	{
		// Assign this object as the target.
		newMenuItem.target = self;
		newMenuItem.action = @selector(newArchive:);
	}

	NSMenuItem *saveAsMenuItem = [[[NSApplication sharedApplication].mainMenu itemAtIndex:1].submenu itemWithTag:444];
	if (saveAsMenuItem)
	{
		// Assign this object as the target.
		saveAsMenuItem.target = self;
		saveAsMenuItem.action = @selector(saveas:);
	}
	if (self.fatFsTableViewController == nil)
	{
		_fatFsTableViewController = [[FatFsTableViewController alloc] initWithNibName:@"FatFsTableViewController" bundle:nil];
		// embed the current view to our host view
		[rootView addSubview:[self.fatFsTableViewController view]];
		
		// make sure we automatically resize the controller's view to the current window size
		[[self.fatFsTableViewController view] setFrame:[rootView bounds]];
	}

	if (self.fatFsSerialViewController == nil)
	{
		_fatFsSerialViewController = [[FatFsSerialViewController alloc] initWithNibName:@"FatFsSerialViewController" bundle:nil];
		// embed the current view to our host view
		[serialView addSubview:[self.fatFsSerialViewController view]];
		
		// make sure we automatically resize the controller's view to the current window size
		[[self.fatFsSerialViewController view] setFrame:[serialView bounds]];
	}
	
	// Create an instance of StorageAccess
	StorageAccess::Create();
	
	//[self doOpen];
}

/******************************** dealloc *************************************/
- (void)dealloc
{
	NSMenuItem *openMenuItem = [[[NSApplication sharedApplication].mainMenu itemAtIndex:1].submenu itemWithTag:999];

	if (openMenuItem)
	{
		// Unassign this object as the open menu item target.
		openMenuItem.target = nil;
		openMenuItem.action = nil;
	}
	
	NSMenuItem *saveMenuItem = [[[NSApplication sharedApplication].mainMenu itemAtIndex:1].submenu itemWithTag:888];

	if (saveMenuItem)
	{
		// Assign this object as the target.
		saveMenuItem.target = nil;
		saveMenuItem.action = nil;
	}

	NSMenuItem *addMenuItem = [[[NSApplication sharedApplication].mainMenu itemAtIndex:1].submenu itemWithTag:777];

	if (addMenuItem)
	{
		// Assign this object as the target.
		addMenuItem.target = nil;
		addMenuItem.action = nil;
	}

	NSMenuItem *exportMenuItem = [[[NSApplication sharedApplication].mainMenu itemAtIndex:1].submenu itemWithTag:666];

	if (exportMenuItem)
	{
		// Assign this object as the target.
		exportMenuItem.target = nil;
		exportMenuItem.action = nil;
	}
	
	NSMenuItem *newMenuItem = [[[NSApplication sharedApplication].mainMenu itemAtIndex:1].submenu itemWithTag:555];
	if (newMenuItem)
	{
		// Assign this object as the target.
		newMenuItem.target = nil;
		newMenuItem.action = nil;
	}
	
	NSMenuItem *saveAsMenuItem = [[[NSApplication sharedApplication].mainMenu itemAtIndex:1].submenu itemWithTag:444];
	if (saveAsMenuItem)
	{
		// Assign this object as the target.
		saveAsMenuItem.target = nil;
		saveAsMenuItem.action = nil;
	}
}

/****************************** createFatFs ***********************************/
- (BOOL)createFatFs
{
	__block BOOL	success = StorageAccess::GetInstance()->Format();
	if (success)
	{
		NSArray*	rootFiles = self.fatFsTableViewController.rootFiles;
		[rootFiles enumerateObjectsUsingBlock:
			^(NSDictionary* inDictionary, NSUInteger inIndex, BOOL *outStop)
			{
				NSURL* fileURL = [NSURL URLByResolvingBookmarkData:
							[inDictionary objectForKey:@"sourceBM"]
								options:NSURLBookmarkResolutionWithoutUI+NSURLBookmarkResolutionWithoutMounting+NSURLBookmarkResolutionWithSecurityScope
									relativeToURL:NULL bookmarkDataIsStale:NULL error:NULL];
				if (fileURL)
				{
					[fileURL startAccessingSecurityScopedResource];
					char	dosName[15];
					// fatPath = NULL = root
					if ([fileURL hasDirectoryPath] ? [self addFolder:fileURL fatPath:nil dosName:dosName] :
						 [self addFile:fileURL fatPath:nil dosName:dosName])
					{
						[[self fatFsTableViewController] setDosName:[NSString stringWithUTF8String:dosName] forIndex:inIndex];
					} else
					{
						success = NO;
						*outStop = YES;
					}
					
					[fileURL stopAccessingSecurityScopedResource];
				} else
				{
					success = NO;
					*outStop = YES;
				}
			}];
	}
	return(success);
}

/********************************* addFile ************************************/
- (BOOL)addFile:(NSURL*)inURL fatPath:(NSString*)inFatPath dosName:(char*)outDosName
{
	char*	fatPath = [self allocUTF8StrFor:inFatPath ? [inFatPath stringByAppendingPathComponent:inURL.path.lastPathComponent] : inURL.path.lastPathComponent];
	char*	path = [self allocUTF8StrFor:inURL.path];
	fprintf(stderr, "%s\n", fatPath);
	BOOL success = StorageAccess::GetInstance()->AddFile(path, fatPath, outDosName);

	delete [] fatPath;
	delete [] path;
	
	return(success);
}

/******************************** addFolder ***********************************/
- (BOOL)addFolder:(NSURL*)inURL fatPath:(NSString*)inFatPath  dosName:(char*)outDosName
{
	NSString*	nsFatPath = inFatPath ? [inFatPath stringByAppendingPathComponent:inURL.path.lastPathComponent] : inURL.path.lastPathComponent;
	char*	fatPath = [self allocUTF8StrFor:nsFatPath];
	fprintf(stderr, "%s\n", fatPath);
	BOOL success = StorageAccess::GetInstance()->CreateFolder(fatPath, outDosName);
	delete [] fatPath;
	
	if (success)
	{
		NSDirectoryEnumerator *directoryEnumerator =
		[[NSFileManager defaultManager] enumeratorAtURL:inURL
			includingPropertiesForKeys:@[NSURLIsDirectoryKey]
				options:NSDirectoryEnumerationSkipsHiddenFiles
					errorHandler:nil];

		[directoryEnumerator skipDescendants];

		for (NSURL* fileURL in directoryEnumerator)
		{
			NSNumber*	isDirectory = nil;
			[fileURL getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:nil];

			success = [isDirectory boolValue] ? [self addFolder:fileURL fatPath:nsFatPath dosName:nil] :
													[self addFile:fileURL fatPath:nsFatPath dosName:nil];
			if (success)
			{
				continue;
			}
			break;
		}
	}
	return(success);
}

/****************************** allocUTF8StrFor *******************************/
- (char*)allocUTF8StrFor:(NSString*)inStr
{
	NSUInteger	strLen = [inStr lengthOfBytesUsingEncoding:NSUTF8StringEncoding] +1;
	char*	utf8Str = new char[strLen];
	[inStr getCString:utf8Str maxLength:strLen encoding:NSUTF8StringEncoding];
	return(utf8Str);
}

/*********************************** save *************************************/
- (IBAction)save:(id)sender
{
	NSURL*	docURL = NULL;
	if (self.savedBM)
	{
		docURL = [NSURL URLByResolvingBookmarkData: self.savedBM
				options:NSURLBookmarkResolutionWithoutUI+NSURLBookmarkResolutionWithoutMounting+NSURLBookmarkResolutionWithSecurityScope
						relativeToURL:NULL bookmarkDataIsStale:NULL error:NULL];
	}
	if (docURL)
	{
		[self doSave:docURL];
	} else
	{
		[self saveas:sender];
	}
}

/******************************** newArchive **********************************/
- (IBAction)newArchive:(id)sender
{
	// Test for dirty, warn user of potential loss... TBD
	
	self.archivePath = @"";
	self.savedBM = NULL;
	[self.fatFsTableViewController clearTable];
}

/********************************* sendFatFs **********************************/
- (IBAction)sendFatFs:(id)sender
{
	if ([self.fatFsSerialViewController portIsOpen:YES])
	{
		NSError *error;
		NSString *globallyUniqueString = [[NSProcessInfo processInfo] globallyUniqueString];
		NSString *tempDirectoryPath = [NSTemporaryDirectory() stringByAppendingPathComponent:globallyUniqueString];
		NSURL *tempDirectoryURL = [NSURL fileURLWithPath:tempDirectoryPath isDirectory:YES];
		[[NSFileManager defaultManager] createDirectoryAtURL:tempDirectoryURL withIntermediateDirectories:YES attributes:nil error:&error];
		if (error)
		{
			[self.fatFsSerialViewController postErrorString:error.localizedDescription];
		} else
		{
			NSURL* docURL = [NSURL fileURLWithPath:@"temp.hex" relativeToURL:tempDirectoryURL];
			if ([self exportHexFile:docURL])
			{
				[self.fatFsSerialViewController sendHexFile:docURL];
			}
			[[NSFileManager defaultManager] removeItemAtURL:tempDirectoryURL error:&error];
			if (error)
			{
				[self.fatFsSerialViewController postErrorString:error.localizedDescription];
			}
		}
	}
}

/******************************* exportHexFile ********************************/
- (BOOL)exportHexFile:(NSURL*)inDocURL
{
	BOOL	success = NO;
	if (inDocURL)
	{
		if ([self createFatFs])
		{
			char*	path = [self allocUTF8StrFor:inDocURL.path];
			success = StorageAccess::GetInstance()->SaveToHexFile(path);
			delete [] path;
		}
	}
	return(success);
}

/********************************* exportHex **********************************/
- (IBAction)exportHex:(id)sender
{
	NSURL*	docURL = NULL;
	NSData*	docURLBM = [[NSUserDefaults standardUserDefaults] objectForKey:@"docURLBM"];
	if (docURLBM)
	{
		docURL = [NSURL URLByResolvingBookmarkData: docURLBM
				options:NSURLBookmarkResolutionWithoutUI+NSURLBookmarkResolutionWithoutMounting+NSURLBookmarkResolutionWithSecurityScope
						relativeToURL:NULL bookmarkDataIsStale:NULL error:NULL];
	}
	NSURL*	baseURL = docURL ? [NSURL fileURLWithPath:[[docURL path] stringByDeletingLastPathComponent] isDirectory:YES] : NULL;
	NSString*	initialName = docURL ? [[[docURL path] lastPathComponent] stringByDeletingPathExtension] : @"Untitled";
	NSSavePanel*	savePanel = [NSSavePanel savePanel];
	if (savePanel)
	{
		savePanel.directoryURL = baseURL;
		savePanel.allowedFileTypes = @[@"hex"];
		savePanel.nameFieldStringValue = initialName;
		[savePanel beginSheetModalForWindow:self.window completionHandler:^(NSInteger result)
		{
			if (result == NSModalResponseOK)
			{
				NSURL* docURL = savePanel.URL;
				[docURL startAccessingSecurityScopedResource];
				[self exportHexFile:docURL];
				[docURL stopAccessingSecurityScopedResource];
			}
		}];
	}
}

/********************************* saveas *************************************/
- (IBAction)saveas:(id)sender
{
	NSURL*	docURL = NULL;
	NSData*	docURLBM = [[NSUserDefaults standardUserDefaults] objectForKey:@"docURLBM"];
	if (docURLBM)
	{
		docURL = [NSURL URLByResolvingBookmarkData: docURLBM
				options:NSURLBookmarkResolutionWithoutUI+NSURLBookmarkResolutionWithoutMounting+NSURLBookmarkResolutionWithSecurityScope
						relativeToURL:NULL bookmarkDataIsStale:NULL error:NULL];
	}
	NSURL*	baseURL = docURL ? [NSURL fileURLWithPath:[[docURL path] stringByDeletingLastPathComponent] isDirectory:YES] : NULL;
	NSString*	initialName = docURL ? [[[docURL path] lastPathComponent] stringByDeletingPathExtension] : @"Untitled";
	NSSavePanel*	savePanel = [NSSavePanel savePanel];
	if (savePanel)
	{
		savePanel.directoryURL = baseURL;
		savePanel.allowedFileTypes = @[@"sfl2"];
		savePanel.nameFieldStringValue = initialName;
		[savePanel beginSheetModalForWindow:self.window completionHandler:^(NSInteger result)
		{
			if (result == NSModalResponseOK)
			{
				NSURL* docURL = savePanel.URL;
				if (docURL)
				{
					[self doSave:docURL];
				}
			}
		}];
	}
}

/********************************* doSave *************************************/
- (void)doSave:(NSURL*)inDocURL
{
	if (inDocURL)
	{
		[inDocURL startAccessingSecurityScopedResource];
		NSMutableDictionary* docDict = [NSMutableDictionary dictionary];
		NSString*	label = [[NSUserDefaults standardUserDefaults] objectForKey:@"volumeName"];
		NSNumber*	blockSize = [[NSUserDefaults standardUserDefaults] objectForKey:@"blockSize"];
		NSNumber*	pageSize = [[NSUserDefaults standardUserDefaults] objectForKey:@"pageSize"];
		NSNumber*	volumeSize = [[NSUserDefaults standardUserDefaults] objectForKey:@"volumeSize"];
		[docDict setObject:label forKey:@"volumeName"];
		[docDict setObject:blockSize forKey:@"blockSize"];
		[docDict setObject:pageSize forKey:@"pageSize"];
		[docDict setObject:volumeSize forKey:@"volumeSize"];
		[docDict setObject:_fatFsTableViewController.rootFiles forKey:@"rootFiles"];
		[NSKeyedArchiver archiveRootObject:docDict toFile:[inDocURL path]];
		[inDocURL stopAccessingSecurityScopedResource];
		NSError*	error;
		self.savedBM = [inDocURL bookmarkDataWithOptions:NSURLBookmarkCreationWithSecurityScope
				includingResourceValuesForKeys:NULL relativeToURL:NULL error:&error];
		[[NSUserDefaults standardUserDefaults] setObject:self.savedBM forKey:@"docURLBM"];
		self.archivePath = inDocURL.path;
		if (error)
		{
			NSLog(@"-doSave- %@\n", error);
		}
	}
}

/********************************** open **************************************/
- (IBAction)open:(id)sender
{
	NSURL*	baseURL = NULL;
	NSData*	docURLBM = [[NSUserDefaults standardUserDefaults] objectForKey:@"docURLBM"];
	if (docURLBM)
	{
		baseURL = [NSURL URLByResolvingBookmarkData: docURLBM
								options:NSURLBookmarkResolutionWithoutUI+NSURLBookmarkResolutionWithoutMounting+NSURLBookmarkResolutionWithSecurityScope
									relativeToURL:NULL bookmarkDataIsStale:NULL error:NULL];
		baseURL = [NSURL fileURLWithPath:[[baseURL path] stringByDeletingLastPathComponent] isDirectory:YES];
	}
	NSOpenPanel*	openPanel = [NSOpenPanel openPanel];
	if (openPanel)
	{
		[openPanel setCanChooseDirectories:NO];
		[openPanel setCanChooseFiles:YES];
		[openPanel setAllowsMultipleSelection:NO];
		openPanel.directoryURL = baseURL;
		openPanel.allowedFileTypes = @[@"sfl2"];
		[openPanel beginSheetModalForWindow:self.window completionHandler:^(NSInteger result)
		{
			if (result == NSModalResponseOK)
			{
				NSArray* urls = [openPanel URLs];
				if ([urls count] == 1)
				{
					[[NSUserDefaults standardUserDefaults]
						setObject:[urls[0] bookmarkDataWithOptions:NSURLBookmarkCreationWithSecurityScope
							includingResourceValuesForKeys:NULL relativeToURL:NULL error:NULL]
								forKey:@"docURLBM"];
					[self doOpen];
				}
			}
		}];
	}
}

/********************************* doOpen *************************************/
- (void)doOpen
{
	self.savedBM = [[NSUserDefaults standardUserDefaults] objectForKey:@"docURLBM"];
	NSURL*	docURL = [NSURL URLByResolvingBookmarkData:
	 					self.savedBM
	 						options:NSURLBookmarkResolutionWithoutUI+NSURLBookmarkResolutionWithoutMounting+NSURLBookmarkResolutionWithSecurityScope
	 							relativeToURL:NULL bookmarkDataIsStale:NULL error:NULL];
	[docURL startAccessingSecurityScopedResource];
	NSDictionary* docDict = [NSKeyedUnarchiver unarchiveObjectWithFile:[docURL path]];
	[docURL stopAccessingSecurityScopedResource];
	if (docDict)
	{
		NSString*	label = [docDict objectForKey:@"volumeName"];
		NSNumber*	blockSize = [docDict objectForKey:@"blockSize"];
		NSNumber*	pageSize = [docDict objectForKey:@"pageSize"];
		NSNumber*	volumeSize = [docDict objectForKey:@"volumeSize"];
		[[NSUserDefaults standardUserDefaults] setObject:label forKey:@"volumeName"];
		[[NSUserDefaults standardUserDefaults] setObject:blockSize forKey:@"blockSize"];
		[[NSUserDefaults standardUserDefaults] setObject:pageSize forKey:@"pageSize"];
		[[NSUserDefaults standardUserDefaults] setObject:volumeSize forKey:@"volumeSize"];
		self.fatFsTableViewController.rootFiles = [NSMutableArray arrayWithArray:[docDict objectForKey:@"rootFiles"]];
		self.archivePath = docURL.path;
	}
}

/********************************** add **************************************/
- (IBAction)add:(id)sender
{
	NSOpenPanel*	openPanel = [NSOpenPanel openPanel];
	if (openPanel)
	{
		[openPanel setCanChooseDirectories:NO];
		[openPanel setCanChooseFiles:YES];
		[openPanel setAllowsMultipleSelection:NO];
		[openPanel beginSheetModalForWindow:self.window completionHandler:^(NSInteger result)
		{
			if (result == NSModalResponseOK)
			{
				NSArray* urls = [openPanel URLs];
				if ([urls count] == 1)
				{
					[self.fatFsTableViewController addFile:urls[0]];
				}
			}
		}];
	}
}


@end
