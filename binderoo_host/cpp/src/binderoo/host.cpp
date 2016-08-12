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

#include "binderoo/host.h"

#include "binderoo/boundfunction.h"
#include "binderoo/boundobject.h"
#include "binderoo/exports.h"
#include "binderoo/hash.h"
#include "binderoo/imports.h"
#include "binderoo/slice.h"

#include <unordered_map>
#include <vector>
#include <string>
#include <algorithm>

#include <Windows.h>
//----------------------------------------------------------------------------

binderoo::Host*	binderoo::Host::pActiveHost				= nullptr;

namespace binderoo
{
	typedef std::basic_string< char, std::char_traits< char >, binderoo::Allocator< char > >		InternalString;
	typedef std::vector< InternalString, binderoo::Allocator< InternalString > >					InternalStringVector;

	typedef void					( BIND_C_CALL *ImportFunctionsFromPtr )							( binderoo::Slice< binderoo::BoundFunction > );
	typedef void					( BIND_C_CALL *GetExportedObjectsPtr )							( binderoo::Slice< binderoo::BoundObject >* );
	typedef void					( BIND_C_CALL *GetExportedFunctionsPtr )						( binderoo::Slice< binderoo::BoundFunction >* );
	typedef void*					( BIND_C_CALL *CreateObjectByNamePtr )							( DString );
	typedef void*					( BIND_C_CALL *CreateObjectByHashPtr )							( uint64_t );
	typedef void					( BIND_C_CALL *DestroyObjectByNamePtr )							( DString, void* );
	typedef void					( BIND_C_CALL *DestroyObjectByHashPtr )							( uint64_t, void* );
	typedef const char*				( BIND_C_CALL *GenerateBindingDeclarationsForAllObjectsPtr )	( UnalignedAllocatorFunc allocator );

	enum class DynamicLibStatus : int
	{
		NotLoaded,
		LoadFailed,
		CoreInterfaceNotFound,

		Ready,

		Max,
		Min = 0
	};

	struct HostDynamicLib
	{
		HostDynamicLib( binderoo::Allocator< char > allocator )
			: strName( allocator )
			, strPath( allocator )
			, hModule( nullptr )
			, eStatus( DynamicLibStatus::NotLoaded )
			, importFunctionsFrom( nullptr )
			, getExportedObjects( nullptr )
			, getExportedFunctions( nullptr )
			, createObjectByName( nullptr )
			, createObjectByHash( nullptr )
			, destroyObjectByName( nullptr )
			, destroyObjectByHash( nullptr )
			, generateCPPStyleBindingDeclarationsForAllObjects( nullptr )
		{
		}

		InternalString									strName;
		InternalString									strPath;
		HMODULE											hModule;
		DynamicLibStatus								eStatus;

		ImportFunctionsFromPtr							importFunctionsFrom;
		GetExportedObjectsPtr							getExportedObjects;
		GetExportedFunctionsPtr							getExportedFunctions;
		CreateObjectByNamePtr							createObjectByName;
		CreateObjectByHashPtr							createObjectByHash;
		DestroyObjectByNamePtr							destroyObjectByName;
		DestroyObjectByHashPtr							destroyObjectByHash;
		GenerateBindingDeclarationsForAllObjectsPtr		generateCPPStyleBindingDeclarationsForAllObjects;
	};
	//------------------------------------------------------------------------

	class HostImplementation
	{
	public:
		typedef Allocator< void, 16 >														DefaultAllocator;

		typedef Allocator< BoundFunction >													FunctionAllocator;
		typedef std::vector< BoundFunction, FunctionAllocator >								FunctionVector;

		typedef binderoo::FNV1aHasher< BoundFunction::Hashes >								FunctionMapHasher;
		typedef std::pair< const BoundFunction::Hashes, size_t >							FunctionMapPair;
		typedef Allocator< FunctionMapPair >												FunctionMapAllocator;

		typedef std::equal_to< BoundFunction::Hashes >										FunctionMapComparer;
		typedef std::unordered_map< BoundFunction::Hashes, size_t, FunctionMapHasher, FunctionMapComparer, FunctionMapAllocator >	FunctionMap;

		typedef std::vector< HostDynamicLib, Allocator< HostDynamicLib > >					DynamicLibVector;
		//--------------------------------------------------------------------

		HostImplementation( HostConfiguration& config )
			: configuration( config )
			, allocator( config.alloc, config.free, config.calloc, config.realloc )
			, mapExportedFunctionIndices( allocator )
			, vecExportedFunctions( allocator )
			, mapImportedFunctionIndices( allocator )
			, vecImportedFunctions( allocator )
			, vecDynamicLibs( allocator )
		{
			collectExports();
			collectDynamicLibraries();
		}
		//--------------------------------------------------------------------

