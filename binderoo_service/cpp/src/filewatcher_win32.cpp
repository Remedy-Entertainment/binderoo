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
#include <algorithm>
//----------------------------------------------------------------------------

#define FILE_NOTIFY_SERVICE_WATCH ( FILE_NOTIFY_CHANGE_LAST_WRITE | FILE_NOTIFY_CHANGE_CREATION | FILE_NOTIFY_CHANGE_FILE_NAME )
#define FILE_NOTIFY_SERVICE_DIROPEN ( FILE_FLAG_BACKUP_SEMANTICS | FILE_FLAG_OVERLAPPED )

namespace
{
	bool matchesExtensions( const binderoo::Containers< binderoo::AllocatorSpace::Service >::InternalString& strFilename, binderoo::DString extensions )
	{
		bool bAnyMatch = extensions.length() == 0;

		size_t uExtensionStart = 0;
		size_t uExtensionEnd = 0;

		for( size_t uExtensionsPos = 0; !bAnyMatch && uExtensionsPos <= extensions.length(); ++uExtensionsPos )
		{
			if( uExtensionsPos == extensions.length()
				|| extensions.data()[ uExtensionsPos ] == ';' )
			{
				uExtensionEnd = uExtensionsPos;

				if( uExtensionStart != uExtensionEnd )
				{
					binderoo::DString strThisExtension( extensions.data() + uExtensionStart, uExtensionEnd - uExtensionStart );

					const char* pExtensionPos = strThisExtension.data();
					const char* pFilenameEnd = strFilename.c_str() + strFilename.length();
					const char* pFilenamePos = pFilenameEnd - strThisExtension.length();

					bool bMatch = true;
					while( bMatch && pFilenamePos != pFilenameEnd )
					{
						bMatch &= ( tolower( *pExtensionPos ) == tolower( *pFilenamePos ) );
						++pExtensionPos;
						++pFilenamePos;
					}

					bAnyMatch |= bMatch;
				}

				uExtensionStart = uExtensionsPos + 1;
				uExtensionEnd = uExtensionStart;
				uExtensionsPos = uExtensionStart;
			}
		}

		return bAnyMatch;
	}
	//------------------------------------------------------------------------

	bool matchesExtensions( const binderoo::Containers< binderoo::AllocatorSpace::Service >::InternalString& strFilename, const binderoo::Containers< binderoo::AllocatorSpace::Service >::InternalString& strExtensions )
	{
		return matchesExtensions( strFilename, binderoo::DString( strExtensions.data(), strExtensions.length() ) );
	}
	//------------------------------------------------------------------------

