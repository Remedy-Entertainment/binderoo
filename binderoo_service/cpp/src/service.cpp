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

#include "service.h"
#include "filewatcher.h"

#include "binderoo/fileutils.h"

#include <atomic>
#include <map>
#include <set>

#include <Windows.h>
//----------------------------------------------------------------------------

binderoo::AllocatorFunc				binderoo::AllocatorFunctions< binderoo::AllocatorSpace::Service >::alloc		= nullptr;
binderoo::DeallocatorFunc			binderoo::AllocatorFunctions< binderoo::AllocatorSpace::Service >::free			= nullptr;
binderoo::CAllocatorFunc			binderoo::AllocatorFunctions< binderoo::AllocatorSpace::Service >::calloc		= nullptr;
binderoo::ReallocatorFunc			binderoo::AllocatorFunctions< binderoo::AllocatorSpace::Service >::realloc		= nullptr;
//----------------------------------------------------------------------------

namespace binderoo
{
	class Process
	{
	public:
		Process( const Containers< AllocatorSpace::Service >::InternalString& programLocation, const Containers< AllocatorSpace::Service >::InternalString& workingLocation, const Containers< AllocatorSpace::Service >::InternalString& parameters, const Containers< AllocatorSpace::Service >::StringVector& environmentVariables, bool bSynchronous = true )
			: strProgramLocation( programLocation )
			, strProgramParameters( parameters )
			, hStdOutputRead( nullptr )
			, hStdOutputWrite( nullptr )
			, hStdErrorRead( nullptr )
			, hStdErrorWrite( nullptr )
			, dReturnCode( 0 )
			, bLaunched( FALSE )
		{
			prepareEnvironmentVariables( environmentVariables );

			ZeroMemory( &startupInfo, sizeof( STARTUPINFO ) );
			ZeroMemory( &processInfo, sizeof( PROCESS_INFORMATION ) );

			SECURITY_ATTRIBUTES security;
			security.nLength				= sizeof( SECURITY_ATTRIBUTES );
			security.bInheritHandle			= TRUE;
			security.lpSecurityDescriptor	= NULL;

			BOOL bCreatedPipe = CreatePipe( &hStdOutputRead, &hStdOutputWrite, &security, 0 )
								&& CreatePipe( &hStdErrorRead, &hStdErrorWrite, &security, 0 );

			if( bCreatedPipe )
			{
				SetHandleInformation( hStdErrorRead, HANDLE_FLAG_INHERIT, 0 );
				SetHandleInformation( hStdOutputRead, HANDLE_FLAG_INHERIT, 0 );

				startupInfo.cb					= sizeof( STARTUPINFO );
				startupInfo.lpTitle				= "Binderoo files compiling...";
				startupInfo.hStdOutput			= hStdOutputWrite;
				startupInfo.hStdError			= hStdErrorWrite;
				startupInfo.hStdInput			= GetStdHandle( STD_INPUT_HANDLE );
				startupInfo.dwFlags				= STARTF_USESHOWWINDOW | STARTF_USESTDHANDLES | STARTF_PREVENTPINNING;
				startupInfo.wShowWindow			= SW_HIDE;

				bLaunched = CreateProcess( strProgramLocation.c_str(), (char*)strProgramParameters.c_str(), NULL, NULL, TRUE, CREATE_NEW_CONSOLE, (void*)vecEnvironmentVariables.data(), workingLocation.c_str(), &startupInfo, &processInfo );

				if( bSynchronous )
				{
					waitForProgramEnd();
				}
			}
		}
		//--------------------------------------------------------------------

		~Process()
		{
			CloseHandle( processInfo.hThread );
			CloseHandle( processInfo.hProcess );
			CloseHandle( hStdErrorRead );
			CloseHandle( hStdErrorWrite );
			CloseHandle( hStdOutputRead );
			CloseHandle( hStdOutputWrite );
		}
		//--------------------------------------------------------------------

		BIND_INLINE bool		launched() const								{ return bLaunched != FALSE; }
		BIND_INLINE bool		running() const
		{
			if( !launched() )
			{
				return false;
			}
			DWORD dCode = 0;
			BOOL bSucceeded = GetExitCodeProcess( processInfo.hProcess, &dCode );
			return bSucceeded != FALSE && dCode == STILL_ACTIVE;
		}
		//--------------------------------------------------------------------