		void					collectExports();
		void					collectDynamicLibraries();

		void					loadDynamicLibraries();
		bool					loadDynamicLibrary( HostDynamicLib& lib );
		//--------------------------------------------------------------------

		void					registerImportedClassInstance( ImportedBase* pInstance );
		void					deregisterImportedClassInstance( ImportedBase* pInstance );

		void					registerImportedFunction( ImportedBase* pInstance );
		void					deregisterImportedFunction( ImportedBase* pInstance );
		//--------------------------------------------------------------------

		void*					createImportedClass( const char* pName );
		bool					destroyImportedClass( const char* pName, void* pObject );
		//--------------------------------------------------------------------

		const BoundFunction*	getImportedFunctionDetails( const char* pName ) const;
		//--------------------------------------------------------------------

		const char*				generateCPPStyleBindingDeclarationsForAllObjects();
		//--------------------------------------------------------------------

	private:
		HostConfiguration&		configuration;
		DefaultAllocator		allocator;

		FunctionMap				mapExportedFunctionIndices;
		FunctionVector			vecExportedFunctions;

		FunctionMap				mapImportedFunctionIndices;
		FunctionVector			vecImportedFunctions;

		DynamicLibVector		vecDynamicLibs;
	};
	//------------------------------------------------------------------------
}
//----------------------------------------------------------------------------

binderoo::Host::Host( binderoo::HostConfiguration& config )
	: configuration( config )
	, pImplementation( nullptr )
{
	pImplementation = (HostImplementation*)config.alloc( sizeof( HostImplementation ), sizeof( size_t ) );
	new( pImplementation ) HostImplementation( config );

	pActiveHost = this;
}
//----------------------------------------------------------------------------

binderoo::Host::~Host()
{
	pImplementation->~HostImplementation();

	pActiveHost = nullptr;

	configuration.free( pImplementation );
}
//----------------------------------------------------------------------------

void binderoo::Host::registerImportedClassInstance( binderoo::ImportedBase* pInstance )
{
	pImplementation->registerImportedClassInstance( pInstance );
}
//--------------------------------------------------------------------

void binderoo::Host::deregisterImportedClassInstance( binderoo::ImportedBase* pInstance )
{
	pImplementation->deregisterImportedClassInstance( pInstance );
}
//--------------------------------------------------------------------

void binderoo::Host::registerImportedFunction( binderoo::ImportedBase* pInstance )
{
	pImplementation->registerImportedFunction( pInstance );
}
//----------------------------------------------------------------------------

void binderoo::Host::deregisterImportedFunction( binderoo::ImportedBase* pInstance )
{
	pImplementation->deregisterImportedFunction( pInstance );
}
//----------------------------------------------------------------------------

void* binderoo::Host::createImportedClass( const char* pName )
{
	return pImplementation->createImportedClass( pName );
}
//--------------------------------------------------------------------

bool binderoo::Host::destroyImportedClass( const char* pName, void* pObject )
{
	return pImplementation->destroyImportedClass( pName, pObject );
}
//--------------------------------------------------------------------

const binderoo::BoundFunction* binderoo::Host::getImportedFunctionDetails( const char* pName ) const
{
	return pImplementation->getImportedFunctionDetails( pName );
}
//--------------------------------------------------------------------

const char* binderoo::Host::generateCPPStyleBindingDeclarationsForAllObjects()
{
	return pImplementation->generateCPPStyleBindingDeclarationsForAllObjects();
}
//----------------------------------------------------------------------------

void binderoo::HostImplementation::collectExports()
{
	ExportedClass* pCurrClass = ExportedClass::getFirstClass();

	while( pCurrClass )
	{
		for( auto& method : pCurrClass->getMethods() )
		{
			uint64_t uSymbolHash = fnv1a_64( method.strName.data(), method.strName.length() );
			uint64_t uSignatureHash = fnv1a_64( method.strSignature.data(), method.strSignature.length() );

			BoundFunction bound;

			bound.strFunctionName							= method.strName;
			bound.strFunctionSignature						= method.strSignature;

			bound.functionHashes.uFunctionNameHash			= uSymbolHash;
			bound.functionHashes.uFunctionSignatureHash		= uSignatureHash;
			bound.pFunction									= method.pFunctionPointer;
			bound.iMinimumVersion							= pCurrClass->getVersion();
			bound.eResolution								= BoundFunction::Resolution::Exported;

			size_t uIndex = vecExportedFunctions.size();
			vecExportedFunctions.push_back( bound );

			mapExportedFunctionIndices[ bound.functionHashes ] = uIndex;
		}

		pCurrClass = pCurrClass->getNextClass();
	}
}
//----------------------------------------------------------------------------

