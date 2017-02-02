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

#if !defined( _BINDEROO_SERVICE_H_ )
#define _BINDEROO_SERVICE_H_

#include "binderoo/defs.h"
#include "binderoo/allocator.h"
#include "binderoo/slice.h"

#include "binderoo/monitoredfolder.h"

namespace binderoo
{
	enum class CompilerType : int32_t
	{
		Unknown = -1,
		DMD,
		LDC,
	};

	struct Compiler
	{
		Compiler()
			: eType( CompilerType::Unknown ) { }

		union PlatformConfig
		{
			PlatformConfig() { }

			struct WindowsSpecific
			{
				WindowsSpecific() { }

				DString							strVisualStudioInstallDir;
				DString							strVisualStudioVersion;
				DString							strWindowsSdkDir;
			} windows;
		};

		DString								strCompilerLocation;
		PlatformConfig						platformConfig;
		CompilerType						eType;
	};

	struct ModuleVersion
	{
		BIND_INLINE ModuleVersion() { }
		BIND_INLINE ModuleVersion( const DString versionName, const Slice< DString > tokens )
			: strVersionName( versionName )
			, versionTokens( tokens ) { }

		DString								strVersionName;
		Slice< DString >					versionTokens;
	};

	typedef fastdelegate::FastDelegate0< void > ThreadOSUpdateFunction;
	typedef fastdelegate::FastDelegate1< ThreadOSUpdateFunction, int32_t >	ThreadRunFunction;

	typedef void*(* ThreadCreateFunction )( ThreadRunFunction threadEntryPoint );
	typedef void(* ThreadSleepFunction )( size_t uMilliszeonds );
	typedef void(* ThreadWaitOnFunction )( void* pThread );
	typedef bool(* ThreadIsRunningFunction )( void* pThread );
	typedef void(* ThreadDestroyFunction )( void* pThread );

	typedef void(* LogInfoFunction )( const char* );
	typedef void(* LogWarningFunction )( const char* );
	typedef void(* LogErrorFunction )( const char* );
	//------------------------------------------------------------------------

	struct ServiceConfiguration
	{
		BIND_INLINE ServiceConfiguration()
			: eCurrentCompiler( CompilerType::Unknown )
			, alloc( nullptr )
			, free( nullptr )
			, calloc( nullptr )
			, realloc( nullptr )
			, unaligned_alloc( nullptr )
			, unaligned_free( nullptr )
			, create_thread( nullptr )
			, sleep_thread( nullptr )
			, destroy_thread( nullptr )
			, bStartInRapidIterationMode( false )
		{
		}

		Slice< Compiler >					compilers;
		Slice< MonitoredFolder >			folders;
		Slice< ModuleVersion >				versions;

		CompilerType						eCurrentCompiler;

		AllocatorFunc						alloc;
		DeallocatorFunc						free;
		CAllocatorFunc						calloc;
		ReallocatorFunc						realloc;

		UnalignedAllocatorFunc				unaligned_alloc;
		UnalignedDeallocatorFunc			unaligned_free;

		ThreadCreateFunction				create_thread;
		ThreadSleepFunction					sleep_thread;
		ThreadWaitOnFunction				wait_on_thread;
		ThreadIsRunningFunction				is_thread_running;
		ThreadDestroyFunction				destroy_thread;

		LogInfoFunction						log_info;
		LogWarningFunction					log_warning;
		LogErrorFunction					log_error;

		bool								bStartInRapidIterationMode;
	};
	//------------------------------------------------------------------------

	class ServiceImplementation;

	typedef fastdelegate::FastDelegate1< bool, void > CompileFinishedCallback;
	//------------------------------------------------------------------------

	class BIND_DLL Service
	{
	public:
		Service( ServiceConfiguration& configuration );
		~Service();
		//--------------------------------------------------------------------

		void						setRapidIterationMode( bool bSet );
		bool						isInRapidIterationMode( ) const;
		void						compileClients( CompileFinishedCallback callWhenDone );
		void						compileClientBlocking( MonitoredFolder& thisClient );
		//--------------------------------------------------------------------

		static BIND_INLINE Service*	getInstance()								{ return spInstance; }
		//--------------------------------------------------------------------

	private:
		ServiceConfiguration		config;
		ServiceImplementation*		pImplementation;

		static Service*				spInstance;
	};
	//------------------------------------------------------------------------

	struct BIND_DLL DisableServiceRapidIteration
	{
		enum : int32_t
		{
			NoService = -1,
			WasDisabled = 0,
			WasEnabled = 1,
		};
		//--------------------------------------------------------------------

	public:
		BIND_INLINE DisableServiceRapidIteration()
			: eDisabledStatus( NoService )
		{
			binderoo::Service* pService = binderoo::Service::getInstance();
			if( pService )
			{
				eDisabledStatus = pService->isInRapidIterationMode() ? WasEnabled : WasDisabled;
				pService->setRapidIterationMode( false );
			}
		}
		//--------------------------------------------------------------------

		BIND_INLINE ~DisableServiceRapidIteration()
		{
			if( eDisabledStatus != NoService )
			{
				binderoo::Service* pService = binderoo::Service::getInstance();
				if( pService )
				{
					pService->setRapidIterationMode( eDisabledStatus == WasEnabled );
				}
			}
		}
		//--------------------------------------------------------------------

	private:
		int32_t						eDisabledStatus;
	};
	//------------------------------------------------------------------------
}
//----------------------------------------------------------------------------

#endif // !defined( _BINDEROO_SERVICE_H_ )

//============================================================================
