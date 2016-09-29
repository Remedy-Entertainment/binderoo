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

#include <atomic>

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
	pThread = pConfiguration->create_thread( fastdelegate::MakeDelegate( this, &threadFunction ) );
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

	while( !bHaltExecution )
	{
		threadOSUpdate();

		if( watcher.detectFileChanges() )
		{
			const ChangedFilesVector& changedFiles = watcher.getChangedFiles();

			for( auto& changedFile : changedFiles )
			{
			}
		}

		pConfiguration->sleep_thread( 0 );
	}
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
