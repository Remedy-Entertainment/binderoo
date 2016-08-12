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

#if !defined( _BINDEROO_UTIL_PARAMHANDLER_H_ )
#define _BINDEROO_UTIL_PARAMHANDLER_H_

#include "binderoo/defs.h"
#include "binderoo/slice.h"

#include <stdlib.h>
#include <stdio.h>
#include <string.h>

class ParamHandler
{
	template< typename _ty >
	struct Fetcher
	{
		static BIND_INLINE _ty fetch( binderoo::DString& param )
		{
			return _ty();
		}
	};
	//------------------------------------------------------------------------

	template< typename _ty >
	struct Setter
	{
		static BIND_INLINE void set( _ty& val, char* pOutputBuffer, size_t uBufferSize, const char*& pOutputPointer )
		{
			pOutputBuffer[ 0 ] = 0;
			pOutputPointer = pOutputBuffer;
		}
	};
	//------------------------------------------------------------------------

public:
	ParamHandler( binderoo::Slice< binderoo::DString > params )
		: sliceParameters( params )
		, returnValue( nullptr )
	{
		returnBuffer[ 0 ] = 0;
	}
	//------------------------------------------------------------------------

	template< typename _ty >
	BIND_INLINE _ty getParam( size_t uIndex )
	{
		return Fetcher< _ty >::fetch( sliceParameters[ uIndex ] );
	}
	//------------------------------------------------------------------------

	template< typename _ty >
	BIND_INLINE void setReturn( _ty& val )
	{
		Setter< _ty >::set( val, returnBuffer, ReturnBufferSize, returnValue );
	}
	//------------------------------------------------------------------------

	BIND_INLINE const char*					getReturnString() const				{ return returnValue; }
	//------------------------------------------------------------------------

	BIND_INLINE size_t						getParameterCount() const			{ return sliceParameters.length(); }
	//------------------------------------------------------------------------

private:
	enum { ReturnBufferSize = 128 };

	binderoo::Slice< binderoo::DString >	sliceParameters;
	const char*								returnValue;
	char									returnBuffer[ ReturnBufferSize ];

	template<> struct Fetcher< const char* >
	{
		static BIND_INLINE const char* fetch( binderoo::DString& param )
		{
			return param.data();
		}
	};
	//------------------------------------------------------------------------

	template<> struct Fetcher< bool >
	{
		static BIND_INLINE bool fetch( binderoo::DString& param )
		{
			return _stricmp( "true", param.data() ) ? true
													: atoi( param.data() ) != 0;
		}
	};
	//------------------------------------------------------------------------

	template<> struct Fetcher< char >
	{
		static BIND_INLINE char fetch( binderoo::DString& param )
		{
			return atoi( param.data() );
		}
	};
	//------------------------------------------------------------------------

	template<> struct Fetcher< unsigned char >
	{
		static BIND_INLINE unsigned char fetch( binderoo::DString& param )
		{
			return atoi( param.data() );
		}
	};
	//------------------------------------------------------------------------

	template<> struct Fetcher< short >
	{
		static BIND_INLINE short fetch( binderoo::DString& param )
		{
			return atoi( param.data() );
		}
	};
	//------------------------------------------------------------------------

	template<> struct Fetcher< unsigned short >
	{
		static BIND_INLINE unsigned short fetch( binderoo::DString& param )
		{
			return atoi( param.data() );
		}
	};
	//------------------------------------------------------------------------

	template<> struct Fetcher< int >
	{
		static BIND_INLINE int fetch( binderoo::DString& param )
		{
			return atoi( param.data() );
		}
	};
	//------------------------------------------------------------------------

	template<> struct Fetcher< unsigned int >
	{
		static BIND_INLINE unsigned int fetch( binderoo::DString& param )
		{
			return atoi( param.data() );
		}
	};
	//------------------------------------------------------------------------

	template<> struct Fetcher< int64_t >
	{
		static BIND_INLINE int64_t fetch( binderoo::DString& param )
		{
			return atoi( param.data() );
		}
	};
	//------------------------------------------------------------------------

	template<> struct Fetcher< uint64_t >
	{
		static BIND_INLINE uint64_t fetch( binderoo::DString& param )
		{
			return atoi( param.data() );
		}
	};
	//------------------------------------------------------------------------

	template<> struct Fetcher< float >
	{
		static BIND_INLINE float fetch( binderoo::DString& param )
		{
			return (float)atof( param.data() );
		}
	};
	//------------------------------------------------------------------------

	template<> struct Fetcher< double >
	{
		static BIND_INLINE double fetch( binderoo::DString& param )
		{
			return atof( param.data() );
		}
	};
	//------------------------------------------------------------------------
	//------------------------------------------------------------------------

