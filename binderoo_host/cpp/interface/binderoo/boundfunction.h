/*
Binderoo
Copyright (c) 2016, Remedy Entertainment
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:
    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * Neither the name of the copyright holder (Remedy Entertainment) nor the
      names of its contributors may be used to endorse or promote products
      derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL REMEDY ENTERTAINMENT BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/
//----------------------------------------------------------------------------

#pragma once

#if !defined( _BINDEROO_BOUNDFUNCTION_H_ )
#define _BINDEROO_BOUNDFUNCTION_H_

#include "binderoo/defs.h"
#include "binderoo/slice.h"
//----------------------------------------------------------------------------

namespace binderoo
{
	BIND_ALIGN( 16 ) struct BoundFunction
	{
		enum class Resolution : char
		{
			Unresolved,
			WaitingForImport,
			Imported,
			Exported,

			Max,
			Min = Unresolved,
		};
		//--------------------------------------------------------------------

		enum class CallingConvention : char
		{
			Undefined,
			C,
			CPP,

			Max,
			Min = Undefined,
		};
		//--------------------------------------------------------------------

		enum class FunctionKind : char
		{
			Undefined	= 0,
			Static		= 0x1,
			Method		= 0x2,
			Virtual		= 0x4,
			Abstract	= 0x8,
		};
		//--------------------------------------------------------------------

		enum class Flags : char
		{
			None			= 0,
			OwnerIsAbstract	= 0x1,
			Const			= 0x2,
		};
		//--------------------------------------------------------------------

		struct Hashes
		{
			uint64_t			uFunctionNameHash;
			uint64_t			uFunctionSignatureHash;

			BIND_INLINE bool	operator==( const Hashes& rhs ) const			{ return uFunctionNameHash == rhs.uFunctionNameHash && uFunctionSignatureHash == rhs.uFunctionSignatureHash; }
			BIND_INLINE bool	operator<( const Hashes& rhs ) const			{ return uFunctionNameHash < rhs.uFunctionNameHash || uFunctionSignatureHash < rhs.uFunctionSignatureHash; }
		};
		//--------------------------------------------------------------------

		DString					strFunctionName;
		DString					strFunctionSignature;
		DString					strOwningClass;
		DString					strRequiredInclude;
		Hashes					functionHashes;
		void*					pFunction;
		int						iMinimumVersion;
		Resolution				eResolution;
		CallingConvention		eCallingConvention;
		FunctionKind			eFunctionKind;
		Flags					eFlags;
	};
	//------------------------------------------------------------------------
}
//----------------------------------------------------------------------------

#endif // !defined( _BINDEROO_BOUNDFUNCTION_H_ )

//============================================================================