	void getAllFiles(	const binderoo::Containers< binderoo::AllocatorSpace::Service >::InternalString& strDirectory,
						const binderoo::Containers< binderoo::AllocatorSpace::Service >::InternalString& strExtensions,
						binderoo::Containers< binderoo::AllocatorSpace::Service >::StringVector& vecOutput )
	{
		WIN32_FIND_DATA findData;
		ZeroMemory( &findData, sizeof( WIN32_FIND_DATA ) );

		binderoo::Containers< binderoo::AllocatorSpace::Service >::InternalString strDirectorySearch = "\\\\?\\";
		strDirectorySearch += strDirectory;
		strDirectorySearch += "*";

		HANDLE hFindHandle = FindFirstFile( strDirectorySearch.c_str(), &findData );
		BOOL bSuccess = hFindHandle != INVALID_HANDLE_VALUE;

		while( bSuccess != FALSE )
		{
			bool bIsSkippable = ( findData.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY ) && findData.cFileName[ 0 ] == '.';

			if( !bIsSkippable )
			{
				binderoo::Containers< binderoo::AllocatorSpace::Service >::InternalString strFoundFile = strDirectory;
				strFoundFile += findData.cFileName;

				if( ( findData.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY ) != 0 )
				{
					strFoundFile += "\\";
					getAllFiles( strFoundFile, strExtensions, vecOutput );
				}
				else if( ( findData.dwFileAttributes & ( FILE_ATTRIBUTE_VIRTUAL | FILE_ATTRIBUTE_DEVICE | FILE_ATTRIBUTE_TEMPORARY ) ) == 0
					&& matchesExtensions( strFoundFile, strExtensions ) )
				{
					vecOutput.push_back( strFoundFile );
				}
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

struct FileWatcherDataWin32
{
	enum : DWORD { dBufferLength = 65536 };

	FileWatcherDataWin32()
		: pFolder( nullptr )
		, pWriteBuffer( buffer1 )
		, pReadBuffer( buffer2 )
		, hFolder( nullptr )
	{
		buffer1[ 0 ] = 0;
		buffer2[ 0 ] = 0;
	}

	char							buffer1[ dBufferLength ];
	char							buffer2[ dBufferLength ];

	binderoo::MonitoredFolder*		pFolder;
	char*							pWriteBuffer;
	char*							pReadBuffer;
	DWORD							dReadBufferLength;
	DWORD							dWriteBufferLength;

	OVERLAPPED						overlappedData;
	HANDLE							hFolder;

	binderoo::ChangedFilesVector	vecChangedFiles;
	//------------------------------------------------------------------------

	void kickoffWatcher()
	{
		ZeroMemory( &overlappedData, sizeof( OVERLAPPED ) );
		overlappedData.hEvent = this;
		BOOL bKickedOff = ReadDirectoryChangesW( hFolder, pWriteBuffer, FileWatcherDataWin32::dBufferLength, TRUE, FILE_NOTIFY_SERVICE_WATCH, NULL, &overlappedData, &FileWatcherDataWin32::completed );
		char messageBuffer[ 2048 ] = { 0 };

		if( !bKickedOff )
		{
			DWORD dError = GetLastError();
			FormatMessage( FORMAT_MESSAGE_FROM_SYSTEM | FORMAT_MESSAGE_IGNORE_INSERTS, nullptr, dError, 0, messageBuffer, 2048, nullptr );
			int foo = 1;
		}

	}
	//------------------------------------------------------------------------

private:
	void parseWatchedData()
	{
		if( dReadBufferLength > 0 )
		{
			char* pCurrBuffer = pReadBuffer;
			while( pCurrBuffer != nullptr )
			{
				FILE_NOTIFY_INFORMATION* pInformation = (FILE_NOTIFY_INFORMATION*)pCurrBuffer;
				int strLength = WideCharToMultiByte( CP_ACP, 0, pInformation->FileName, pInformation->FileNameLength / sizeof( WCHAR ), NULL, 0, NULL, NULL );

				binderoo::Containers< binderoo::AllocatorSpace::Service >::InternalString strChangedFile;
				strChangedFile.resize( strLength );
				WideCharToMultiByte( CP_ACP, 0, pInformation->FileName, pInformation->FileNameLength / sizeof( WCHAR ), (LPSTR)strChangedFile.data(), strLength, NULL, NULL );

				if( matchesExtensions( strChangedFile, pFolder->strSourceExtensions ) )
				{
					vecChangedFiles.push_back( binderoo::ChangedFiles() );
					binderoo::ChangedFiles& changedFile = vecChangedFiles.back();
					changedFile.pThisFolder = pFolder;
					changedFile.strChangedFile = strChangedFile;
				}

				if( pInformation->NextEntryOffset > 0 )
				{
					pCurrBuffer += pInformation->NextEntryOffset;
				}
				else
				{
					pCurrBuffer = 0;
				}
			}

			dReadBufferLength = 0;
		}
	}
	//------------------------------------------------------------------------

public:
	static VOID CALLBACK completed( DWORD dwErrorCode, DWORD dwBytesTransferred, LPOVERLAPPED lpOverlapped )
	{
		FileWatcherDataWin32* pData = (FileWatcherDataWin32*)lpOverlapped->hEvent;

		char* pTemp = pData->pReadBuffer;
		pData->pReadBuffer = pData->pWriteBuffer;
		pData->pWriteBuffer = pTemp;
		pData->dReadBufferLength = dwBytesTransferred;

		pData->kickoffWatcher();
		pData->parseWatchedData();
	}
	//------------------------------------------------------------------------

};
//----------------------------------------------------------------------------


binderoo::FileWatcher::FileWatcher( binderoo::Slice< binderoo::MonitoredFolder >& folders )
{
	monitoredFolders = folders;
	vecFileWatchersHandles.reserve( folders.length() );

	for( auto& folder : monitoredFolders )
	{
		Containers< AllocatorSpace::Service >::InternalString searchPath = "\\\\?\\";
		searchPath += Containers< AllocatorSpace::Service >::InternalString( folder.strSourceFolder.data(), folder.strSourceFolder.length() );
		std::replace( searchPath.begin(), searchPath.end(), '/', '\\' );

		int iWideLength = MultiByteToWideChar( CP_ACP, 0, searchPath.data(), (int)searchPath.length(), NULL, 0 );
		Containers< AllocatorSpace::Service >::InternalWString wSearchPath( iWideLength, '-' );
		MultiByteToWideChar( CP_ACP, 0, searchPath.data(), (int)searchPath.length(), (wchar_t*)wSearchPath.data(), (int)wSearchPath.length() );

		FileWatcherDataWin32* pData = AllocatorFunctions< AllocatorSpace::Service >::allocAndConstruct< FileWatcherDataWin32 >();

		pData->pFolder = &folder;
		pData->hFolder = CreateFileW( wSearchPath.c_str(), FILE_LIST_DIRECTORY, FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE, NULL, OPEN_EXISTING, FILE_NOTIFY_SERVICE_DIROPEN, NULL );
		pData->kickoffWatcher();

/*		char messageBuffer[ 2048 ] = { 0 };

		if( hFolder == INVALID_HANDLE_VALUE )
		{
			DWORD dError = GetLastError();
			FormatMessage( FORMAT_MESSAGE_FROM_SYSTEM | FORMAT_MESSAGE_IGNORE_INSERTS, nullptr, dError, 0, messageBuffer, 2048, nullptr );
		}*/
		vecFileWatchersHandles.push_back( pData );

	}

}
//----------------------------------------------------------------------------

binderoo::FileWatcher::~FileWatcher()
{
	for( void* pData : vecFileWatchersHandles )
	{
		FileWatcherDataWin32* watcherData = (FileWatcherDataWin32*)pData;
		CancelIo( watcherData->hFolder );
	}

	for( void* pData : vecFileWatchersHandles )
	{
		FileWatcherDataWin32* watcherData = (FileWatcherDataWin32*)pData;
		while( !HasOverlappedIoCompleted( &watcherData->overlappedData ) )
		{
			SleepEx( 10, TRUE );
		}
		CloseHandle( watcherData->hFolder );

		AllocatorFunctions< AllocatorSpace::Service >::destructAndFree( watcherData );
	}
}
//----------------------------------------------------------------------------

bool binderoo::FileWatcher::detectFileChanges()
{
	vecCurrentChangedFiles.clear();

	for( void* pData : vecFileWatchersHandles )
	{
		FileWatcherDataWin32& watcherData = *(FileWatcherDataWin32*)pData;

		if( watcherData.vecChangedFiles.size() > 0 )
		{
			vecCurrentChangedFiles.insert( vecCurrentChangedFiles.end(), watcherData.vecChangedFiles.begin(), watcherData.vecChangedFiles.end() );
			watcherData.vecChangedFiles.clear();
		}
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
	getAllFiles( Containers< AllocatorSpace::Service >::InternalString( folder.strSourceFolder.data(), folder.strSourceFolder.length() ),
				Containers< AllocatorSpace::Service >::InternalString( folder.strSourceExtensions.data(), folder.strSourceExtensions.length() ),
				vecOutput );
}
//----------------------------------------------------------------------------

void binderoo::FileWatcher::getAllFiles( const Containers< AllocatorSpace::Service >::InternalString& strFolder, const Containers< AllocatorSpace::Service >::InternalString& strExtensions, Containers< AllocatorSpace::Service >::StringVector& vecOutput )
{
	Containers< AllocatorSpace::Service >::InternalString strFixedUpFolder( strFolder );
	std::replace( strFixedUpFolder.begin(), strFixedUpFolder.end(), '/', '\\' );

	::getAllFiles( strFixedUpFolder, strExtensions, vecOutput );
}
//----------------------------------------------------------------------------

//============================================================================
