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
//  StorageAccess.h
//  FatFsToHex
//
//  Created by Jon Mackey on 1/1/18.
//  Copyright © 2018 Jon Mackey. All rights reserved.
//

#ifndef StorageAccess_h
#define StorageAccess_h

#include <stdio.h>
#include <map>
#include "FatFs/diskio.h"
#include "FatFs/ff.h"

typedef std::map<uint32_t, uint8_t*>	BlockMap;

class StorageAccess
{
public:
							StorageAccess(void);
							~StorageAccess(void);
	static void				Create(void);
	static void				Release(void);
	void					Alloc(void);
	void					Dealloc(void);
	static StorageAccess*	GetInstance(void)
								{return(sInstance);}
	DSTATUS					GetDiskStatus(void);
	DSTATUS					InitializeDisk(void);
	DRESULT					DiskRead(
								DWORD					inSector,
								UINT					inCount,
								BYTE*					outBuffer);
	DRESULT 				DiskWrite(
								DWORD					inSector,
								UINT					inCount,
								const BYTE*				inBuffer);
	DRESULT					DiskIoctl(
								BYTE					inCommand,
								void*					inBuffer);
	uint8_t*				GetBlock(
								uint32_t				inBlockIndex,
								bool					inCreateIfUndefined = false);
	uint32_t				GetHighestBlockIndex(void) const;
	uint32_t				GetMaxBlockIndex(void) const
								{return(mVolumeSize/mBlockSize);}
	uint32_t				GetBlockSize(void) const
								{return(mBlockSize);}
	uint32_t				GetPageSize(void) const
								{return(mPageSize);}
	uint32_t				GetVolumeSize(void) const
								{return(mVolumeSize);}
	bool					SaveToHexFile(
								const char*				inPath);
	bool					SaveToFile(
								const char*				inPath);
	bool					Format(void);
	bool					AddFile(
								const char*				inSrcPath,
								const char*				inDstPath,
								char*					outDosName);
	bool					CreateFolder(
								const char*				inDstPath,
								char*					outDosName);
	bool					Begin(void);
protected:
	static StorageAccess*	sInstance;
	uint32_t	mBlockSize;
	uint32_t	mPageSize;
	uint32_t	mVolumeSize;
	BlockMap	mBlockMap;
	static const size_t kBufferSize;
	uint8_t*	mBuffer;
	FATFS		mFatFs;
	
	void					ClearBlockMap(void);
};
#endif /* StorageAccess_h */
