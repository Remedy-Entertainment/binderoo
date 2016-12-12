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
#include "binderoo/containers.h"
#include "binderoo/exports.h"
#include "binderoo/hash.h"
#include "binderoo/imports.h"
#include "binderoo/sharedevent.h"
#include "binderoo/slice.h"

#include <unordered_map>
#include <vector>
#include <string>
#include <algorithm>

#include <Windows.h>
#pragma warning( push )
#pragma warning( disable: 4091 )
#include <DbgHelp.h>
#pragma warning( pop )

#pragma comment( lib, "dbghelp.lib" )
#pragma comment( lib, "Rpcrt4.lib" )
//----------------------------------------------------------------------------

binderoo::AllocatorFunc				binderoo::AllocatorFunctions< binderoo::AllocatorSpace::Host >::fAlloc		= nullptr;
binderoo::DeallocatorFunc			binderoo::AllocatorFunctions< binderoo::AllocatorSpace::Host >::fFree		= nullptr;
binderoo::CAllocatorFunc			binderoo::AllocatorFunctions< binderoo::AllocatorSpace::Host >::fCalloc		= nullptr;
binderoo::ReallocatorFunc			binderoo::AllocatorFunctions< binderoo::AllocatorSpace::Host >::fRealloc	= nullptr;

binderoo::Host*	binderoo::Host::pActiveHost																		= nullptr;
//----------------------------------------------------------------------------

namespace binderoo
{
	typedef Containers< AllocatorSpace::Host >::InternalString												InternalString;
	typedef std::vector< InternalString, binderoo::Allocator< AllocatorSpace::Host, InternalString > >		InternalStringVector;

	typedef void					( BIND_C_CALL *ImportFunctionsFromPtr )									( binderoo::Slice< binderoo::BoundFunction > functions );
	typedef void					( BIND_C_CALL *GetExportedObjectsPtr )									( binderoo::Slice< binderoo::BoundObject >* pOutExportedObjects );
	typedef void					( BIND_C_CALL *GetExportedFunctionsPtr )								( binderoo::Slice< binderoo::BoundFunction >* pOutExportedFunctions );
	typedef void*					( BIND_C_CALL *CreateObjectByNamePtr )									( DString strName );
	typedef void*					( BIND_C_CALL *CreateObjectByHashPtr )									( uint64_t uNameHash );
	typedef void					( BIND_C_CALL *DestroyObjectByNamePtr )									( DString, void* pObject );
	typedef void					( BIND_C_CALL *DestroyObjectByHashPtr )									( uint64_t, void* pObject );
	typedef const char*				( BIND_C_CALL *GenerateBindingDeclarationsForAllObjectsPtr )			( UnalignedAllocatorFunc allocator, const char* pVersion );
	//------------------------------------------------------------------------

	enum class DynamicLibStatus : int
	{
		NotLoaded,
		LoadFailed,
		CoreInterfaceNotFound,
		Unloaded,

		Ready,

		Max,
		Min = 0
	};
	//------------------------------------------------------------------------

	static const char* pDynamicLibStatusMessages[] =
	{
		"Not loaded",						// NotLoaded
		"Load failed",						// LoadFailed
		"Core interface not found",			// CoreInterfaceNotFound
		"Unloaded",							// Unloaded
		"Ready",							// Ready
	};
	//------------------------------------------------------------------------

	struct HostDynamicLib
	{
		HostDynamicLib()
			: hModule( nullptr )
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
		//--------------------------------------------------------------------

		InternalString									strName;
		InternalString									strPath;
		InternalString									strScratchPath;
		InternalString									strScratchLib;
		InternalString									strScratchSymbols;
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

	template< typename _ty >
	struct HostBinding
	{
		typedef typename _ty BoundType;

		HostBinding()
			: pLibrary( nullptr )
			, pObject( nullptr )
			, uSearchHash( 0 )
		{
		}
		//--------------------------------------------------------------------

		BIND_INLINE bool operator==( const BoundType* pRHS ) const				{ return pObject == pRHS; }
		BIND_INLINE bool operator==( const uint64_t RHS ) const					{ return uSearchHash == RHS; }
		//--------------------------------------------------------------------