	template< >	struct Setter< const char* >
	{
		static BIND_INLINE void set( const char*& pVal, char* pOutputBuffer, size_t uBufferSize, const char*& pOutputPointer )
		{
			pOutputPointer = pVal;
		}
	};
	//------------------------------------------------------------------------

	template< >	struct Setter< bool >
	{
		static BIND_INLINE void set( bool& val, char* pOutputBuffer, size_t uBufferSize, const char*& pOutputPointer )
		{
			sprintf_s( pOutputBuffer, uBufferSize, val ? "true" : "false" );
			pOutputPointer = pOutputBuffer;
		}
	};
	//------------------------------------------------------------------------

	template< >	struct Setter< char >
	{
		static BIND_INLINE void set( char& val, char* pOutputBuffer, size_t uBufferSize, const char*& pOutputPointer )
		{
			sprintf_s( pOutputBuffer, uBufferSize, "%d", val );
			pOutputPointer = pOutputBuffer;
		}
	};
	//------------------------------------------------------------------------

	template< >	struct Setter< unsigned char >
	{
		static BIND_INLINE void set( unsigned char& val, char* pOutputBuffer, size_t uBufferSize, const char*& pOutputPointer )
		{
			sprintf_s( pOutputBuffer, uBufferSize, "%d", val );
			pOutputPointer = pOutputBuffer;
		}
	};
	//------------------------------------------------------------------------

	template< >	struct Setter< short >
	{
		static BIND_INLINE void set( short& val, char* pOutputBuffer, size_t uBufferSize, const char*& pOutputPointer )
		{
			sprintf_s( pOutputBuffer, uBufferSize, "%d", val );
			pOutputPointer = pOutputBuffer;
		}
	};
	//------------------------------------------------------------------------

	template< >	struct Setter< unsigned short >
	{
		static BIND_INLINE void set( unsigned short& val, char* pOutputBuffer, size_t uBufferSize, const char*& pOutputPointer )
		{
			sprintf_s( pOutputBuffer, uBufferSize, "%d", val );
			pOutputPointer = pOutputBuffer;
		}
	};
	//------------------------------------------------------------------------

	template< >	struct Setter< int >
	{
		static BIND_INLINE void set( int& val, char* pOutputBuffer, size_t uBufferSize, const char*& pOutputPointer )
		{
			sprintf_s( pOutputBuffer, uBufferSize, "%d", val );
			pOutputPointer = pOutputBuffer;
		}
	};
	//------------------------------------------------------------------------

	template< >	struct Setter< unsigned int >
	{
		static BIND_INLINE void set( unsigned int& val, char* pOutputBuffer, size_t uBufferSize, const char*& pOutputPointer )
		{
			sprintf_s( pOutputBuffer, uBufferSize, "%d", val );
			pOutputPointer = pOutputBuffer;
		}
	};
	//------------------------------------------------------------------------

	template< >	struct Setter< int64_t >
	{
		static BIND_INLINE void set( int64_t& val, char* pOutputBuffer, size_t uBufferSize, const char*& pOutputPointer )
		{
			sprintf_s( pOutputBuffer, uBufferSize, "%lld", val );
			pOutputPointer = pOutputBuffer;
		}
	};
	//------------------------------------------------------------------------

	template< >	struct Setter< uint64_t >
	{
		static BIND_INLINE void set( uint64_t& val, char* pOutputBuffer, size_t uBufferSize, const char*& pOutputPointer )
		{
			sprintf_s( pOutputBuffer, uBufferSize, "%llu", val );
			pOutputPointer = pOutputBuffer;
		}
	};
	//------------------------------------------------------------------------

	template< >	struct Setter< float >
	{
		static BIND_INLINE void set( float& val, char* pOutputBuffer, size_t uBufferSize, const char*& pOutputPointer )
		{
			sprintf_s( pOutputBuffer, uBufferSize, "%f", val );
			pOutputPointer = pOutputBuffer;
		}
	};
	//------------------------------------------------------------------------

	template< >	struct Setter< double >
	{
		static BIND_INLINE void set( double& val, char* pOutputBuffer, size_t uBufferSize, const char*& pOutputPointer )
		{
			sprintf_s( pOutputBuffer, uBufferSize, "%f", val );
			pOutputPointer = pOutputBuffer;
		}
	};
	//------------------------------------------------------------------------

};
//----------------------------------------------------------------------------

void handleFunction( const char* pFunctionName, ParamHandler& parameters );

#endif //!defined( _BINDEROO_UTIL_PARAMHANDLER_H_ )
