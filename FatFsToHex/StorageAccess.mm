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
//  StorageAccess.mm
//  FatFsToHex
//
//  Created by Jon Mackey on 1/1/18.
//  Copyright © 2018 Jon Mackey. All rights reserved.
//
#import <Cocoa/Cocoa.h>
#include "StorageAccess.h"

StorageAccess*	StorageAccess::sInstance = NULL;
const size_t StorageAccess::kBufferSize = 4096;
// HEX_LINE_DATA_LEN was hard coded as 32.  32 results in a 76 byte hex line
// length that has the potential of overwriting the 64 byte Arduino serial
// ring buffer.  This is probably why the Arduino ISP uses 16 data bytes which
// results in a 44 byte hex line.
#define HEX_LINE_DATA_LEN	16

enum EIntelHexRecordType
{
	eRecordTypeData,		// 0
	eRecordTypeEOF,			// 1
	eRecordTypeExSegAddr,	// 2
	eRecordTypeStSegAddr,	// 3
	eRecordTypeExLinAddr,	// 4
	eRecordTypeStLinAddr	// 5
};

/***************************** StorageAccess **********************************/
StorageAccess::StorageAccess(void)
	: mBlockSize(0), mBuffer(NULL)
{
}

/***************************** ~StorageAccess *********************************/
StorageAccess::~StorageAccess(void)
{

}

/******************************* Initialize ***********************************/
void StorageAccess::Create(void)
{
	if (sInstance == NULL)
	{
		sInstance = new StorageAccess;
		sInstance->Alloc();
	}
}

/********************************* Release ************************************/
void StorageAccess::Release(void)
{
	if (sInstance)
	{
		sInstance->Dealloc();
		delete sInstance;
		sInstance = NULL;
	}
}

/********************************** Alloc *************************************/
void StorageAccess::Alloc(void)
{
	mBuffer = new uint8_t[4096];
}

/********************************* Dealloc ************************************/
void StorageAccess::Dealloc(void)
{
	if (mBuffer)
	{
		delete [] mBuffer;
		mBuffer = NULL;
	}
	ClearBlockMap();
}

/********************************** Format ************************************/
bool StorageAccess::Format(void)
{
	ClearBlockMap();
	// Partition the flash with 1 partition that takes the entire space.
#ifdef DEBUG
	fprintf(stderr, "Partitioning flash with 1 primary partition...\n");
#endif
	DWORD szt[] = {100, 0, 0, 0};  // 1 primary partition with 100% of space.
	memset(mBuffer, 0, kBufferSize);
	FRESULT r = f_fdisk(0, szt, mBuffer);
	if (r == FR_OK)
	{
#ifdef DEBUG
		fprintf(stderr, "Partitioned flash!\n");
		// Make filesystem.
		fprintf(stderr, "Creating and formatting FAT filesystem...\n");
#endif
		r = f_mkfs("", FM_ANY, 0, mBuffer, kBufferSize);
		if (r == FR_OK)
		{
#ifdef DEBUG
			fprintf(stderr, "Formatted flash!\n");
#endif
			// Finally test that the filesystem can be mounted.
			if (Begin())
			{
				NSString*	label = [[NSUserDefaults standardUserDefaults] objectForKey:@"volumeName"];
				if (label &&
					label.length)
				{
					char labelName[20];
					[label getCString:labelName maxLength:20 encoding:NSUTF8StringEncoding];
					r = f_setlabel(labelName);
#ifdef DEBUG
					if (r == FR_OK)
					{
						fprintf(stderr, "Volume label set to \"%s\".\n", labelName);
					} else
					{
						fprintf(stderr, "Error, failed to set volume label to \"%s\"!,  error code: %d\n", labelName, (int)r);
					}
#endif
				}
#ifdef DEBUG
			} else
			{
				fprintf(stderr, "Error, failed to mount newly formatted filesystem!\n");
#endif
			}
#ifdef DEBUG
		} else
		{
			fprintf(stderr, "Error, f_mkfs failed with error code: %d\n", (int)r);
#endif
		}
#ifdef DEBUG
	} else
	{
		fprintf(stderr, "Error, f_fdisk failed with error code: %d\n", (int)r);
#endif
	}
	return(r == FR_OK);
}

