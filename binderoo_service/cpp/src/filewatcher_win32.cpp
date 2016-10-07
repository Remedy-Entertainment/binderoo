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

namespace
{
	void getAllFiles( const binderoo::Containers< binderoo::AllocatorSpace::Service >::InternalString& strDirectory, binderoo::Containers< binderoo::AllocatorSpace::Service >::StringVector& vecOutput )
	{
		WIN32_FIND_DATA findData;
		ZeroMemory( &findData, sizeof( WIN32_FIND_DATA ) );

		HANDLE hFindHandle = FindFirstFile( strDirectory.c_str(), &findData );
		BOOL bSuccess = hFindHandle != INVALID_HANDLE_VALUE;

		while( bSuccess != FALSE )
		{
			binderoo::Containers< binderoo::AllocatorSpace::Service >::InternalString strFoundFile = strDirectory;
			strFoundFile += "/";
			strFoundFile += findData.cFileName;

			if( ( findData.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY ) != 0 )
			{
				getAllFiles( strFoundFile, vecOutput );
			}
			else if( ( findData.dwFileAttributes & ( FILE_ATTRIBUTE_VIRTUAL | FILE_ATTRIBUTE_DEVICE | FILE_ATTRIBUTE_TEMPORARY ) ) == 0 )
			{
				vecOutput.push_back( strFoundFile );
			}

			bSuccess = FindNextFile( hFindHandle, &findData );
		}

		if( hFindHandle != INVALID_HANDLE_VALUE )
		{
			FindClose( hFindHandle );
		}
	}
	//------------------------------------------------------------------------
}
//----------------------------------------------------------------------------

binderoo::FileWatcher::FileWatcher( binderoo::Slice< binderoo::MonitoredFolder >& folders )
{
	monitoredFolders = folders;
	vecFileWatchersHandles.reserve( folders.length() );
	vecFileNotificationsHandles.reserve( folders.length() );

	for( auto& folder : monitoredFolders )
	{
		Containers< AllocatorSpace::Service >::InternalString searchPath = "\\\\?\\";
		searchPath += Containers< AllocatorSpace::Service >::InternalString( folder.strSourceFolder.data(), folder.strSourceFolder.length() );

		HANDLE hFolder = CreateFile( searchPath.c_str(), FILE_LIST_DIRECTORY, FILE_SHARE_READ, NULL, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL );
		vecFileWatchersHandles.push_back( hFolder );

		HANDLE hNotifier = FindFirstChangeNotification( searchPath.c_str(), TRUE, FILE_NOTIFY_CHANGE_LAST_WRITE | FILE_NOTIFY_CHANGE_CREATION );
		vecFileNotificationsHandles.push_back( hFolder );

	}
}
//----------------------------------------------------------------------------

binderoo::FileWatcher::~FileWatcher()
{
	for( auto& hNotifier : vecFileNotificationsHandles )
	{
		FindCloseChangeNotification( hNotifier );
	}

	for( auto& hFolder : vecFileWatchersHandles )
	{
		CloseHandle( hFolder );
	}
}
//----------------------------------------------------------------------------

bool binderoo::FileWatcher::detectFileChanges()
{
	const DWORD dBufferLength = 65536;
	char buffer[ dBufferLength ];

	vecCurrentChangedFiles.clear();

	const DWORD dOriginalWait = 10;
	const DWORD dAdditionalWait = 100;

	DWORD dWaitStatus = WaitForMultipleObjects( (DWORD)vecFileNotificationsHandles.size(), vecFileNotificationsHandles.data(), FALSE, dOriginalWait );

	while( dWaitStatus > WAIT_OBJECT_0 && dWaitStatus < WAIT_OBJECT_0 + vecFileNotificationsHandles.size() )
	{
		DWORD dCurrentFolder = dWaitStatus - WAIT_OBJECT_0;
		MonitoredFolder& currFolder = monitoredFolders[ dCurrentFolder ];

		DWORD dBytesRead = 0;
		BOOL bRead = ReadDirectoryChangesW( vecFileWatchersHandles[ dCurrentFolder ], buffer, dBufferLength, TRUE, FILE_NOTIFY_CHANGE_LAST_WRITE | FILE_NOTIFY_CHANGE_CREATION, &dBytesRead, NULL, NULL );

		while( bRead != FALSE )
		{
			char* pCurrBuffer = buffer;
			while( pCurrBuffer != nullptr )
			{
				FILE_NOTIFY_INFORMATION* pInformation = (FILE_NOTIFY_INFORMATION*)pCurrBuffer;
				int strLength = WideCharToMultiByte( CP_ACP, MB_PRECOMPOSED, pInformation->FileName, pInformation->FileNameLength / sizeof( WCHAR ), NULL, 0, NULL, NULL );

				vecCurrentChangedFiles.push_back( ChangedFiles() );
				ChangedFiles& changedFile = vecCurrentChangedFiles.back();
				changedFile.pThisFolder = &currFolder;
				changedFile.strChangedFile.resize( strLength );
				WideCharToMultiByte( CP_ACP, MB_PRECOMPOSED, pInformation->FileName, pInformation->FileNameLength / sizeof( WCHAR ), (LPSTR)changedFile.strChangedFile.data(), strLength, NULL, NULL );

				if( pInformation->NextEntryOffset > 0 )
				{
					pCurrBuffer += pInformation->NextEntryOffset;
				}
				else
				{
					pCurrBuffer = 0;
				}
			}

			bRead = ReadDirectoryChangesW( vecFileWatchersHandles[ dCurrentFolder ], buffer, dBufferLength, TRUE, FILE_NOTIFY_CHANGE_LAST_WRITE | FILE_NOTIFY_CHANGE_CREATION, &dBytesRead, NULL, NULL );
		}

		FindNextChangeNotification( vecFileNotificationsHandles[ dCurrentFolder ] );
		dWaitStatus = WaitForMultipleObjects( (DWORD)vecFileNotificationsHandles.size(), vecFileNotificationsHandles.data(), FALSE, dAdditionalWait );
	}

	return !vecCurrentChangedFiles.empty();
}
//----------------------------------------------------------------------------

void binderoo::FileWatcher::getAllFiles( Containers< AllocatorSpace::Service >::StringVector& vecOutput )
{
	for( auto& folder : monitoredFolders )
	{
		getAllFiles( folder, vecOutput );
	}
}
//----------------------------------------------------------------------------

void binderoo::FileWatcher::getAllFiles( const MonitoredFolder& folder, Containers< AllocatorSpace::Service >::StringVector& vecOutput )
{
	Containers< AllocatorSpace::Service >::InternalString strFolder = "\\\\?\\";
	strFolder += Containers< AllocatorSpace::Service >::InternalString( folder.strSourceFolder.data(), folder.strSourceFolder.length() );
	::getAllFiles( strFolder, vecOutput );
}
//----------------------------------------------------------------------------

//============================================================================
