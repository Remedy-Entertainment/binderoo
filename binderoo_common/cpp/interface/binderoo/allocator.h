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

#include "binderoo/defs.h"
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

	enum class AllocatorSpace
	{
		Host,
		Service
	};

	template< AllocatorSpace eSpace >
	class BIND_DLL AllocatorFunctions
	{
	public:
		static void setup( AllocatorFunc a, DeallocatorFunc d, CAllocatorFunc c, ReallocatorFunc r )
		{
			fAlloc		= a;
			fFree		= d;
			fCalloc		= c;
			fRealloc	= r;
		}
		//--------------------------------------------------------------------

		static BIND_INLINE void*	alloc( size_t objSize, size_t alignment )
		{
			return fAlloc ? fAlloc( objSize, alignment ) : nullptr;
		}
		//--------------------------------------------------------------------

		// This does not construct data. It only allocates to the specified
		// aignment.
		template< typename _ty >
		static BIND_INLINE _ty*	alloc( size_t alignment = BIND_ALIGNOF( _ty ) )
		{
			return (_ty*)alloc( sizeof( _ty ), alignment );
		}
		//--------------------------------------------------------------------

		// Allocates and constructs with default object alignment
		template< typename _ty, typename... _args >
		static BIND_INLINE _ty*	allocAndConstruct( _args... args )
		{
			return new( alloc( sizeof( _ty ), BIND_ALIGNOF( _ty ) ) ) _ty( args... );
		}
		//--------------------------------------------------------------------

		// Allocates and constructs with specified object alignment
		template< typename _ty, typename... _args >
		static BIND_INLINE _ty*	allocAndConstructAligned( size_t alignment, _args... args )
		{
			return new( alloc( sizeof( _ty ), alignment ) ) _ty( args... );
		}
		//--------------------------------------------------------------------

		static BIND_INLINE void		free( void* pObj )
		{
			if( fFree ) fFree( pObj );
		}
		//--------------------------------------------------------------------

		template< typename _ty >
		static BIND_INLINE void		destructAndFree( _ty* pObj )
		{
			if( pObj )
			{
				pObj->~_ty();
				free( pObj );
			}
		}
		//--------------------------------------------------------------------

		static BIND_INLINE void*	calloc( size_t objCount, size_t objSize, size_t alignment )
		{
			return fCalloc ? fCalloc( objCount, objSize, alignment ) : nullptr;
		}
		//--------------------------------------------------------------------

		static BIND_INLINE void*	realloc( void* pObj, size_t newObjSize, size_t alignment )
		{
			return fRealloc ? fRealloc( pObj, newObjSize, alignment ) : nullptr;
		}
		//--------------------------------------------------------------------

	protected:
		static AllocatorFunc			fAlloc;
		static DeallocatorFunc			fFree;
		static CAllocatorFunc			fCalloc;
		static ReallocatorFunc			fRealloc;
	};
	//------------------------------------------------------------------------

	template< AllocatorSpace eSpace, typename _ty, size_t _alignval = 16 >
	class BIND_DLL Allocator : public AllocatorFunctions< eSpace >
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
			typedef Allocator< eSpace, typename _newty, alignment > other;
		};
		//--------------------------------------------------------------------

		BIND_INLINE						Allocator()									{ }
		BIND_INLINE						Allocator( const Allocator& /*other*/ )		{ }
		template< AllocatorSpace Space, typename _otherTy, size_t _otherA > 
		BIND_INLINE						Allocator( const Allocator< Space, typename _otherTy, _otherA >& /*other*/ )	{ }
		BIND_INLINE						~Allocator()								{ }
		//--------------------------------------------------------------------

		template< AllocatorSpace Space, typename _otherTy, size_t _otherA > 
		BIND_INLINE bool				operator==( const Allocator< Space, _otherTy, _otherA >& /*rhs*/ ) const	{ return true; }
		//--------------------------------------------------------------------

		template< AllocatorSpace Space, typename _otherTy, size_t _otherA > 
		BIND_INLINE bool				operator==( Allocator< Space, _otherTy, _otherA >& /*rhs*/ )				{ return true; }
		//--------------------------------------------------------------------

		BIND_INLINE pointer				address( reference x ) const				{ return &x; }
		BIND_INLINE const_pointer		address( const_reference x ) const			{ return &x; }
		//--------------------------------------------------------------------

		BIND_INLINE pointer				allocate( size_type count )
		{
			return reinterpret_cast< pointer >( alloc( count * value_type_size, alignment ) );
		}
		//--------------------------------------------------------------------

		BIND_INLINE pointer				allocate( size_type count, typename Allocator< eSpace, void, alignment >::const_pointer hint )
		{
			return allocate( count );
		}
		//--------------------------------------------------------------------

		BIND_INLINE void				deallocate( pointer pPointer, size_type /*count*/ )
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
		template< typename _otherA, typename Args >
		BIND_INLINE void				construct( _otherA* pPointer, Args&& args )
		{
			::new( (void*)pPointer ) U( args );
		}
		//--------------------------------------------------------------------
#else // Sane compilers
		template< typename _otherTy, typename ...Args >
		BIND_INLINE void				construct( _otherTy* pPointer, Args&&... args )
		{
			::new( (void*)pPointer ) _otherTy( std::forward< Args >( args )... );
		}
		//--------------------------------------------------------------------
#endif // BIND_CPPVERSION

		template< typename _otherTy >
		BIND_INLINE void				destroy( _otherTy* pPointer )
		{
			pPointer->_otherTy::~_otherTy();
		}
		//--------------------------------------------------------------------
	};
	//------------------------------------------------------------------------

	template< AllocatorSpace eSpace, size_t _alignval >
	class BIND_DLL Allocator< eSpace, void, _alignval > : public AllocatorFunctions< eSpace >
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
			typedef Allocator< eSpace, typename _newty, alignment > other;
		};
		//--------------------------------------------------------------------

		BIND_INLINE						Allocator()									{ }
		BIND_INLINE						Allocator( const Allocator& /*other*/ )		{ }
		template< AllocatorSpace Space, typename _otherTy, size_t _otherA > 
		BIND_INLINE						Allocator( const Allocator< Space, typename _otherTy, _otherA >& /*other*/ )	{ }
		BIND_INLINE						~Allocator()								{ }
		//--------------------------------------------------------------------

		template< AllocatorSpace Space, typename _otherTy, size_t _otherA >
		BIND_INLINE bool				operator==( const Allocator< Space, typename _otherTy, _otherA >& /*rhs*/ )		{ return true; }
		//--------------------------------------------------------------------
	};
}
//----------------------------------------------------------------------------

#endif // !defined( _BINDEROO_ALLOCATOR_H_ )

//============================================================================