/********************************* AddFile ************************************/
bool StorageAccess::AddFile(
	const char*	inSrcPath,
	const char*	inDstPath,
	char*		outDosName)
{
	FRESULT r = FR_OK;
	FILE*    file = fopen(inSrcPath, "r");
	if (file)
	{
		if (Begin())
		{
			FIL	fp;
			r = f_open (&fp, inDstPath, FA_CREATE_NEW+FA_WRITE);
			if (r == FR_OK)
			{
				size_t bytesRead = fread(mBuffer, 1, kBufferSize, file);
				size_t	totalBytesRead = bytesRead;
				UINT	bytesWritten;
				UINT	totalBytesWritten = 0;
				while (bytesRead > 0)
				{
					r = f_write(&fp, mBuffer, (UINT)bytesRead, &bytesWritten);
					if (r == FR_OK)
					{
						totalBytesWritten += bytesWritten;
						bytesRead = fread(mBuffer, 1, kBufferSize, file);
						totalBytesRead += bytesRead;
						continue;
					}
					break;
				}
#ifdef DEBUG
				fprintf(stderr, "Bytes read = %d, bytes written = %d\n", (int)totalBytesRead, totalBytesWritten);
#endif
				f_close(&fp);
				if (r == FR_OK &&
					outDosName)
				{
					FILINFO	fileInfo;
					r = f_stat(inDstPath, &fileInfo);
					if (r == FR_OK)
					{
						memcpy(outDosName, fileInfo.altname, FF_SFN_BUF + 1);
					}
				}
#ifdef DEBUG
			} else
			{
				fprintf(stderr, "f_open failed with error code: %d\n", (int)r);
#endif
			}
		}
		fclose(file);
	}
	return(r == FR_OK);
}

/****************************** CreateFolder **********************************/
bool StorageAccess::CreateFolder(
	const char*	inDstPath,
	char*		outDosName)
{
	FRESULT r = FR_MKFS_ABORTED;
	if (Begin())
	{
		r = f_mkdir(inDstPath);
		if (r == FR_OK &&
			outDosName)
		{
			FILINFO	fileInfo;
			r = f_stat(inDstPath, &fileInfo);
			if (r == FR_OK)
			{
				memcpy(outDosName, fileInfo.altname, FF_SFN_BUF + 1);
			}
		}
	}
	return(r == FR_OK);
}

static const char kHexChars[] = "0123456789ABCDEF";
/******************************** Int8ToHexStr ********************************/
/*
*	Returns hex8 str with leading zeros (0x0 would return 00, 0x1 01)
*/
char* Int8ToHexStr(
	uint8_t	inNum,
	char*	inBuffer)
{
	char*	bufPtr = &inBuffer[1];
	for (; bufPtr >= inBuffer; bufPtr--)
	{
		*bufPtr =  kHexChars[inNum & 0xF];
		inNum >>= 4;
	}
	return(&inBuffer[2]);
}

/**************************** ToIntelHexLine **********************************/
// https://en.wikipedia.org/wiki/Intel_HEX
size_t ToIntelHexLine(
	const uint8_t*	inData,
	uint8_t			inDataLen,
	uint16_t		inAddress,
	uint8_t			inRecordType,
	char*			inLineBuffer)
{
	uint8_t	checksum = inDataLen;
	uint8_t	thisByte = 0;

	inLineBuffer[0] = ':';
	char* nextHexBytePtr = Int8ToHexStr(inDataLen, &inLineBuffer[1]);
	if (inRecordType != eRecordTypeExLinAddr)
	{
		thisByte = inAddress >> 8;
		nextHexBytePtr = Int8ToHexStr(thisByte, nextHexBytePtr);
		checksum += thisByte;
		thisByte = inAddress & 0xFF;
		nextHexBytePtr = Int8ToHexStr(thisByte, nextHexBytePtr);
		checksum += thisByte;
		nextHexBytePtr = Int8ToHexStr(inRecordType, nextHexBytePtr);
		checksum += inRecordType;
		for (uint8_t i = 0; i < inDataLen; i++)
		{
			thisByte = inData[i];
			nextHexBytePtr = Int8ToHexStr(thisByte, nextHexBytePtr);
			checksum += thisByte;
		}
	// Else it's record type 4, 'Extended Linear Address'
	} else
	{
		nextHexBytePtr = Int8ToHexStr(0, nextHexBytePtr);
		nextHexBytePtr = Int8ToHexStr(0, nextHexBytePtr);
		nextHexBytePtr = Int8ToHexStr(eRecordTypeExLinAddr, nextHexBytePtr);
		checksum += eRecordTypeExLinAddr;
		thisByte = inAddress >> 8;
		nextHexBytePtr = Int8ToHexStr(thisByte, nextHexBytePtr);
		checksum += thisByte;
		thisByte = inAddress & 0xFF;
		nextHexBytePtr = Int8ToHexStr(thisByte, nextHexBytePtr);
		checksum += thisByte;
	}
	nextHexBytePtr = Int8ToHexStr(-checksum, nextHexBytePtr);
	*(nextHexBytePtr++) = '\n';
	*nextHexBytePtr = 0;
	return(nextHexBytePtr-inLineBuffer);
}

