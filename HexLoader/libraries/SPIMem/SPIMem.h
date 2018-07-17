/*
*	SPIMem.h
*	Copyright (c) 2018 Jonathan Mackey
*
*	Class to r/w from/to NOR Flash memory (bare minimum)
*/
#ifndef SPIMem_H
#define SPIMem_H

class SPIMem
{
public:
							SPIMem(
								uint8_t					inCSPin);
	void					begin(void);
	bool					ChipErase(void);
	uint8_t					GetManufacturerID(void)
								{return(mManufacturerID);}
	uint8_t					GetMemoryType(void)
								{return(mMemoryType);}
	uint32_t				GetCapacity(void)
								{return(mCapacity);}
	bool					WritePage(
								uint32_t				inAddr,
								const uint8_t*			inData);
	bool					Read(
								uint32_t				inAddr,
								uint32_t				inDataLen,
								uint8_t*				outData);
	void					LoadJEDECInfo(void);

protected:
	uint8_t		mCSPin;
	uint8_t		mManufacturerID;
	uint8_t		mMemoryType;
	uint32_t	mCapacity;
#if defined (SPCR) && defined (SPSR)
    uint8_t		mSPCR;
    uint8_t		mSPSR;
#endif
	
	void					SendCmd(
								uint8_t					inCmd);
	void					Select(void);
	void					Unselect(void);
	bool					WaitTillReady(
								uint32_t				inTimeout = 100);
	bool					WriteEnable(void);
	void					WriteDisable(void);
};

#endif