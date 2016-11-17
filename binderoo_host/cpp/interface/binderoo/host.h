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

#if !defined( _BINDEROO_HOST_H_ )
#define _BINDEROO_HOST_H_
//----------------------------------------------------------------------------

#include "binderoo/defs.h"
#include "binderoo/slice.h"
#include "binderoo/allocator.h"

#include "binderoo/boundfunction.h"
#include "binderoo/boundobject.h"
//----------------------------------------------------------------------------

namespace binderoo
{
	class ImportedBase;

	template< typename _ty >
	class ImportedClassInstance;

	template< typename _functiontraits >
	class ImportedFunction;

	struct BIND_DLL HostConfiguration
	{
		Slice< DString >					strDynamicLibSearchFolders;

		AllocatorFunc						alloc;
		DeallocatorFunc						free;
		CAllocatorFunc						calloc;
		ReallocatorFunc						realloc;

		UnalignedAllocatorFunc				unaligned_alloc;
		UnalignedDeallocatorFunc			unaligned_free;
	};
	//------------------------------------------------------------------------

	class BIND_DLL Host
	{
	public:
		Host( HostConfiguration& config );
		~Host();
		//--------------------------------------------------------------------

		bool checkForReloads();
		void performReloads();
		//--------------------------------------------------------------------

		BIND_INLINE void checkForAndPerformReloads()
		{
			if( checkForReloads() )
			{
				performReloads();
			}
		}
		//--------------------------------------------------------------------

		template< typename _ty >
		BIND_INLINE void					registerImportedClassInstance( ImportedClassInstance< _ty >* pInstance )
		{
			registerImportedClassInstance( (ImportedBase*)pInstance );
		}
		//--------------------------------------------------------------------

		template< typename _ty >
		BIND_INLINE void					deregisterImportedClassInstance( ImportedClassInstance< _ty >* pInstance )
		{
			deregisterImportedClassInstance( (ImportedBase*)pInstance );
		}
		//--------------------------------------------------------------------

		template< typename _functiontraits >
		BIND_INLINE void					registerImportedFunction( ImportedFunction< _functiontraits >* pInstance )
		{
			registerImportedFunction( (ImportedBase*)pInstance );
		}
		//--------------------------------------------------------------------
		
		template< typename _functiontraits >
		BIND_INLINE void					deregisterImportedFunction( ImportedFunction< _functiontraits >* pInstance )
		{
			deregisterImportedFunction( (ImportedBase*)pInstance );
		}
		//--------------------------------------------------------------------

		void* createImportedClass( const char* pName );
		bool destroyImportedClass( const char* pName, void* pObject );
		//--------------------------------------------------------------------

		template< typename _ty >
		BIND_INLINE _ty* createImportedClass()									{ return (_ty*)createImportedClass( TypeNames< _ty >::getDName() ); }
		//--------------------------------------------------------------------

		template< typename _ty >
		BIND_INLINE bool destroyImportedClass( void* pObj )						{ return destroyImportedClass( TypeNames< _ty >::getDName(), pObj ); }
		//--------------------------------------------------------------------

		const BoundFunction* getImportedFunctionDetails( const char* pName ) const;
		//--------------------------------------------------------------------

		// Returns a string allocated with your unaligned_alloc function that represents
		// the required #defines to bind a C++ object to the system
		const char* generateCPPStyleBindingDeclarationsForAllObjects();
		//--------------------------------------------------------------------

		static BIND_INLINE Host*			getActiveHost()						{ return pActiveHost; }

	private:
		void registerImportedClassInstance( ImportedBase* pInstance );
		void deregisterImportedClassInstance( ImportedBase* pInstance );

		void registerImportedFunction( ImportedBase* pInstance );
		void deregisterImportedFunction( ImportedBase* pInstance );
		//--------------------------------------------------------------------

		static Host*						pActiveHost;

		HostConfiguration					configuration;
		class HostImplementation*			pImplementation;
	};
	//------------------------------------------------------------------------
}
//----------------------------------------------------------------------------

#endif // !defined( _BINDEROO_HOST_H_ )

//============================================================================
