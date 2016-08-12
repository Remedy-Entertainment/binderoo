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

#if !defined( _BINDEROO_DEFS_H_ )
#define _BINDEROO_DEFS_H_
//----------------------------------------------------------------------------

#include <cstdint>

#if defined( BINDEROO_HOST )
	#define BIND_DLL			__declspec( dllexport )
#else
	#define BIND_DLL			__declspec( dllimport )
#endif // Host mode check

#pragma warning( disable: 4251 )

#define BIND_C_CALL			__cdecl
#define BIND_C_NAMING		extern "C"

#define BIND_ALIGN( x )		__declspec( align( x ) )
#define BIND_INLINE			__forceinline
#define BIND_NOINLINE		__declspec( noinline )
#define BIND_ABSTRACT		abstract
#define BIND_OVERRIDE		override
//----------------------------------------------------------------------------

#define BIND_TOSTRING_IMPL( x ) #x
#define BIND_TOSTRING( x ) BIND_TOSTRING_IMPL( ( x ) )

#define BIND_CONCAT_IMPL( a, b ) a ## b
#define BIND_CONCAT( a, b ) BIND_CONCAT_IMPL( a, b )
//----------------------------------------------------------------------------

#define BIND_CPP11				0
#define BIND_MSVC2012			1

#if defined( _MSC_VER ) && _MSC_VER < 1900
	#define BIND_CPPVERSION		BIND_MSVC2012
#else
	#define BIND_CPPVERSION		BIND_CPP11
#endif // C++ version checks

namespace binderoo
{
	template< typename _ty >
	struct TypeNames
	{
		static BIND_INLINE const char* getCName() { static_assert( false, "Undefined type!" ); }
		static BIND_INLINE const char* getDName() { static_assert( false, "Undefined type!" ); }
	};
}

#define BIND_TYPE_NAME( FullCType, FullDName ) \
template<> struct binderoo::TypeNames< FullCType > \
{ \
	static BIND_INLINE const char* getCName() { return #FullCType ## ; } \
	static BIND_INLINE const char* getDName() { return #FullDName ## ; } \
};\
template<> struct binderoo::TypeNames< FullCType* > \
{ \
	static BIND_INLINE const char* getCName() { return #FullCType "*"; } \
	static BIND_INLINE const char* getDName() { return #FullDName "*"; } \
};\
template<> struct binderoo::TypeNames< FullCType& > \
{ \
	static BIND_INLINE const char* getCName() { return #FullCType "&"; } \
	static BIND_INLINE const char* getDName() { return "ref " #FullDName ## ; } \
};\

BIND_TYPE_NAME( char, char )
BIND_TYPE_NAME( unsigned char, ubyte )
BIND_TYPE_NAME( short, short )
BIND_TYPE_NAME( unsigned short, ushort )
BIND_TYPE_NAME( int, int )
BIND_TYPE_NAME( unsigned int, uint )
BIND_TYPE_NAME( int64_t, long )
BIND_TYPE_NAME( uint64_t, ulong )
BIND_TYPE_NAME( wchar_t, wchar )

#endif // !defined( _BINDEROO_DEFS_H_ )

//============================================================================