/**************************** LineIsEmpty **********************************/
bool LineIsEmpty(
	const uint8_t*	inData,
	uint8_t			inDataLen)
{
	for (uint8_t i = 0; i < inDataLen; i++)
	{
		if (inData[i] == 0)
		{
			continue;
		}
		return(false);
	}
	return(true);
}

/*************************** GetHighestBlockIndex *****************************/
/*
*	Used to determine how much space has been used in the FS.
*/
uint32_t StorageAccess::GetHighestBlockIndex(void) const
{
	BlockMap::const_reverse_iterator	itr = mBlockMap.rbegin();
	BlockMap::const_reverse_iterator	itrEnd = mBlockMap.rend();
	return(itr != itrEnd ? itr->first : 0);
}

/****************************** SaveToHexFile *********************************/
bool StorageAccess::SaveToHexFile(
	const char*	inPath)
{
	bool success = false;
	FILE*    file = fopen(inPath, "w");
	if (file)
	{
		BlockMap::iterator	itr = mBlockMap.begin();
		BlockMap::iterator	itrEnd = mBlockMap.end();
		char		hexLine[90];
		uint32_t	address = 0;
		uint32_t	baseAddress = 0;
		uint32_t	upperAddress = 0;
		uint32_t	lastUpperAddress = 0;
		uint8_t*	dataPtr;
		bool		entireBlockIsNull;
		size_t		lineLength;
		
		for (; itr != itrEnd; ++itr)
		{
			dataPtr = itr->second;
			address = itr->first * mBlockSize;
			baseAddress = address % 0x10000;
			/*
			*	The Intel hex format address field is only 16 bits.  When the
			*	address moves to the next block of 65535 bytes you need to write
			*	an address record that all data records will offset from.
			*/
			upperAddress = address / 0x10000;
			if (upperAddress != lastUpperAddress)
			{
				lastUpperAddress = upperAddress;
				lineLength = ToIntelHexLine(NULL, 2, upperAddress, eRecordTypeExLinAddr, hexLine);
				fwrite(hexLine, 1, lineLength, file);
			}
			entireBlockIsNull = true;
			for (uint32_t offset = 0; offset < mBlockSize; offset += HEX_LINE_DATA_LEN)
			{
				if (!LineIsEmpty(&dataPtr[offset], HEX_LINE_DATA_LEN))
				{
					entireBlockIsNull = false;
					lineLength = ToIntelHexLine(&dataPtr[offset], HEX_LINE_DATA_LEN, baseAddress + offset, eRecordTypeData, hexLine);
					fwrite(hexLine, 1, lineLength, file);
				}
			}
			/*
			*	If the entire block is null THEN
			*	write a single byte data line so that the reader will know to
			*	zero the entire block.
			*/
			if (entireBlockIsNull)
			{
				//fprintf(stderr, "entireBlockIsNull = %X\n", address);
				lineLength = ToIntelHexLine(dataPtr, 1, baseAddress, eRecordTypeData, hexLine);
				fwrite(hexLine, 1, lineLength, file);
			}
		}
		lineLength = ToIntelHexLine(dataPtr, 0, 0, eRecordTypeEOF, hexLine);
		fwrite(hexLine, 1, lineLength, file);
		fclose(file);
		success = true;
	}
	return(success);
}

/********************************* SaveToFile *********************************/
bool StorageAccess::SaveToFile(
	const char*	inPath)
{
	bool success = false;
	FILE*    file = fopen(inPath, "w");
	if (file)
	{
		BlockMap::iterator	itr = mBlockMap.begin();
		BlockMap::iterator	itrEnd = mBlockMap.end();
		/*
		*	FatFs only initializes blocks that it uses.  The block map indexes
		*	may have gaps of unused blocks.   The blocks that aren't used need
		*	to be written to the file.  These blocks could be written as random
		*	data but this would limit the optimization of anything that copies
		*	the file.  It also makes the file less readable for debugging.  For
		*	this reason empty blocks are zeroed.
		*/
		uint32_t	nextBlockIndex = 0;
		uint8_t*	emptyBlock = new uint8_t[mBlockSize];
		memset(emptyBlock, 0, mBlockSize);
		for (; itr != itrEnd; ++itr)
		{
			uint32_t	emptyBlocks = itr->first - nextBlockIndex;
			if (emptyBlocks)
			{
				for (uint32_t i = 0; i < emptyBlocks; i++)
				{
					fwrite(emptyBlock, 1, mBlockSize, file);
				}
			}
			nextBlockIndex = itr->first+1;
			fwrite(itr->second, 1, mBlockSize, file);
		}
		delete [] emptyBlock;
		fclose(file);
		success = true;
	}
	return(success);
}

