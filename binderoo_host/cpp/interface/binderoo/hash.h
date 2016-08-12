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

#if !defined( _BINDEROO_HASH_H_ )
#define _BINDEROO_HASH_H_
//----------------------------------------------------------------------------

#include "defs.h"

namespace binderoo
{
	BIND_INLINE uint32_t fnv1a_32( const char* pData, size_t uLength );
	template< size_t uLength >
	BIND_INLINE uint32_t fnv1a_32( char const (&data)[ uLength ] )				{ return fnv1a_32( data, uLength ); }

	BIND_INLINE uint64_t fnv1a_64( const char* pData, size_t uLength );
	template< size_t uLength >
	BIND_INLINE uint64_t fnv1a_64( char const (&data)[ uLength ] )				{ return fnv1a_64( data, uLength ); }

	template< typename _ty >
	struct FNV1aHasher
	{
		uint64_t operator()( const _ty& val ) const
		{
			return fnv1a_64( (const char*)&val, sizeof( _ty ) );
		}
		//--------------------------------------------------------------------

		uint64_t operator()( _ty& val )
		{
			return fnv1a_64( (const char*)&val, sizeof( _ty ) );
		}
		//--------------------------------------------------------------------
	};
	//------------------------------------------------------------------------

}
//----------------------------------------------------------------------------

BIND_INLINE uint32_t binderoo::fnv1a_32( const char* pData, size_t uLength )
{
	const uint32_t uBasis = 2166136261u;
	const uint32_t uPrime = 16777619u;

	uint32_t uValue = uBasis;
	const char* pEnd = pData + uLength;
	while( pData < pEnd )
	{
		uValue ^= *pData;
		uValue *= uPrime;
		++pData;
	}

	return uValue;
}
//----------------------------------------------------------------------------

BIND_INLINE uint64_t binderoo::fnv1a_64( const char* pData, size_t uLength )
{
	const uint64_t uBasis = 14695981039346656037ull;
	const uint64_t uPrime = 1099511628211ull;

	uint64_t uValue = uBasis;
	const char* pEnd = pData + uLength;
	while( pData < pEnd )
	{
		uValue ^= *pData;
		uValue *= uPrime;
		++pData;
	}

	return uValue;
}
//----------------------------------------------------------------------------

#endif // !defined( _BINDEROO_HASH_H_ )

//============================================================================