		void					updateObjects()
		{
			updateStdStream( hStdOutputRead, strStdOut );
			updateStdStream( hStdErrorRead, strStdError );

			GetExitCodeProcess( processInfo.hProcess, &dReturnCode );
		}
		//--------------------------------------------------------------------

		void					waitForProgramEnd()
		{
			while( running() )
			{
				updateObjects();
				Sleep( 0 );
			}

			updateObjects();
		}
		//--------------------------------------------------------------------

	private:

		void					updateStdStream( HANDLE hStream, Containers< AllocatorSpace::Service >::InternalString& strOutput )
		{
			DWORD dBytes = 0;
			PeekNamedPipe( hStream, NULL, 0, NULL, &dBytes, 0 );

			if( dBytes != 0 )
			{
				const DWORD dBufferSize = 1025;
				const DWORD dBufferReadSize = dBufferSize - 1;
				char buffer[ dBufferSize ];

				while( dBytes > 0 )
				{
					DWORD dReadBytes = 0;
					ReadFile( hStream, buffer, min( dBytes, dBufferReadSize ), &dReadBytes, NULL );
					buffer[ dReadBytes ] = 0;
					strOutput += buffer;
					dBytes -= dReadBytes;
				}
			}
		}
		//--------------------------------------------------------------------

		void prepareEnvironmentVariables( const Containers< AllocatorSpace::Service >::StringVector& vecAdditionalVariables )
		{
			char* pOldEnvironmentStrings = GetEnvironmentStrings();

			Containers< AllocatorSpace::Service >::StringVector vecNewVariables;

			int iTotalSize = 0;

			const char* pCurrEnvString = pOldEnvironmentStrings;
			while( *pCurrEnvString != 0 )
			{
				int iStrSize = lstrlen( pCurrEnvString ) + 1;
				vecNewVariables.push_back( Containers< AllocatorSpace::Service >::InternalString( pCurrEnvString ) );
				pCurrEnvString += iStrSize;
				iTotalSize += iStrSize;
			}

			for( const Containers< AllocatorSpace::Service >::InternalString& strEnvVar : vecAdditionalVariables )
			{
				vecNewVariables.push_back( strEnvVar );
				iTotalSize += (int)( strEnvVar.length() + 1 );
			}
			iTotalSize += 1;

			FreeEnvironmentStrings( pOldEnvironmentStrings );

			vecEnvironmentVariables.resize( iTotalSize );

			std::sort( vecNewVariables.begin(), vecNewVariables.end() );
			char* pOutput = vecEnvironmentVariables.data();
			for( const Containers< AllocatorSpace::Service >::InternalString& strEnvVar : vecNewVariables )
			{
				strcpy_s( pOutput, (ptrdiff_t)*vecEnvironmentVariables.end() - (ptrdiff_t)pOutput, strEnvVar.data() );
				pOutput += (int)( strEnvVar.length() + 1 );
			}
			*pOutput = 0;
		}
		//--------------------------------------------------------------------

		Containers< AllocatorSpace::Service >::InternalString			strProgramLocation;
		Containers< AllocatorSpace::Service >::InternalString			strProgramParameters;
		Containers< AllocatorSpace::Service >::CharVector				vecEnvironmentVariables;

		Containers< AllocatorSpace::Service >::InternalString			strStdOut;
		Containers< AllocatorSpace::Service >::InternalString			strStdError;

		STARTUPINFO				startupInfo;
		PROCESS_INFORMATION		processInfo;

		HANDLE					hStdOutputRead;
		HANDLE					hStdOutputWrite;
		HANDLE					hStdErrorRead;
		HANDLE					hStdErrorWrite;

		DWORD					dReturnCode;
		BOOL					bLaunched;
	};
	//------------------------------------------------------------------------

