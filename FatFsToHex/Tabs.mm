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
//  Tabs.mm
//  FatFsToHex
//
//  Created by Jon Mackey on 1/3/18.
//  Copyright © 2018 Jon Mackey. All rights reserved.
//
#include "Tabs.h"

/*********************************** Tabs *************************************/
/*
*	Pass the maximum number of tabs this class will return by Get()
*/
Tabs::Tabs(
	long	inMaxTabs)
	: mTabIndex(inMaxTabs), mMaxTabs(inMaxTabs)
{
	mTabs = new char[inMaxTabs+1];
	for (long tabIndex = 0; tabIndex < mMaxTabs; tabIndex++)
	{
		mTabs[tabIndex] = '\t';
	}
	mTabs[mMaxTabs] = 0;
}

/*********************************** ~Tabs ************************************/
Tabs::~Tabs(void)
{
	delete [] mTabs;
}

/********************************* operator = *********************************/
/*
*	Sets the number of tabs to be returned by Get().  You can pass any value.
*	Passing a number larger than the maximum allowed will cause the number
*	of tabs returned by Get() to be clamped till the tab stop falls below
*	the maximum.  Passing a value less than zero will cause the number of
*	tabs returned by Get() be nil until the tab stop passes tab stop zero.
*/
Tabs& Tabs::operator = (
	long	inTabStop)
{
	mTabIndex = mMaxTabs - inTabStop;
	return(*this);
}

/********************************* operator += ********************************/
/*
*	Same clamping rules as operator =
*/
Tabs& Tabs::operator += (
	long	inTabStops)
{
	mTabIndex -= inTabStops;
	return(*this);
}

/********************************* operator -= ********************************/
/*
*	Same clamping rules as operator =
*/
Tabs& Tabs::operator -= (
	long	inTabStops)
{
	mTabIndex += inTabStops;
	return(*this);
}

/********************************* operator ++ ********************************/
/*
*	Same clamping rules as operator =
*/
Tabs& Tabs::operator ++ (int)
{
	mTabIndex--;
	return(*this);
}

/********************************* operator -- ********************************/
/*
*	Same clamping rules as operator =
*/
Tabs& Tabs::operator -- (int)
{
	mTabIndex++;
	return(*this);
}

/********************************* Reset ********************************/
/*
*	Resets the tab stop to tab stop zero
*/
long Tabs::Reset(void)
{
	mTabIndex = mMaxTabs;
	return(mTabIndex);
}

/********************************* Get ********************************/
/*
*	Gets a string containing tabs representing the internal number of
*	tab stops
*/
const char* Tabs::Get(void)
{
	return((mTabIndex >= 0 && mTabIndex <= mMaxTabs) ? &mTabs[mTabIndex] :
			(mTabIndex < 0 ? mTabs : &mTabs[mMaxTabs]) );
}

/******************************* Size *********************************/
/*
*	Returns the size of the string returned by Get(void)
*/
long Tabs::Size(void)
{
	return((mTabIndex >= 0 && mTabIndex <= mMaxTabs) ? (mMaxTabs - mTabIndex) :
			(mTabIndex < 0 ? mMaxTabs : 0) );
}

/********************************* Get ********************************/
/*
*	Returns a string containing inNumTabs, clamped to 0 to mMaxTabs.
*/
const char* Tabs::Get(
	long	inNumTabs)
{
	return((inNumTabs >= 0 && inNumTabs <= mMaxTabs) ? &mTabs[mMaxTabs-inNumTabs] :
			(inNumTabs < 0 ? &mTabs[inNumTabs] : mTabs) );
}

