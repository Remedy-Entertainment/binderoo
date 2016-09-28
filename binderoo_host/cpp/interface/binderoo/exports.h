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

#if !defined( _BINDEROO_EXPORTS_H_ )
#define _BINDEROO_EXPORTS_H_
//----------------------------------------------------------------------------

// To export a class, you need to include this header and generate a definition
// for it using some macros. Also importantly: mark your class up for DLL export
// either using the BIND_DLL macro or some other method. Virtual function tables
// will not generate correctly under some compilers if it decides a function
// will never be virtual.
//
// BIND_EXPORT_CLASS_BASE_BEGIN( namespace, class, version )
// BIND_EXPORT_CLASS_INHERITS_BEGIN( namespace, class, baseClass, version )
//
// BIND_EXPORT_METHOD( namespace, class, method, returnType [, paramTypes... ] )
// BIND_EXPORT_NONEWMETHODS
//
// BIND_EXPORT_CLASS_BASE_END;
// BIND_EXPORT_CLASS_INHERITS_END;
//
// A base class export would look something like:
// BIND_EXPORT_CLASS_BASE_BEGIN( binderoo, ExportedMethod, 1 )
//   BIND_EXPORT_METHOD( binderoo, ExportedMethod, valid, bool )
// BIND_EXPORT_CLASS_BASE_END;
//
//----------------------------------------------------------------------------

#include "binderoo/defs.h"
#include "binderoo/functiontraits.h"
#include "binderoo/slice.h"
//----------------------------------------------------------------------------

namespace binderoo
{
	template< typename _func >
	BIND_INLINE void* toVoidPointer( _func pFunc )
	{
		return ( ( void** )&pFunc )[ 0 ];
	}

	struct BIND_DLL ExportedMethod
	{
		ExportedMethod()
			: pFunctionPointer( nullptr )
		{
		}
		//--------------------------------------------------------------------

		template< size_t nameLength, size_t signatureLength, typename FunctionType >
		ExportedMethod( char const (&name)[ nameLength ], char const (&signature)[ signatureLength ], FunctionType pFunc )
			: strName( name )
			, strSignature( signature )
			, pFunctionPointer( ( ( void** )&pFunc )[ 0 ] )
		{
		}
		//--------------------------------------------------------------------

		BIND_INLINE bool		valid() const { return strName.length() > 0; }
		//--------------------------------------------------------------------

		DString					strName;
		DString					strSignature;
		void*					pFunctionPointer;
	};
	//------------------------------------------------------------------------

	typedef Slice< ExportedMethod > ExportedMethods;
	//------------------------------------------------------------------------

	class BIND_DLL ExportedClass
	{
	public:
		ExportedClass( int version, DString name, DString inherits, ExportedMethods pMethods )
			: iVersion( version )
			, strName( name )
			, methods( pMethods )
			, pNext( nullptr )
		{
			bHasNewMethods = methods[ 0 ].valid();

			pNext = pHead;
			pHead = this;
		}
		//--------------------------------------------------------------------

		BIND_INLINE int				getVersion() const							{ return iVersion; }
		BIND_INLINE const char*		getName() const								{ return strName.data(); }
		BIND_INLINE const char*		getBaseClass() const						{ return strBaseClass.data(); }
		BIND_INLINE size_t			getMethodCount() const						{ return bHasNewMethods ? methods.length() : 0; }
		BIND_INLINE ExportedMethod&	getMethod( size_t iIndex ) const			{ return methods[ iIndex ]; }
		BIND_INLINE ExportedMethods	getMethods() const							{ return methods; }
		//--------------------------------------------------------------------

		static BIND_INLINE ExportedClass* getFirstClass()						{ return pHead; }
		BIND_INLINE ExportedClass*	getNextClass()								{ return pNext; }
		//--------------------------------------------------------------------

	private:
		bool						bHasNewMethods;
		int							iVersion;
		DString						strName;
		DString						strBaseClass;
		ExportedMethods				methods;
		//--------------------------------------------------------------------

		ExportedClass*				pNext;

		static ExportedClass*		pHead;
	};
}
//----------------------------------------------------------------------------

// TODO: Make this all C++11 smexy
#define BIND_CLASSSTRING_IMPL( classNamespace, className ) classNamespace "::" className
#define BIND_CLASSSTRING( classNamespace, className ) BIND_CLASSSTRING_IMPL( #classNamespace, #className )

#define BIND_METHODSTRING_IMPL( classNamespace, className, method ) classNamespace "::" className "::" method
#define BIND_METHODSTRING( classNamespace, className, method ) BIND_METHODSTRING_IMPL( #classNamespace, #className, #method )

#define BIND_CLASSIDENTIFIER( classNamespace, className ) BIND_CONCAT( classNamespace, BIND_CONCAT( ::, className ) )
#define BIND_METHODIDENTIFIER( classNamespace, className, method ) BIND_CONCAT( BIND_CLASSIDENTIFIER( classNamespace, className ), BIND_CONCAT( ::, method ) ) ) )
#define BIND_VERSIONIDENTIFIER( className ) BIND_CONCAT( iExportVersion_, className )
#define BIND_EXPORTEDMETHODSIDENTIFIER( className ) BIND_CONCAT( exportedMethods_, className )

#define BIND_FUNCTION_SIGNATURE( returnType, args ) returnType "(" args ")"
//----------------------------------------------------------------------------
//----------------------------------------------------------------------------

#define BIND_EXPORT_CLASS_BASE_BEGIN( classNamespace, className, exportVersion ) \
	static const int BIND_VERSIONIDENTIFIER( className ) = exportVersion; \
	static binderoo::ExportedMethod BIND_EXPORTEDMETHODSIDENTIFIER( className )[] = {

#define BIND_EXPORT_CLASS_INHERITS_BEGIN( classNamespace, className, inherits, exportVersion ) BIND_EXPORT_CLASS_BASE_BEGIN( classNamespace, className, exportVersion )

#define BIND_EXPORT_METHOD( classNamespace, className, method, returnType, ... ) binderoo::ExportedMethod( BIND_METHODSTRING( classNamespace, className, method ), BIND_FUNCTION_SIGNATURE( #returnType, #__VA_ARGS__ ), BIND_CONCAT( &, BIND_CONCAT( classNamespace, BIND_CONCAT( ::, BIND_CONCAT( className, BIND_CONCAT( ::, method ) ) ) ) ) )

#define BIND_EXPORT_NONEWMETHODS binderoo::ExportedMethod()

#define BIND_EXPORT_CLASS_BASE_END( classNamespace, className ) }; \
	static binderoo::ExportedClass BIND_CONCAT( exportedClass_, className ) ( BIND_VERSIONIDENTIFIER( className ), BIND_CLASSSTRING( classNamespace, className ), "", binderoo::ExportedMethods( BIND_EXPORTEDMETHODSIDENTIFIER( className ) ) )

#define BIND_EXPORT_CLASS_INHERITS_END( classNamespace, className, inherits ) }; \
	static binderoo::ExportedClass BIND_CONCAT( exportedClass_, className ) ( BIND_VERSIONIDENTIFIER( className ), BIND_CLASSSTRING( classNamespace, className ), #inherits, binderoo::ExportedMethods( BIND_EXPORTEDMETHODSIDENTIFIER( className ) ) )

#endif // !defined( _BINDEROO_EXPORTS_H_ )

//============================================================================