/********************************** Begin *************************************/
bool StorageAccess::Begin(void)
{
	// Mount the filesystem.
	FRESULT r = f_mount(&mFatFs, "", 1);
	if (r != FR_OK)
	{
#ifdef DEBUG
		fprintf(stderr, "f_mount failed with error code: %d\n", (int)r);
#endif
		return false;
	}
#ifdef DEBUG
	fprintf(stderr, "Volume mounted!\n");
#endif
	return true;
}

/****************************** ClearBlockMap *********************************/
void StorageAccess::ClearBlockMap(void)
{
	BlockMap::iterator	itr = mBlockMap.begin();
	BlockMap::iterator	itrEnd = mBlockMap.end();
	for (; itr != itrEnd; ++itr)
	{
		delete [] itr->second;
		itr->second = NULL;
	}
	mBlockMap.clear();
	mBlockSize = 0;
#ifdef DEBUG
	fprintf(stderr, "ClearBlockMap - cleared\n");
#endif
}

/****************************** GetDiskStatus *********************************/
DSTATUS StorageAccess::GetDiskStatus(void)
{
	return(0);
}

/***************************** InitializeDisk *********************************/
DSTATUS StorageAccess::InitializeDisk(void)
{
	NSNumber*	blockSize = [[NSUserDefaults standardUserDefaults] objectForKey:@"blockSize"];
	mBlockSize = blockSize.intValue;
	NSNumber*	pageSize = [[NSUserDefaults standardUserDefaults] objectForKey:@"pageSize"];
	mPageSize = pageSize.intValue;
	NSNumber*	volumeSize = [[NSUserDefaults standardUserDefaults] objectForKey:@"volumeSize"];
	mVolumeSize = volumeSize.intValue * 0x100000;
#ifdef DEBUG
	fprintf(stderr, "InitializeDisk mBlockSize = %d, mPageSize = %d, mVolumeSize = %d\n", mBlockSize, mPageSize, mVolumeSize);
#endif
	return(0);
}

/******************************** GetBlock ************************************/
uint8_t* StorageAccess::GetBlock(
	uint32_t	inBlockIndex,
	bool		inCreateIfUndefined)
{
	uint8_t*	blockPtr = NULL;
	BlockMap::iterator	itr = mBlockMap.find(inBlockIndex);
	if (itr != mBlockMap.end())
	{
		blockPtr = itr->second;
	} else if (inCreateIfUndefined)
	{
		blockPtr = new uint8_t[mBlockSize];
		memset(blockPtr, 0, mBlockSize);
		mBlockMap.insert(BlockMap::value_type(inBlockIndex, blockPtr));
	}
	return(blockPtr);
}

/********************************* DiskRead *************************************/
DRESULT StorageAccess::DiskRead(
	DWORD	inSector,
	UINT	inCount,
	BYTE*	outBuffer)
{
#ifdef DEBUG
	fprintf(stderr, "DiskRead(%X, %d)\n", (int)inSector, (int)inCount);
#endif
	uint8_t*	bufferPtr = outBuffer;
	uint8_t*	blockPtr;
	for (uint32_t i = 0; i < inCount; i++)
	{
		blockPtr = GetBlock((uint32_t)inSector+i);
		if (blockPtr)
		{
			memcpy(bufferPtr, blockPtr, mBlockSize);
		} else
		{
			memset(bufferPtr, 0, mBlockSize);
		}
		bufferPtr += mBlockSize;
	}
	return(RES_OK);
}

/********************************* DiskWrite ************************************/
DRESULT StorageAccess::DiskWrite(
	DWORD		inSector,
	UINT		inCount,
	const BYTE*	inBuffer)
{
#ifdef DEBUG
	fprintf(stderr, "DiskWrite(%X, %d)\n", (int)inSector, (int)inCount);
#endif
	const uint8_t*	bufferPtr = inBuffer;
	uint8_t*	blockPtr;
	for (uint32_t i = 0; i < inCount; i++)
	{
		blockPtr = GetBlock((uint32_t)inSector+i, true);
		if (blockPtr)
		{
			memcpy(blockPtr, bufferPtr, mBlockSize);
		}
		bufferPtr += mBlockSize;
	}
	return(RES_OK);
}