	bool compile( const Compiler& compiler, const Containers< AllocatorSpace::Service >::StringVector& vecInputFiles )
	{
		if( !vecInputFiles.empty() )
		{
			Containers< AllocatorSpace::Service >::InternalString strTempRoot = FileUtils< AllocatorSpace::Service >::getTempDirectory();

			Containers< AllocatorSpace::Service >::InternalString strCompilerWorkingFolder = Containers< AllocatorSpace::Service >::InternalString( compiler.strCompilerLocation.data(), compiler.strCompilerLocation.length() );
			strCompilerWorkingFolder += "/dmd2/windows/bin";
			Containers< AllocatorSpace::Service >::InternalString strCompilerExecutable = "\"";
			strCompilerExecutable += strCompilerWorkingFolder;
			strCompilerExecutable += "/dmd.exe\"";

			Containers< AllocatorSpace::Service >::InternalString strArguments = "-m64 -debug -g -op -L/DLL ";

			for( const Containers< AllocatorSpace::Service >::InternalString& strInputFile : vecInputFiles )
			{
				strArguments += "\"";
				strArguments += strInputFile;
				strArguments += "\"";
			}

			Containers< AllocatorSpace::Service >::StringVector vecEnvironmentVariables;

			vecEnvironmentVariables.push_back( Containers< AllocatorSpace::Service >::InternalString( "VCINSTALLDIR=\"C:\\Program Files (x86)\\Microsoft Visual Studio 14.0\\" ) );
			vecEnvironmentVariables.push_back( Containers< AllocatorSpace::Service >::InternalString( "LINKCMD64=\"C:\\Program Files (x86)\\Microsoft Visual Studio 14.0\\VC\\bin\\amd64link.exe\"" ) );
			vecEnvironmentVariables.push_back( Containers< AllocatorSpace::Service >::InternalString( "WindowsSdkDir=\"C:\\Program Files (x86)\\Windows Kits\\8.1\\\"" ) );

			Process compileProcess( strCompilerExecutable, strCompilerWorkingFolder, strArguments, vecEnvironmentVariables, true );


		}

		return false;
	}
	//------------------------------------------------------------------------
}
//----------------------------------------------------------------------------

namespace binderoo
{
	class ServiceImplementation
	{
	public:
		ServiceImplementation( ServiceConfiguration& configuration );
		~ServiceImplementation();

		int32_t threadFunction( ThreadOSUpdateFunction threadOSUpdate );

	private:
		FileWatcher				watcher;

		ServiceConfiguration*	pConfiguration;
		void*					pThread;
		std::atomic< bool >		bHaltExecution;
		std::atomic< bool >		bRunning;
	};
}
//----------------------------------------------------------------------------

binderoo::ServiceImplementation::ServiceImplementation( ServiceConfiguration& configuration )
	: watcher( configuration.folders )
	, pConfiguration( &configuration )
	, pThread( nullptr )
	, bHaltExecution( false )
	, bRunning( false )
{
	pThread = pConfiguration->create_thread( fastdelegate::MakeDelegate( this, &binderoo::ServiceImplementation::threadFunction ) );
}
//----------------------------------------------------------------------------

binderoo::ServiceImplementation::~ServiceImplementation()
{
	bHaltExecution = true;

	while( bRunning )
	{
		pConfiguration->sleep_thread( 0 );
	}

	pConfiguration->sleep_thread( 0 );

	pConfiguration->destroy_thread( pThread );
}
//----------------------------------------------------------------------------

int32_t binderoo::ServiceImplementation::threadFunction( binderoo::ThreadOSUpdateFunction threadOSUpdate )
{
	bRunning = true;

	std::set< MonitoredFolder* > changedFolders;

	for( auto& folder : pConfiguration->folders )
	{
		// std::set doesn't have a reserve function. This is essentially a hack, but should reserve all our memory.
		changedFolders.insert( &folder );
	}

	while( !bHaltExecution )
	{
		threadOSUpdate();

		if( watcher.detectFileChanges() )
		{
			changedFolders.clear();
			const ChangedFilesVector& changedFiles = watcher.getChangedFiles();

			for( auto& changedFile : changedFiles )
			{
				changedFolders.insert( changedFile.pThisFolder );
			}

			Containers< AllocatorSpace::Service >::StringVector vecAllFiles;

/*			for( auto& changedFolder : changedFolders )
			{
				watcher.getAllFiles( *changedFolder, vecAllFiles );
			}*/

			for( auto& folder : pConfiguration->folders )
			{
				watcher.getAllFiles( folder, vecAllFiles );
			}

			binderoo::compile( pConfiguration->compilers[ 0 ], vecAllFiles );

		}

		pConfiguration->sleep_thread( 0 );
	}

	return 0;
}
//----------------------------------------------------------------------------

binderoo::Service::Service( ServiceConfiguration& configuration )
	: config( configuration )
	, pImplementation( nullptr )
{
	pImplementation = (ServiceImplementation*)config.alloc( sizeof( ServiceImplementation ), sizeof( size_t ) );
	new( pImplementation ) ServiceImplementation( config );
}
//----------------------------------------------------------------------------

binderoo::Service::~Service()
{
	pImplementation->~ServiceImplementation();

	config.free( pImplementation );
}
//----------------------------------------------------------------------------

//============================================================================
