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

#if !defined( _BINDEROO_SLICE_H_ )
#define _BINDEROO_SLICE_H_
//----------------------------------------------------------------------------

#include "binderoo/defs.h"
//----------------------------------------------------------------------------

/*#if defined( _MSC_VER )
	// The entire class is inlined, so we don't need to do any kind of whacky
	// symbol resolution. Thus, we disable this for this struct only.
	// https://msdn.microsoft.com/en-us/library/esew7y1w.aspx
	#pragma warning( push )
	#pragma warning( disable: 4251 )
#endif // defined( _MSC_VER )*/

namespace binderoo
{
	// A slice is little more than a data pointer. It implies no ownership whatsoever.
	template< typename _ty >
	struct Slice
	{
	private:
		template< typename _ty >
		struct LengthOf
		{
			template< size_t length >
			static BIND_INLINE size_t get( _ty( &data )[ length ] ) { return length; }
		};
		//--------------------------------------------------------------------

		template<>
		struct LengthOf< char >
		{
			template< size_t length >
			static BIND_INLINE size_t get( _ty( &data )[ length ] ) { return data[ length - 1 ] ? length : length - 1; }
		};
		//--------------------------------------------------------------------

		template<>
		struct LengthOf< const char >
		{
			template< size_t length >
			static BIND_INLINE size_t get( _ty( &data )[ length ] ) { return data[ length - 1 ] ? length : length - 1; }
		};
		//--------------------------------------------------------------------

	public:
		BIND_INLINE Slice()
			: uLength( 0 )
			, pData( nullptr )
		{
		}
		//--------------------------------------------------------------------

		template< size_t length >
		BIND_INLINE Slice( _ty (&data)[ length ] )
			: uLength( LengthOf< _ty >::get( data ) )
			, pData( data )
		{
		}
		//--------------------------------------------------------------------

		BIND_INLINE Slice( _ty* data, size_t length )
			: uLength( length )
			, pData( data )
		{
		}
		//--------------------------------------------------------------------

		BIND_INLINE const Slice& operator=( const Slice& other )
		{
			uLength = other.uLength;
			pData = other.pData;
			return *this;
		}
		//--------------------------------------------------------------------

		BIND_INLINE _ty&		operator[]( size_t uIndex ) const				{ return pData[ uIndex ]; }

		BIND_INLINE size_t		length() const									{ return uLength; }

		BIND_INLINE _ty*		data()											{ return pData; }
		BIND_INLINE const _ty*	data() const									{ return pData; }

		BIND_INLINE _ty*		begin()											{ return pData; }
		BIND_INLINE const _ty*	begin() const									{ return pData; }

		BIND_INLINE _ty*		end()											{ return pData + uLength; }
		BIND_INLINE const _ty*	end() const										{ return pData + uLength; }
		//--------------------------------------------------------------------

	private:
		size_t					uLength;
		_ty*					pData;
	};
	//------------------------------------------------------------------------

	typedef Slice< const char >		DString;
}
//----------------------------------------------------------------------------

/*#if defined( _MSC_VER )
	#pragma warning( pop )
#endif //defined( _MSC_VER )*/

#endif // !defined( _BINDEROO_SLICE_H_ )

//============================================================================