/********************************* DiskIoctl ************************************/
DRESULT StorageAccess::DiskIoctl(
	BYTE	inCommand,
	void*	inBuffer)
{
	/*
	*	See http://elm-chan.org/fsw/ff/doc/dioctl.html
	*/
	switch(inCommand)
	{
		case CTRL_SYNC:
			// Not used.
			break;
		case GET_SECTOR_COUNT:
		{
			/*
			*	Returns number of available sectors on the drive into the DWORD
			*	variable pointed by buff. This command is used in only f_mkfs and
			*	f_fdisk function to determine the volume/partition size to be
			*	created. Required at FF_USE_MKFS == 1 or FF_MULTI_PARTITION == 1.
			*/
			*(DWORD*)inBuffer = mVolumeSize/mBlockSize;
			break;
		}
		case GET_SECTOR_SIZE:
		{
			/*
			*	Returns sector size of the device into the WORD variable pointed by
			*	buff. Valid return values for this command are 512, 1024, 2048 and
			*	4096. This command is required only if FF_MAX_SS > FF_MIN_SS. When
			*	FF_MAX_SS == FF_MIN_SS, this command is never used and the device
			*	must work at that sector size.
			*/
			*(WORD*)inBuffer = mBlockSize;
			break;
		}
		case GET_BLOCK_SIZE:
		{
			/*
			*	Returns the erase block size of the device memory media in unit of
			*	sector into the DWORD variable pointed by buff. The allowable value
			*	is 1 to 32768 in power of 2. Return 1 if the erase block size is
			*	unknown or non flash memory media. This command is used by only
			*	f_mkfs function and it attempts to align data area on the erase
			*	block boundary. Required at FF_USE_MKFS == 1
			*/
			*(DWORD*)inBuffer = mPageSize/mBlockSize;
			break;
		}
		case CTRL_TRIM:
			// Not used
			break;
	}
	return (RES_OK);
}

// Basic partitioning scheme for when fdisk and mkfs are used to format the
// flash.  This just creates one partition on the flash drive, see more
// details in FatFs docs:
//   http://elm-chan.org/fsw/ff/en/fdisk.html
PARTITION VolToPart[] = {
  {0, 0},    /* "0:" ==> Physical drive 0, 1st partition */
  // {1, 0},     // Logical drive 1 ==> Physical drive 1 (auto detection)
  // {2, 0},     // Logical drive 2 ==> Physical drive 2 (auto detection)
  // {3, 0},     // Logical drive 3 ==> Physical drive 3 (auto detection)
  // /*
  // {0, 2},     // Logical drive 2 ==> Physical drive 0, 2nd partition
  // {0, 3},     // Logical drive 3 ==> Physical drive 0, 3rd partition
  // */
};

DSTATUS disk_status(BYTE pdrv)
{
	if (StorageAccess::GetInstance() == NULL)
	{
		return (STA_NOINIT);
	} else
	{
		return (StorageAccess::GetInstance()->GetDiskStatus());
	}
}

DSTATUS disk_initialize(
	BYTE	inDriveIndex)
{
	if (StorageAccess::GetInstance() == NULL)
	{
		return (STA_NOINIT);
	} else
	{
		return (StorageAccess::GetInstance()->InitializeDisk());
	}
}

DRESULT disk_read(
	BYTE	inDriveIndex,
	BYTE*	outBuffer,
	DWORD	inSector,
	UINT	inCount)
{
	if (StorageAccess::GetInstance() == NULL)
	{
		return (RES_NOTRDY);
	} else
	{
		return (StorageAccess::GetInstance()->DiskRead(inSector, inCount, outBuffer));
	}
}

DRESULT disk_write(
	BYTE		inDriveIndex,
	const BYTE*	inBuffer,
	DWORD		inSector,
	UINT		inCount)
{
	if (StorageAccess::GetInstance() == NULL)
	{
		return (RES_NOTRDY);
	} else
	{
		return (StorageAccess::GetInstance()->DiskWrite(inSector, inCount, inBuffer));
	}
}

DRESULT disk_ioctl(
	BYTE	inDriveIndex,
	BYTE	inCommand,
	void*	inBuffer)
{
	if (StorageAccess::GetInstance() == NULL)
	{
		return (RES_NOTRDY);
	} else
	{
		return (StorageAccess::GetInstance()->DiskIoctl(inCommand, inBuffer));
	}
}


