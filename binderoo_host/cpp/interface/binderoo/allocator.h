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

#if !defined( _BINDEROO_ALLOCATOR_H_ )
#define _BINDEROO_ALLOCATOR_H_
//----------------------------------------------------------------------------

#include "defs.h"
//----------------------------------------------------------------------------

namespace binderoo
{
	typedef void*	( BIND_C_CALL *AllocatorFunc )				( size_t objSize, size_t alignment );
	typedef void	( BIND_C_CALL *DeallocatorFunc )			( void* pObj );
	typedef void*	( BIND_C_CALL *CAllocatorFunc )				( size_t objCount, size_t objSize, size_t alignment );
	typedef void*	( BIND_C_CALL *ReallocatorFunc )			( void* pObj, size_t newObjSize, size_t alignment );

	typedef void*	( BIND_C_CALL *UnalignedAllocatorFunc )		( size_t objSize );
	typedef void	( BIND_C_CALL *UnalignedDeallocatorFunc )	( void* pObj );
	//------------------------------------------------------------------------

	template< typename _ty, size_t _alignval = 16 >
	class BIND_DLL Allocator
	{
	public:

		typedef typename _ty			value_type;
		typedef typename _ty*			pointer;
		typedef const typename _ty*		const_pointer;
		typedef typename _ty&			reference;
		typedef const typename _ty&		const_reference;
		typedef size_t					size_type;
		typedef ptrdiff_t				difference_type;
		//--------------------------------------------------------------------

		enum : size_t
		{
			value_type_size				= sizeof( value_type ),
#if BIND_CPPVERSION == BIND_MSVC2012
			alignment					= __alignof( value_type ) > _alignval ? __alignof( value_type ) : _alignval,
#else // Sane compilers
			alignment					= alignof( value_type ) > _alignval ? alignof( value_type ) : _alignval,
#endif // BIND_CPPVERSION
			max_alloc_count				= (size_type)-1 / value_type_size
		};
		//--------------------------------------------------------------------

		template< typename _newty >
		struct rebind
		{
			typedef Allocator< typename _newty, alignment > other;
		};
		//--------------------------------------------------------------------

		BIND_INLINE						Allocator()
			: alloc( nullptr )
			, free( nullptr )
			, calloc( nullptr )
			, realloc( nullptr )													{ }
		//--------------------------------------------------------------------

		BIND_INLINE						Allocator( AllocatorFunc a, DeallocatorFunc d, CAllocatorFunc c, ReallocatorFunc r )
			: alloc( a )
			, free( d )
			, calloc( c )
			, realloc( r )															{ }
		//--------------------------------------------------------------------

		BIND_INLINE						Allocator( const Allocator& other )
			: alloc( other.alloc )
			, free( other.free )
			, calloc( other.calloc )
			, realloc( other.realloc )												{ }
		//--------------------------------------------------------------------

		template< typename U, size_t A > 
		BIND_INLINE						Allocator( const Allocator< typename U, A >& other )
			: alloc( other.alloc )
			, free( other.free )
			, calloc( other.calloc )
			, realloc( other.realloc )												{ }
		//--------------------------------------------------------------------

		BIND_INLINE						~Allocator()								{ }
		//--------------------------------------------------------------------

		template< typename U, size_t S >
		BIND_INLINE bool				operator==( const Allocator< U, S >& rhs ) const	{ return true; }
		//--------------------------------------------------------------------

		template< typename U, size_t S >
		BIND_INLINE bool				operator==( Allocator< U, S >& rhs )				{ return true; }
		//--------------------------------------------------------------------

		BIND_INLINE pointer				address( reference x ) const				{ return &x; }
		BIND_INLINE const_pointer		address( const_reference x ) const			{ return &x; }
		//--------------------------------------------------------------------

		BIND_INLINE pointer				allocate( size_type count )
		{
			return reinterpret_cast< pointer >( alloc( count * value_type_size, alignment ) );
		}
		//--------------------------------------------------------------------

		BIND_INLINE pointer				allocate( size_type count, Allocator< void >::const_pointer hint )
		{
			return allocate( count );
		}
		//--------------------------------------------------------------------

		BIND_INLINE void				deallocate( pointer pPointer, size_type count )
		{
			return free( pPointer );
		}
		//--------------------------------------------------------------------

		BIND_INLINE size_type			max_size() const
		{
			return max_alloc_count;
		}
		//--------------------------------------------------------------------

#if BIND_CPPVERSION == BIND_MSVC2012
		template< typename U, typename Args >
		BIND_INLINE void				construct( U* pPointer, Args&& args )
		{
			::new( (void*)pPointer ) U( args );
		}
		//--------------------------------------------------------------------
#else // Sane compilers
		template< typename U, typename ...Args >
		BIND_INLINE void				construct( U* pPointer, Args&&... args )
		{
			::new( (void*)pPointer ) U( std::forward< Args >( args )... );
		}
		//--------------------------------------------------------------------
#endif // BIND_CPPVERSION

		template< class U >
		BIND_INLINE void				destroy( U* pPointer )
		{
			pPointer->~U();
		}
		//--------------------------------------------------------------------

		AllocatorFunc					alloc;
		DeallocatorFunc					free;
		CAllocatorFunc					calloc;
		ReallocatorFunc					realloc;
	};
	//------------------------------------------------------------------------

	template< size_t _alignval >
	class BIND_DLL Allocator< void, _alignval >
	{
	public:
		typedef void					value_type;
		typedef void*					pointer;
		typedef const void*				const_pointer;
		//--------------------------------------------------------------------

		enum : size_t
		{
			value_type_size				= 0,
			alignment					= _alignval,
			max_alloc_count				= 0
		};
		//--------------------------------------------------------------------

		template< typename _newty >
		struct rebind
		{
			typedef Allocator< typename _newty, alignment > other;
		};
		//--------------------------------------------------------------------

		BIND_INLINE						Allocator()
			: alloc( nullptr )
			, free( nullptr )
			, calloc( nullptr )
			, realloc( nullptr )													{ }
		//--------------------------------------------------------------------

		BIND_INLINE						Allocator( AllocatorFunc a, DeallocatorFunc d, CAllocatorFunc c, ReallocatorFunc r )
			: alloc( a )
			, free( d )
			, calloc( c )
			, realloc( r )															{ }
		//--------------------------------------------------------------------

		BIND_INLINE						Allocator( const Allocator& other )
			: alloc( other.alloc )
			, free( other.free )
			, calloc( other.calloc )
			, realloc( other.realloc )												{ }
		//--------------------------------------------------------------------

		template< typename U, size_t A > 
		BIND_INLINE						Allocator( const Allocator< typename U, A >& other )
			: alloc( other.alloc )
			, free( other.free )
			, calloc( other.calloc )
			, realloc( other.realloc )												{ }
		//--------------------------------------------------------------------

		BIND_INLINE						~Allocator()								{ }
		//--------------------------------------------------------------------

		template< typename U, size_t S >
		BIND_INLINE bool				operator==( const Allocator< U, S >& rhs )	{ return true; }
		//--------------------------------------------------------------------

		AllocatorFunc					alloc;
		DeallocatorFunc					free;
		CAllocatorFunc					calloc;
		ReallocatorFunc					realloc;
	};
}
//----------------------------------------------------------------------------

#endif // !defined( _BINDEROO_ALLOCATOR_H_ )

//============================================================================
