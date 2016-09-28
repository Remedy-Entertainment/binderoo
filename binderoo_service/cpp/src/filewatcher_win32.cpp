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

#include "filewatcher.h"

#include <Windows.h>
//----------------------------------------------------------------------------

binderoo::FileWatcher::FileWatcher( binderoo::Slice< binderoo::MonitoredFolder >& folders )
{
	monitoredFolders = folders;
	vecFileWatchersHandles.reserve( folders.length() );
	vecFileWatchersDirectories.reserve( folders.length() );

	for( auto& folder : monitoredFolders )
	{
		InternalString searchPath = "\\\\?\\";
		searchPath += InternalString( folder.strSourceFolder.data(), folder.strSourceFolder.length() );

		HANDLE findHandle = FindFirstChangeNotification( searchPath.c_str(), TRUE, FILE_NOTIFY_CHANGE_LAST_WRITE );
		vecFileWatchersHandles.push_back( findHandle );


	}
}
//----------------------------------------------------------------------------

bool binderoo::FileWatcher::detectFileChanges()
{
	vecCurrentChangedFiles.clear();

	const DWORD dOriginalWait = 10;
	const DWORD dAdditionalWait = 100;

	DWORD dWaitStatus = WaitForMultipleObjects( vecFileWatchersHandles.size(), vecFileWatchersHandles.data(), FALSE, dOriginalWait );

	while( dWaitStatus > WAIT_OBJECT_0 && dWaitStatus < WAIT_OBJECT_0 + vecFileWatchersHandles.size() )
	{
		DWORD dCurrentFolder = dWaitStatus - WAIT_OBJECT_0;
		MonitoredFolder& currFolder = monitoredFolders[ dCurrentFolder ];

		vecCurrentChangedFiles.push_back( ChangedFiles() );
		ChangedFiles& changedFile = vecCurrentChangedFiles.back();

		changedFile.pThisFolder = &currFolder;



		FindNextChangeNotification( vecFileWatchersHandles[ dCurrentFolder ] );
		dWaitStatus = WaitForMultipleObjects( vecFileWatchersHandles.size(), vecFileWatchersHandles.data(), FALSE, dAdditionalWait );
	}

	return !vecCurrentChangedFiles.empty();
}
//============================================================================