		HostDynamicLib*									pLibrary;
		BoundType*										pObject;
		uint64_t										uSearchHash;
	};
	//------------------------------------------------------------------------

	typedef HostBinding< BoundFunction >																	HostBoundFunction;
	typedef HostBinding< BoundObject >																		HostBoundObject;
	//------------------------------------------------------------------------

	struct HostImportedObjectInstance
	{
		HostImportedObjectInstance()
			: pInstance( nullptr )
		{
		}
		//--------------------------------------------------------------------

		BIND_INLINE bool operator==( const ImportedBase* pRHS ) const			{ return pInstance == pRHS; }
		//--------------------------------------------------------------------

		InternalString									strReloadData;
		ImportedBase*									pInstance;
	};
	//------------------------------------------------------------------------

	class HostImplementation // It doesn't look like anything to me.
	{
	public:
		typedef Allocator< AllocatorSpace::Host, void, 16 >													DefaultAllocator;

		typedef Allocator< AllocatorSpace::Host, BoundFunction >											FunctionAllocator;
		typedef std::vector< BoundFunction, FunctionAllocator >												FunctionVector;

		typedef binderoo::FNV1aHasher< BoundFunction::Hashes >												FunctionMapHasher;
		typedef std::pair< const BoundFunction::Hashes, size_t >											FunctionMapPair;
		typedef Allocator< AllocatorSpace::Host, FunctionMapPair >											FunctionMapAllocator;

		typedef std::equal_to< BoundFunction::Hashes >														FunctionMapComparer;
		typedef std::unordered_map< BoundFunction::Hashes, size_t, FunctionMapHasher, FunctionMapComparer, FunctionMapAllocator >	FunctionMap;

		typedef std::vector< HostDynamicLib, Allocator< AllocatorSpace::Host, HostDynamicLib > >			DynamicLibVector;
		typedef std::vector< HostBoundFunction, Allocator< AllocatorSpace::Host, HostBoundFunction > >		HostBoundFunctionVector;
		typedef std::vector< HostBoundObject, Allocator< AllocatorSpace::Host, HostBoundObject > >			HostBoundObjectVector;

		typedef std::vector< binderoo::ImportedBase*, binderoo::Allocator< AllocatorSpace::Host, binderoo::ImportedBase* > > ImportedFunctionVector;
		typedef std::vector< HostImportedObjectInstance, binderoo::Allocator< AllocatorSpace::Host, HostImportedObjectInstance > > ImportedObjectVector;
		//--------------------------------------------------------------------

		HostImplementation( HostConfiguration& config );
		//--------------------------------------------------------------------

		void						setRapidIterationMode( bool bSet );
		bool						isInRapidIterationMode( ) const;
		//--------------------------------------------------------------------

		bool						checkForReloads();
		void						performReloads();
		//--------------------------------------------------------------------

		void						saveObjectData();
		void						loadObjectData();
		//--------------------------------------------------------------------

		void						performLoad();
		void						performUnload();
		//--------------------------------------------------------------------

		void						destroyImportedObjects();
		void						recreateImportedObjects();
		//--------------------------------------------------------------------

		void						collectExports();
		void						collectDynamicLibraries();
		void						collectBoundFunctions();
		void						collectBoundObjects();
		//--------------------------------------------------------------------

		bool						loadDynamicLibrary( HostDynamicLib& lib );
		void						unloadDynamicLibrary( HostDynamicLib& lib );
		//--------------------------------------------------------------------

		void						registerImportedClassInstance( ImportedBase* pInstance );
		void						deregisterImportedClassInstance( ImportedBase* pInstance );

		void						registerImportedFunction( ImportedBase* pInstance );
		void						deregisterImportedFunction( ImportedBase* pInstance );
		//--------------------------------------------------------------------

		void*						createImportedClass( const char* pName );
		bool						destroyImportedClass( const char* pName, void* pObject );
		//--------------------------------------------------------------------

		const HostBoundFunction*	getImportedFunctionDetails( const char* pName ) const;
		const HostBoundObject*		getImportedObjectDetails( const char* pName ) const;
		//--------------------------------------------------------------------

