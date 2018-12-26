/*
*	DFPlayer.cpp
*	Copyright (c) 2018 Jonathan Mackey
*
*	Minimal class to control the DFPlayer module / YX5200-24SS chip.
*
*	GNU license:
*	This program is free software: you can redistribute it and/or modify
*	it under the terms of the GNU General Public License as published by
*	the Free Software Foundation, either version 3 of the License, or
*	(at your option) any later version.
*
*	This program is distributed in the hope that it will be useful,
*	but WITHOUT ANY WARRANTY; without even the implied warranty of
*	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
*	GNU General Public License for more details.
*
*	You should have received a copy of the GNU General Public License
*	along with this program.  If not, see <http://www.gnu.org/licenses/>.
*
*	Please maintain this license information along with authorship and copyright
*	notices in any redistribution of this code.
*/
#include <Arduino.h>
#include <DFPlayer.h>

enum DFPLayerPacketOffsets
{
	ePacketStart,
	ePacketVersion,
	ePacketLength,
	ePacketCommand,
	ePacketWantsReply,
	ePacketParam,
	ePacketParamLow,
	ePacketChecksum,
	ePacketChecksumLow,
	ePacketEnd,
	ePacketSize
};

// DFPlayer packet
uint8_t DFPlayer::sPacket[] = {0x7E, 0xFF, 06, 00, 00, 00, 00, 00, 00, 0xEF};

/********************************* DFPlayer ***********************************/
DFPlayer::DFPlayer(
	Stream&	inSerial)
	: mSerial(inSerial), mRingIndex(0), mReplyCommand(0)
{

}

/*********************************** begin ************************************/
void DFPlayer::begin(void)
{
	//Serial.begin(9600);
}

/****************************** CommandCompleted ******************************/
/*
*	Returns the command otherwise zero means not completed (yet).
*/
bool DFPlayer::CommandCompleted(void)
{
	if (mSerial.available())
	{
		uint8_t		thisByte = mSerial.read();
		uint16_t	param;
		mRingBuffer[mRingIndex++] = thisByte;
		if (mRingIndex == sizeof(mRingBuffer))
		{
			mRingIndex = 0;
		}
		if (thisByte == 0xEF)
		{
			mReplyCommand = GetParamsFromRingBuffer(mParam);
		}
	}
	return(mReplyCommand != 0);
}

/****************************** CalculateChecksum *****************************/
uint16_t DFPlayer::CalculateChecksum(
	uint8_t*	inBuffer)
{
	return(-(0x105 + inBuffer[ePacketCommand]
				 + inBuffer[ePacketWantsReply]
				 + inBuffer[ePacketParam]
				 + inBuffer[ePacketParamLow]));
}

/************************** GetParamsFromRingBuffer ***************************/
uint8_t DFPlayer::GetParamsFromRingBuffer(
	uint16_t&	outParam)
{
	uint8_t	command = 0;
	// Quick sanity check to see if 9 bytes earlier there is a 7E
	if (mRingBuffer[mRingIndex] == 0x7E)
	{
		command = mRingBuffer[(mRingIndex+ePacketCommand)%10];
		uint8_t wantsReply = mRingBuffer[(mRingIndex+ePacketWantsReply)%10];
		uint8_t paramH = mRingBuffer[(mRingIndex+ePacketParam)%10];
		uint8_t paramL = mRingBuffer[(mRingIndex+ePacketParamLow)%10];
		uint16_t expectedChecksum = -(0x105 + command  + wantsReply + paramH + paramL);
		uint16_t actualChecksum = (mRingBuffer[(mRingIndex+ePacketChecksum)%10] << 8) + mRingBuffer[(mRingIndex+ePacketChecksumLow)%10];
		if (expectedChecksum == actualChecksum)
		{
			outParam = (paramH << 8) + paramL;
		} else
		{
			command = 0;
		}
		mRingBuffer[mRingIndex] = 0;	// We've already looked at this response
	}
	return(command);
}

/******************************* SerializeUInt16 ******************************/
void DFPlayer::SerializeUInt16(
	uint16_t	inUint16,
	uint8_t*	outArray)
{
	outArray[0] = (uint8_t)(inUint16 >> 8);
	outArray[1] = (uint8_t)inUint16;
}

/******************************** SendCommand *********************************/
void DFPlayer::SendCommand(
	uint8_t inCommand,
	uint16_t inParam,
	bool	inWantsReply)
{
	while (mSerial.available())
	{
		mSerial.read();
	}
	mReplyCommand = 0;	// Used to detect when the command is completed.
	sPacket[ePacketCommand] = inCommand;
	sPacket[ePacketWantsReply] = inWantsReply;
	SerializeUInt16(inParam, &sPacket[ePacketParam]);
	SerializeUInt16(CalculateChecksum(sPacket), &sPacket[ePacketChecksum]);
	mSerial.write(sPacket, 10);
}