void binderoo::HostImplementation::collectDynamicLibraries()
{
	InternalStringVector vecFoundFiles( allocator );

	for( auto& searchPath : configuration.strDynamicLibSearchFolders )
	{
		WIN32_FIND_DATA		foundData;
		HANDLE				hFoundHandle = INVALID_HANDLE_VALUE;

		InternalString strSearchPath( searchPath.data(), searchPath.length(), allocator );
		std::replace( strSearchPath.begin(), strSearchPath.end(), '\\', '/' );

		if( strSearchPath.back() != '/' )
		{
			strSearchPath += '/';
		}

		InternalString strSearchPattern = strSearchPath;
		strSearchPattern += "*.dll";

		hFoundHandle = FindFirstFileEx( strSearchPattern.c_str(), FindExInfoStandard, &foundData, FindExSearchNameMatch, nullptr, 0 );

		BOOL bFound = hFoundHandle != INVALID_HANDLE_VALUE ? TRUE : FALSE;
		while( bFound )
		{
			InternalString fileName = InternalString( foundData.cFileName, allocator );
			std::replace( fileName.begin(), fileName.end(), '\\', '/' );
			InternalString fullFileName = strSearchPath;
			fullFileName += fileName;

			vecFoundFiles.push_back( fullFileName );

			bFound = FindNextFile( hFoundHandle, &foundData );
		}

		FindClose( hFoundHandle );
	}

	for( auto& libPath : vecFoundFiles )
	{
		size_t uSlashIndex = libPath.find_last_of( '/' );
		uSlashIndex = ( uSlashIndex == std::string::npos ? 0 : uSlashIndex );

		size_t uDotIndex = libPath.find_last_of( '.' );
		uDotIndex = ( uDotIndex == std::string::npos ? libPath.length() - 1 : uDotIndex );

		HostDynamicLib dynamicLib( allocator );
		dynamicLib.strName = libPath.substr( uSlashIndex + 1, uDotIndex - uSlashIndex - 1 );
		dynamicLib.strPath = libPath;
		dynamicLib.hModule = nullptr;
		dynamicLib.eStatus = DynamicLibStatus::NotLoaded;

		SetDllDirectory( libPath.substr( 0, uSlashIndex ).c_str() );

		if( loadDynamicLibrary( dynamicLib ) )
		{
			vecDynamicLibs.push_back( dynamicLib );
		}
	}
}
//----------------------------------------------------------------------------

bool binderoo::HostImplementation::loadDynamicLibrary( binderoo::HostDynamicLib& lib )
{
	HMODULE hModule = LoadLibrary( lib.strPath.c_str() );

	if( hModule != nullptr )
	{
		ImportFunctionsFromPtr		importFunctionsFrom		= ( ImportFunctionsFromPtr )GetProcAddress( hModule, "importFunctionsFrom" );
		GetExportedObjectsPtr		getExportedObjects		= ( GetExportedObjectsPtr )GetProcAddress( hModule, "getExportedObjects" );
		GetExportedFunctionsPtr		getExportedFunctions	= ( GetExportedFunctionsPtr )GetProcAddress( hModule, "getExportedFunctions" );
		CreateObjectByNamePtr		createObjectByName		= ( CreateObjectByNamePtr )GetProcAddress( hModule, "createObjectByName" );
		CreateObjectByHashPtr		createObjectByHash		= ( CreateObjectByHashPtr )GetProcAddress( hModule, "createObjectByHash" );
		DestroyObjectByNamePtr		destroyObjectByName		= ( DestroyObjectByNamePtr )GetProcAddress( hModule, "destroyObjectByName" );
		DestroyObjectByHashPtr		destroyObjectByHash		= ( DestroyObjectByHashPtr )GetProcAddress( hModule, "destroyObjectByHash" );
		GenerateBindingDeclarationsForAllObjectsPtr generateCPPStyleBindingDeclarationsForAllObjects = ( GenerateBindingDeclarationsForAllObjectsPtr )GetProcAddress( hModule, "generateCPPStyleBindingDeclarationsForAllObjects" );


		if( importFunctionsFrom && getExportedObjects && getExportedFunctions && createObjectByName && createObjectByHash && destroyObjectByName && destroyObjectByHash && generateCPPStyleBindingDeclarationsForAllObjects )
		{
			lib.hModule												= hModule;
			lib.eStatus												= DynamicLibStatus::Ready;
			lib.importFunctionsFrom									= importFunctionsFrom;
			lib.getExportedObjects									= getExportedObjects;
			lib.getExportedFunctions								= getExportedFunctions;
			lib.createObjectByName									= createObjectByName;
			lib.createObjectByHash									= createObjectByHash;
			lib.destroyObjectByName									= destroyObjectByName;
			lib.destroyObjectByHash									= destroyObjectByHash;
			lib.generateCPPStyleBindingDeclarationsForAllObjects	= generateCPPStyleBindingDeclarationsForAllObjects;

			lib.importFunctionsFrom( binderoo::Slice< binderoo::BoundFunction >( vecExportedFunctions.data(), vecExportedFunctions.size() ) );

			return true;
		}
		else
		{
			lib.eStatus					= DynamicLibStatus::CoreInterfaceNotFound;
			FreeLibrary( hModule );
		}
	}

	return false;
}
//----------------------------------------------------------------------------

