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

#if !defined( _BINDEROO_FILEUTILS_H_ )
#define _BINDEROO_FILEUTILS_H_

#include "binderoo/defs.h"
#include "binderoo/allocator.h"
#include "binderoo/containers.h"

#include <Windows.h>

namespace binderoo
{
	template< AllocatorSpace eSpace >
	struct FileUtils
	{
		typedef typename binderoo::Containers< eSpace >::InternalString ThisInternalString;

		static ThisInternalString getTempDirectory()
		{
			binderoo::Containers< eSpace >::InternalString strTempPath;
			DWORD dTempPathLength = GetTempPath( 0, nullptr );
			strTempPath.resize( dTempPathLength - 1 );
			GetTempPath( dTempPathLength, (char*)strTempPath.data() );
			std::replace( strTempPath.begin(), strTempPath.end(), '\\', '/' );
			strTempPath += "binderoo/";

			return strTempPath;
		}
		//--------------------------------------------------------------------

		static bool exists( const ThisInternalString& strFileOrDirectory )
		{
			DWORD dPathAttributes = GetFileAttributes( strFileOrDirectory.c_str() );

			return dPathAttributes != INVALID_FILE_ATTRIBUTES;
		}
		//--------------------------------------------------------------------

		static bool isDirectory( const ThisInternalString& strFileOrDirectory )
		{
			DWORD dPathAttributes = GetFileAttributes( strFileOrDirectory.c_str() );

			return dPathAttributes != INVALID_FILE_ATTRIBUTES && ( dPathAttributes & FILE_ATTRIBUTE_DIRECTORY ) != 0;
		}
		//--------------------------------------------------------------------

		// TODO: Make it recursive
		static void createDirectory( const ThisInternalString& strDirectory )
		{
			CreateDirectory( strDirectory.c_str(), NULL );
		}
		//--------------------------------------------------------------------
	};
	//------------------------------------------------------------------------
}
//----------------------------------------------------------------------------

#endif // !defined( _BINDEROO_FILEUTILS_H_ )

//============================================================================