		const char*					generateCPPStyleBindingDeclarationsForAllObjects( const char* pVersions );
		//--------------------------------------------------------------------

	private:
		void						logInfo( const char* pMessage );
		void						logWarning( const char* pMessage );
		void						logError( const char* pMessage );

		HostConfiguration&			configuration;

		SharedEvent					reloadEvent;

		FunctionMap					mapExportedFunctionIndices;
		FunctionVector				vecExportedFunctions;

		DynamicLibVector			vecDynamicLibs;
		HostBoundFunctionVector		vecBoundFunctions;
		HostBoundObjectVector		vecBoundObjects;

		ImportedFunctionVector		vecImportFunctionInstances;
		ImportedObjectVector		vecImportClassInstances;

		bool						bReloadLibs;
		bool						bInRapidIterationMode;
	};
	//------------------------------------------------------------------------
}
//----------------------------------------------------------------------------

binderoo::Host::Host( binderoo::HostConfiguration& config )
	: configuration( config )
	, pImplementation( nullptr )
{
	AllocatorFunctions< AllocatorSpace::Host >::setup( config.alloc, config.free, config.calloc, config.realloc );

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

void binderoo::Host::setRapidIterationMode( bool bSet )
{
	pImplementation->setRapidIterationMode( bSet );
}
//----------------------------------------------------------------------------

bool binderoo::Host::isInRapidIterationMode( ) const
{
	return pImplementation->isInRapidIterationMode();
}
//----------------------------------------------------------------------------

bool binderoo::Host::checkForReloads()
{
	return pImplementation->checkForReloads();
}
//----------------------------------------------------------------------------

void binderoo::Host::performReloads()
{
	pImplementation->performReloads();
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
	const HostBoundFunction* pFunc = pImplementation->getImportedFunctionDetails( pName );

	return pFunc ? pFunc->pObject : nullptr;
}
//--------------------------------------------------------------------

const char* binderoo::Host::generateCPPStyleBindingDeclarationsForAllObjects( const char* pVersions )
{
	return pImplementation->generateCPPStyleBindingDeclarationsForAllObjects( pVersions );
}
//----------------------------------------------------------------------------
//----------------------------------------------------------------------------

// HostImplementation
//----------------------------------------------------------------------------

binderoo::HostImplementation::HostImplementation( HostConfiguration& config )
	: configuration( config )
	, reloadEvent( "binderoo_service_reload" )
	, bInRapidIterationMode( config.bStartInRapidIterationMode )
	, bReloadLibs( false )
{
	collectExports();

	performLoad();
}
//----------------------------------------------------------------------------

void binderoo::HostImplementation::setRapidIterationMode( bool bSet )
{
	if( bInRapidIterationMode != bSet )
	{
		bReloadLibs = true;
	}
	bInRapidIterationMode = bSet;
}
//----------------------------------------------------------------------------

bool binderoo::HostImplementation::isInRapidIterationMode( ) const
{
	return bInRapidIterationMode;
}
//----------------------------------------------------------------------------

bool binderoo::HostImplementation::checkForReloads()
{
	bReloadLibs |= ( reloadEvent.waitOn( 0 ) && bInRapidIterationMode );
	return bReloadLibs;
}
//----------------------------------------------------------------------------

void binderoo::HostImplementation::performReloads()
{
	logInfo( "Reload triggered." );

	saveObjectData();
	destroyImportedObjects();
	performUnload();

	logInfo( "Unload completed. Moving on to reload." );

	performLoad();
	recreateImportedObjects();
	loadObjectData();

	logInfo( "Reload completed." );

	bReloadLibs = false;
}
//----------------------------------------------------------------------------

void binderoo::HostImplementation::saveObjectData()
{
	for( HostImportedObjectInstance& obj : vecImportClassInstances )
	{
		if( obj.pInstance->pObjectInstance )
		{
			const HostBoundObject* pObjDescriptor = (const HostBoundObject*)obj.pInstance->pObjectDescriptor;
			obj.strReloadData = pObjDescriptor->pObject->serialise( obj.pInstance->pObjectInstance );
		}
		else
		{
			obj.strReloadData.clear();
		}
	}
}
//----------------------------------------------------------------------------

void binderoo::HostImplementation::loadObjectData()
{
	for( HostImportedObjectInstance& obj : vecImportClassInstances )
	{
		if( !obj.strReloadData.empty() )
		{
			const HostBoundObject* pObjDescriptor = (const HostBoundObject*)obj.pInstance->pObjectDescriptor;
			pObjDescriptor->pObject->deserialise( obj.pInstance->pObjectInstance, obj.strReloadData.c_str() );
			obj.strReloadData.clear();
		}
	}
}
//----------------------------------------------------------------------------

void binderoo::HostImplementation::performLoad()
{
	vecDynamicLibs.clear();
	vecBoundFunctions.clear();
	vecBoundObjects.clear();

	collectDynamicLibraries();
	collectBoundFunctions();
	collectBoundObjects();
}
//----------------------------------------------------------------------------

void binderoo::HostImplementation::performUnload()
{
	destroyImportedObjects();

	vecBoundObjects.clear();
	vecBoundFunctions.clear();

	for( HostDynamicLib& lib : vecDynamicLibs )
	{
		unloadDynamicLibrary( lib );
	}

	vecDynamicLibs.clear();
}
//----------------------------------------------------------------------------

void binderoo::HostImplementation::destroyImportedObjects()
{
	for( HostImportedObjectInstance& obj : vecImportClassInstances )
	{
		if( obj.pInstance->pObjectInstance )
		{
			const HostBoundObject* pObjDescriptor = (const HostBoundObject*)obj.pInstance->pObjectDescriptor;
			pObjDescriptor->pObject->free( obj.pInstance->pObjectInstance );
			obj.pInstance->pObjectInstance = nullptr;
		}

		obj.pInstance->pObjectDescriptor = nullptr;
	}

	for( binderoo::ImportedBase*& pImportedFunction : vecImportFunctionInstances )
	{
		pImportedFunction->pObjectDescriptor = nullptr;
		pImportedFunction->pObjectInstance = nullptr;
	}
}
//----------------------------------------------------------------------------

void binderoo::HostImplementation::recreateImportedObjects()
{
	for( binderoo::ImportedBase*& pImportedFunction : vecImportFunctionInstances )
	{
		const HostBoundFunction* pFunction = getImportedFunctionDetails( pImportedFunction->pSymbol );

		if( pFunction )
		{
			pImportedFunction->pObjectInstance		= (void*)pFunction->pObject->pFunction;
			pImportedFunction->pObjectDescriptor		= (void*)pFunction;
		}
	}

	for( HostImportedObjectInstance& obj : vecImportClassInstances )
	{
		const HostBoundObject* pObject = getImportedObjectDetails( obj.pInstance->pSymbol );
		if( pObject )
		{
			obj.pInstance->pObjectDescriptor = (void*)pObject;
			if( !obj.strReloadData.empty() )
			{
				obj.pInstance->pObjectInstance = pObject->pObject->alloc( 1 );
			}
		}
	}
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
	InternalStringVector vecFoundFiles;

	for( auto& searchPath : configuration.strDynamicLibSearchFolders )
	{
		WIN32_FIND_DATA		foundData;
		HANDLE				hFoundHandle = INVALID_HANDLE_VALUE;

		InternalString strSearchPath( searchPath.data(), searchPath.length() );
		std::replace( strSearchPath.begin(), strSearchPath.end(), '\\', '/' );

		if( strSearchPath.back() != '/' )
		{
			strSearchPath += '/';
		}

		if( bInRapidIterationMode )
		{
			strSearchPath += "/rapid/";
		}

		InternalString strSearchPattern = strSearchPath;
		strSearchPattern += "*.dll";

		hFoundHandle = FindFirstFileEx( strSearchPattern.c_str(), FindExInfoStandard, &foundData, FindExSearchNameMatch, nullptr, 0 );

		BOOL bFound = hFoundHandle != INVALID_HANDLE_VALUE ? TRUE : FALSE;
		while( bFound )
		{
			InternalString fileName = InternalString( foundData.cFileName );
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

		HostDynamicLib dynamicLib;
		dynamicLib.strName = libPath.substr( uSlashIndex + 1, uDotIndex - uSlashIndex - 1 );
		dynamicLib.strPath = libPath;
		dynamicLib.hModule = nullptr;
		dynamicLib.eStatus = DynamicLibStatus::NotLoaded;

		InternalString strNotification = "Library \"";
		strNotification += dynamicLib.strName;

		if( loadDynamicLibrary( dynamicLib ) )
		{
			strNotification += "\" ";
			if( bInRapidIterationMode )
			{
				strNotification += "(rapid iteration mode) ";
			}
			strNotification += "loaded successfully.";
			logInfo( strNotification.c_str() );
			vecDynamicLibs.push_back( dynamicLib );
		}
		else
		{
			strNotification += "\" ";
			if( bInRapidIterationMode )
			{
				strNotification += "(rapid iteration mode) ";
			}
			strNotification += "failed to load. Status: ";
			strNotification += pDynamicLibStatusMessages[ (int)dynamicLib.eStatus ];

			logError( strNotification.c_str() );
		}
	}
}
//----------------------------------------------------------------------------

void binderoo::HostImplementation::collectBoundFunctions()
{
	size_t uReserveSize = 0;

	for( auto& lib : vecDynamicLibs )
	{
		binderoo::Slice< binderoo::BoundFunction > exportedFunctions;
		lib.getExportedFunctions( &exportedFunctions );

		uReserveSize += exportedFunctions.length();
	}

	vecBoundFunctions.reserve( uReserveSize );


	for( auto& lib : vecDynamicLibs )
	{
		binderoo::Slice< binderoo::BoundFunction > exportedFunctions;
		lib.getExportedFunctions( &exportedFunctions );

		for( auto& exportedFunc : exportedFunctions )
		{
			HostBoundFunction func;
			func.pLibrary = &lib;
			func.pObject = &exportedFunc;
			func.uSearchHash = exportedFunc.functionHashes.uFunctionNameHash;

			vecBoundFunctions.push_back( func );
		}
	}

}
//----------------------------------------------------------------------------

void binderoo::HostImplementation::collectBoundObjects()
{
	size_t uReserveSize = 0;

	for( auto& lib : vecDynamicLibs )
	{
		binderoo::Slice< binderoo::BoundObject > exportedObjects;
		lib.getExportedObjects( &exportedObjects );

		uReserveSize += exportedObjects.length();
	}

	vecBoundObjects.reserve( uReserveSize );

	for( auto& lib : vecDynamicLibs )
	{
		binderoo::Slice< binderoo::BoundObject > exportedObjects;
		lib.getExportedObjects( &exportedObjects );

		for( auto& exportedObject : exportedObjects )
		{
			HostBoundObject obj;
			obj.pLibrary = &lib;
			obj.pObject = &exportedObject;
			obj.uSearchHash = exportedObject.uFullyQualifiedNameHash;

			vecBoundObjects.push_back( obj );
		}
	}
}
//----------------------------------------------------------------------------

bool binderoo::HostImplementation::loadDynamicLibrary( binderoo::HostDynamicLib& lib )
{
	InternalString strTempPath;
	DWORD dTempPathLength = GetTempPath( 0, nullptr );
	strTempPath.resize( dTempPathLength - 1 );
	GetTempPath( dTempPathLength, (char*)strTempPath.data() );
	std::replace( strTempPath.begin(), strTempPath.end(), '\\', '/' );
	strTempPath += "binderoo/";

	DWORD dPathAttributes = GetFileAttributes( strTempPath.c_str() );
	if( dPathAttributes == INVALID_FILE_ATTRIBUTES || ( dPathAttributes & FILE_ATTRIBUTE_DIRECTORY ) == 0 )
	{
		CreateDirectory( strTempPath.c_str(), nullptr );
	}

	UUID newUUID;
	RPC_STATUS uResult = UuidCreate( &newUUID );
	InternalString strUUID;

	const char* pCurr = (const char*)&newUUID;
	const char* pEnd = pCurr + sizeof( UUID );
	while( pCurr != pEnd )
	{
		char outBuffer[ 8 ] = { 0, 0, 0, 0, 0, 0, 0, 0 };
		snprintf( outBuffer, 8, "%02x", *(unsigned char*)pCurr );
		strUUID += outBuffer;
		++pCurr;
	}

	strTempPath += strUUID + "/";
	dPathAttributes = GetFileAttributes( strTempPath.c_str() );
	if( dPathAttributes == INVALID_FILE_ATTRIBUTES || ( dPathAttributes & FILE_ATTRIBUTE_DIRECTORY ) == 0 )
	{
		CreateDirectory( strTempPath.c_str(), nullptr );
	}

	lib.strScratchPath = strTempPath;
	lib.strScratchLib = strTempPath + lib.strName + ".dll";
	lib.strScratchSymbols = strTempPath + lib.strName + ".pdb";

	BOOL bSuccess = CopyFile( lib.strPath.c_str(), lib.strScratchLib.c_str(), FALSE );

	{
		InternalString strPDBSource = lib.strPath;

		strPDBSource.replace( strPDBSource.find_last_of( "." ), 4, ".pdb" );

		DWORD dPDBAttributes = GetFileAttributes( strPDBSource.c_str() );
		if( dPDBAttributes != INVALID_FILE_ATTRIBUTES )
		{
			CopyFile( strPDBSource.c_str(), lib.strScratchSymbols.c_str(), FALSE );
		}
	}

	SetDllDirectory( strTempPath.c_str() );
	HMODULE hModule = LoadLibrary( lib.strScratchLib.c_str() );

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
			unloadDynamicLibrary( lib );
			lib.eStatus = DynamicLibStatus::CoreInterfaceNotFound;
		}
	}

	return false;
}
//----------------------------------------------------------------------------

void binderoo::HostImplementation::unloadDynamicLibrary( binderoo::HostDynamicLib& lib )
{
	HANDLE hProcess = GetCurrentProcess();

	auto pRelevantFunction = &binderoo::HostImplementation::performUnload;

	DWORD64 dwModuleBase = SymGetModuleBase64( hProcess, *(DWORD64*)&pRelevantFunction );
	if( dwModuleBase != 0 )
	{
		SymUnloadModule64( hProcess, dwModuleBase );
	}

	FreeLibrary( lib.hModule );

	InternalString strErrorMessage = "Failed to delete ";
	if( !DeleteFile( lib.strScratchSymbols.c_str() ) )
	{
		logWarning( (strErrorMessage + lib.strScratchSymbols ).c_str() );
	}
	if( !DeleteFile( lib.strScratchLib.c_str() ) )
	{
		logWarning( (strErrorMessage + lib.strScratchSymbols ).c_str() );
	}
	if( !RemoveDirectory( lib.strScratchPath.c_str() ) )
	{
		logWarning( (strErrorMessage + lib.strScratchSymbols ).c_str() );
	}

	lib.eStatus = DynamicLibStatus::Unloaded;
}
//----------------------------------------------------------------------------

void binderoo::HostImplementation::registerImportedClassInstance( binderoo::ImportedBase* pInstance )
{
	const HostBoundObject* pObject = getImportedObjectDetails( pInstance->pSymbol );

	if( pObject )
	{
		pInstance->pObjectDescriptor = (void*)pObject;
	}

	HostImportedObjectInstance objInstance;
	objInstance.pInstance = pInstance;

	vecImportClassInstances.push_back( objInstance );
}
//----------------------------------------------------------------------------

void binderoo::HostImplementation::deregisterImportedClassInstance( binderoo::ImportedBase* pInstance )
{
	// VS2012 was having issues with std::find and a lambda, so the comparison is in the type now...
	auto found = std::find( vecImportClassInstances.begin(), vecImportClassInstances.end(), pInstance );

	if( found != vecImportClassInstances.end() )
	{
		found->pInstance->pObjectDescriptor = nullptr;

		vecImportClassInstances.erase( found );
	}
}
//----------------------------------------------------------------------------

void binderoo::HostImplementation::registerImportedFunction( binderoo::ImportedBase* pInstance )
{
	const HostBoundFunction* pFunction = getImportedFunctionDetails( pInstance->pSymbol );

	if( pFunction )
	{
		pInstance->pObjectInstance		= (void*)pFunction->pObject->pFunction;
		pInstance->pObjectDescriptor		= (void*)pFunction;
	}

	vecImportFunctionInstances.push_back( pInstance );
}
//----------------------------------------------------------------------------

void binderoo::HostImplementation::deregisterImportedFunction( binderoo::ImportedBase* pInstance )
{
	auto found = std::find( vecImportFunctionInstances.begin(), vecImportFunctionInstances.end(), pInstance );
	if( found != vecImportFunctionInstances.end() )
	{
		vecImportFunctionInstances.erase( found );

		pInstance->pObjectDescriptor = nullptr;
		pInstance->pObjectInstance = nullptr;
	}
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

const binderoo::HostBoundFunction* binderoo::HostImplementation::getImportedFunctionDetails( const char* pName ) const
{
	uint64_t uNameHash = fnv1a_64( pName, strlen( pName ) );

	// VS2012 was having issues with std::find and a lambda, so the comparison is in the type now...
	auto found = std::find( vecBoundFunctions.begin(), vecBoundFunctions.end(), uNameHash );

	if( found != vecBoundFunctions.end() )
	{
		// The return of my most hated operation - dereference the iterator to get the address of the object...
		return &*found;
	}

	return nullptr;
}
//----------------------------------------------------------------------------

const binderoo::HostBoundObject* binderoo::HostImplementation::getImportedObjectDetails( const char* pName ) const
{
	uint64_t uNameHash = fnv1a_64( pName, strlen( pName ) );

	// VS2012 was having issues with std::find and a lambda, so the comparison is in the type now...
	auto found = std::find( vecBoundObjects.begin(), vecBoundObjects.end(), uNameHash );

	if( found != vecBoundObjects.end() )
	{
		// The return of my most hated operation - dereference the iterator to get the address of the object...
		return &*found;
	}

	return nullptr;
}
//----------------------------------------------------------------------------
//----------------------------------------------------------------------------

const char* binderoo::HostImplementation::generateCPPStyleBindingDeclarationsForAllObjects( const char* pVersions )
{
	InternalStringVector vecVersions;
	InternalStringVector vecAllDeclarations;

	const char* pVersionCurr = pVersions;
	const char* pVersionStart = pVersions;

	while( pVersionCurr )
	{
		if( *pVersionCurr )
		{
			if( *pVersionCurr == ';' )
			{
				vecVersions.push_back( InternalString( pVersionStart, (size_t)( pVersionCurr - pVersionStart ) ) );
				pVersionStart = ++pVersionCurr;
			}
			else
			{
				++pVersionCurr;
			}
		}
		else
		{
			if( pVersionCurr != pVersionStart )
			{
				vecVersions.push_back( InternalString( pVersionStart, (size_t)( pVersionCurr - pVersionStart ) ) );
			}
			pVersionCurr = nullptr;
		}
	}

	const char* const pSeparator = "\n\n";
	const size_t uSeparatorLength = 2;

	size_t uRequiredSpace = 0;
	char* pOutput = nullptr;

	for( auto& lib : vecDynamicLibs )
	{
		const char* pDeclarations = lib.generateCPPStyleBindingDeclarationsForAllObjects( configuration.unaligned_alloc, nullptr );

		InternalString strDeclarations( pDeclarations, strlen( pDeclarations ) );
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
//----------------------------------------------------------------------------

void binderoo::HostImplementation::logInfo( const char* pMessage )
{
	if( configuration.log_info )
	{
		configuration.log_info( pMessage );
	}
}
//----------------------------------------------------------------------------

void binderoo::HostImplementation::logWarning( const char* pMessage )
{
	if( configuration.log_warning )
	{
		configuration.log_warning( pMessage );
	}
}
//----------------------------------------------------------------------------

void binderoo::HostImplementation::logError( const char* pMessage )
{
	if( configuration.log_error )
	{
		configuration.log_error( pMessage );
	}
}
//----------------------------------------------------------------------------

//============================================================================
