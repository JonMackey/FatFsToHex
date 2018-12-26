/*
*	DFPlayer.h
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
#ifndef DFPlayer_H
#define DFPlayer_H

#include <Stream.h>

class DFPlayer
{
public:
							DFPlayer(
								Stream&					inSerial);
	void					begin(void);

	void					SendCommand(
								uint8_t					inCommand,
								uint16_t				inParam,
								bool					inWantsReply = false);
							/*
							*	Contrary to the documentation, the index is
							*	1 to N, not 0 to N
							*/
	void					PlayNthRootFile(
								uint16_t				inIndex)
								{SendCommand(3, inIndex);}
	bool					CommandCompleted(void);
	uint8_t					GetCommand(void) const
								{return(mReplyCommand);}
	uint16_t				GetParam(void) const
								{return(mParam);}
	void					ClearReplyCommand(void)
								{mReplyCommand = 0;}
protected:
	static uint8_t	sPacket[];
	uint8_t			mRingBuffer[10];
	uint8_t			mRingIndex;
	uint8_t			mReplyCommand;
	uint16_t		mParam;
	Stream&			mSerial;
	
	static uint16_t			CalculateChecksum(
								uint8_t*				inBuffer);
	static void				SerializeUInt16(
								uint16_t				inUint16,
								uint8_t*				outArray);
	uint8_t					GetParamsFromRingBuffer(
								uint16_t&				outParam);

};

#endif