void binderoo::HostImplementation::registerImportedClassInstance( binderoo::ImportedBase* pInstance )
{
}
//----------------------------------------------------------------------------

void binderoo::HostImplementation::deregisterImportedClassInstance( binderoo::ImportedBase* pInstance )
{
}
//----------------------------------------------------------------------------

void binderoo::HostImplementation::registerImportedFunction( binderoo::ImportedBase* pInstance )
{
	const BoundFunction* pFunction = getImportedFunctionDetails( pInstance->pSymbol );

	if( pFunction )
	{
		pInstance->pObjectInstance		= (void*)pFunction->pFunction;
		pInstance->pObjectDescriptor	= (void*)pFunction;
	}
}
//----------------------------------------------------------------------------

void binderoo::HostImplementation::deregisterImportedFunction( binderoo::ImportedBase* pInstance )
{
}
//----------------------------------------------------------------------------

void* binderoo::HostImplementation::createImportedClass( const char* pName )
{
	uint64_t uNameHash = fnv1a_64( pName, strlen( pName ) );

	for( auto& lib : vecDynamicLibs )
	{
		binderoo::Slice< binderoo::BoundObject > exportedObjects;
		lib.getExportedObjects( &exportedObjects );

		for( auto& exportedObject : exportedObjects )
		{
			if( exportedObject.uFullyQualifiedNameHash == uNameHash )
			{
				return lib.createObjectByHash( uNameHash );
			}
		}
	}
	
	return nullptr;
}
//----------------------------------------------------------------------------

bool binderoo::HostImplementation::destroyImportedClass( const char* pName, void* pObject )
{
	uint64_t uNameHash = fnv1a_64( pName, strlen( pName ) );

	for( auto& lib : vecDynamicLibs )
	{
		binderoo::Slice< binderoo::BoundObject > exportedObjects;
		lib.getExportedObjects( &exportedObjects );

		for( auto& exportedObject : exportedObjects )
		{
			if( exportedObject.uFullyQualifiedNameHash == uNameHash )
			{
				lib.destroyObjectByHash( uNameHash, pObject );
				return true;
			}
		}
	}

	return false;
}
//----------------------------------------------------------------------------

const binderoo::BoundFunction* binderoo::HostImplementation::getImportedFunctionDetails( const char* pName ) const
{
	for( auto& lib : vecDynamicLibs )
	{
		binderoo::Slice< binderoo::BoundFunction > exportedFunctions;
		lib.getExportedFunctions( &exportedFunctions );

		for( auto& exportedFunc : exportedFunctions )
		{
			if( strcmp( exportedFunc.strFunctionName.data(), pName ) == 0 )
			{
				return &exportedFunc;
			}
		}
	}

	return nullptr;
}
//----------------------------------------------------------------------------

const char* binderoo::HostImplementation::generateCPPStyleBindingDeclarationsForAllObjects()
{
	InternalStringVector vecAllDeclarations( allocator );

	const char* const pSeparator = "\n\n";
	const size_t uSeparatorLength = 2;

	size_t uRequiredSpace = 0;
	char* pOutput = nullptr;

	for( auto& lib : vecDynamicLibs )
	{
		const char* pDeclarations = lib.generateCPPStyleBindingDeclarationsForAllObjects( configuration.unaligned_alloc );

		InternalString strDeclarations( pDeclarations, strlen( pDeclarations ), allocator );
		vecAllDeclarations.push_back( strDeclarations );
		uRequiredSpace += strDeclarations.size();

		configuration.unaligned_free( (void*)pDeclarations );
	}

	if( !vecAllDeclarations.empty() )
	{
		uRequiredSpace += ( vecAllDeclarations.size() - 1 ) * uSeparatorLength + 1;

		pOutput = (char*)configuration.unaligned_alloc( uRequiredSpace );

		char* pDest = pOutput;

		for( auto& declarations : vecAllDeclarations )
		{
			if( pDest != pOutput )
			{
				memcpy( pDest, pSeparator, uSeparatorLength );
				pDest += uSeparatorLength;
			}

			memcpy( pDest, declarations.c_str(), declarations.size() );
			pDest += declarations.size();
		}

		*pDest = 0;
	}

	return pOutput;

}
//--------------------------------------------------------------------

//============================================================================
