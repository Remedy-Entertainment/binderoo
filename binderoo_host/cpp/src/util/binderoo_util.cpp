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

#include "binderoo/defs.h"
#include "binderoo/hash.h"
#include "binderoo/host.h"

#include "binderoo/imports.h"
#include "binderoo/exports.h"

#include "paramhandler.h"

#include <cstdio>
#include <cstdlib>
#include <cstring>
//----------------------------------------------------------------------------

static void* BIND_C_CALL test_unaligned_malloc( size_t objSize )
{
	return malloc( objSize );
}
//----------------------------------------------------------------------------

static void BIND_C_CALL test_unaligned_free( void* pObj )
{
	free( pObj );
}
//----------------------------------------------------------------------------


static void* BIND_C_CALL test_malloc( size_t objSize, size_t alignment )
{
	return _aligned_malloc( objSize, alignment );
}
//----------------------------------------------------------------------------

static void BIND_C_CALL test_free( void* pObj )
{
	_aligned_free( pObj );
}
//----------------------------------------------------------------------------

static void* BIND_C_CALL test_calloc( size_t objCount, size_t objSize, size_t alignment )
{
	return _aligned_malloc( objCount * objSize, alignment );
}
//----------------------------------------------------------------------------

static void* BIND_C_CALL test_realloc( void* pObj, size_t newObjSize, size_t alignment )
{
	return _aligned_realloc( pObj, newObjSize, alignment );
}
//----------------------------------------------------------------------------

enum Options : int
{
	None,
	SearchFolder					= 0x01,
	ListCStyleBindingsForAll		= 0x02,
	ListCStyleBindingsForSpecific	= 0x04,
	FunctionCall					= 0x08,
	FunctionCallParameter			= 0x10,
};
//----------------------------------------------------------------------------

void printUsageScreen()
{
	printf( "Binderoo Util (C) 2016 Remedy Entertainment Ltd.\n" );
	printf( "\n" );
	printf( "Usage: binderoo_util [-g class] [-gA] [-f folder]\n" );
	printf( "\n" );
	printf( "  -f folder      Add folders to search for DLL (use multiple -f definitions)\n" );
	printf( "  -g class       Generate C++ style bindings for provided class\n" );
	printf( "  -gA            Generate C++ style bindings for all classes in all DLLs\n" );
	printf( "  -gAV versions  As -gA, except with specified versions\n" );
	printf( "  -c             Call a function\n" );
	printf( "  -p             Parameter for function call (use multiple -p definitions)\n" );
	printf( "\n" );
}
//----------------------------------------------------------------------------

int main( int argc, char** argv )
{
	if( argc < 2 )
	{
		printUsageScreen();
	}
	else
	{
		const int			MaxArgCount = 256;
		binderoo::DString	searchFolders[ MaxArgCount ];
		binderoo::DString	listClasses[ MaxArgCount ];
		binderoo::DString	functionCall;
		binderoo::DString	functionCallParameters[ MaxArgCount ];

		int					iErrorParameters[ MaxArgCount ];
		int					iErrorCount = 0;

		int					iSearchFolderCount = 0;
		int					iListClassCount = 0;
		int					iFunctionCallParameterCount = 0;
		
		int					eCurrParamMode = Options::None;
		int					eFoundParams = Options::None;

		const char*			pCBindingsForAllVersions = nullptr;

		for( int iCurrArg = 1; iCurrArg < argc && iSearchFolderCount < MaxArgCount; ++iCurrArg )
		{
			switch( eCurrParamMode )
			{
			case Options::None:
				{
					// TODO: Make this less rubbish and less prone to error
					if( argv[ iCurrArg ][ 0 ] == '-' )
					{
						switch( argv[ iCurrArg ][ 1 ] )
						{
						case 'g':
							{
								if( argv[ iCurrArg ][ 2 ] == 'A' )
								{
									eFoundParams |= Options::ListCStyleBindingsForAll;
									if( argv[ iCurrArg ][ 3 ] == 'V' )
									{
										eCurrParamMode = Options::ListCStyleBindingsForAll;
									}
								}
								else
								{
									eFoundParams |= Options::ListCStyleBindingsForSpecific;
									eCurrParamMode = Options::ListCStyleBindingsForSpecific;
								}
							}
							break;

						case 'f':
							eFoundParams |= Options::SearchFolder;
							eCurrParamMode = Options::SearchFolder;
							break;

						case 'c':
							eFoundParams |= Options::FunctionCall;
							eCurrParamMode = Options::FunctionCall;
							break;

						case 'p':
							eFoundParams |= Options::FunctionCallParameter;
							eCurrParamMode = Options::FunctionCallParameter;
							break;

						default:
							iErrorParameters[ iErrorCount++ ] = iCurrArg;
							break;
						}
					}
					else
					{
						iErrorParameters[ iErrorCount++ ] = iCurrArg;
					}
				}
				break;

			case Options::SearchFolder:
				searchFolders[ iSearchFolderCount++ ] = binderoo::DString( argv[ iCurrArg ], strlen( argv[ iCurrArg ] ) );
				eCurrParamMode = Options::None;
				break;

			case Options::ListCStyleBindingsForAll:
				pCBindingsForAllVersions = argv[ iCurrArg ];
				eCurrParamMode = Options::None;
				break;

			case Options::ListCStyleBindingsForSpecific:
				listClasses[ iListClassCount++ ] = binderoo::DString( argv[ iCurrArg ], strlen( argv[ iCurrArg ] ) );
				eCurrParamMode = Options::None;
				break;

			case Options::FunctionCall:
				functionCall = binderoo::DString( argv[ iCurrArg ], strlen( argv[ iCurrArg ] ) );
				eCurrParamMode = Options::None;
				break;

			case Options::FunctionCallParameter:
				functionCallParameters[ iFunctionCallParameterCount++ ] = binderoo::DString( argv[ iCurrArg ], strlen( argv[ iCurrArg ] ) );
				eCurrParamMode = Options::None;
				break;

			default:
				iErrorParameters[ iErrorCount++ ] = iCurrArg;
				break;
			}
		}

		if( iErrorCount )
		{
			printf( "The following bad parameters found:\n" );
			for( int iError = 0; iError < iErrorCount; ++iError )
			{
				printf( "  %s\n", argv[ iErrorParameters[ iError ] ] );
			}
			printf( "\n" );

			printUsageScreen();
		}
		else if( eFoundParams == Options::None )
		{
			printf( "No commands found!\n\n" );

			printUsageScreen();
		}
		else if( iSearchFolderCount == 0 )
		{
			printf( "No search folders provided!\n\n" );

			printUsageScreen();
		}
		else
		{
			binderoo::HostConfiguration configuration;

			configuration.strDynamicLibSearchFolders = binderoo::Slice< binderoo::DString >( &searchFolders[ 0 ], (size_t)iSearchFolderCount );
			configuration.alloc = &test_malloc;
			configuration.free = &test_free;
			configuration.calloc = &test_calloc;
			configuration.realloc = &test_realloc;
			configuration.unaligned_alloc = &test_unaligned_malloc;
			configuration.unaligned_free = &test_unaligned_free;
			configuration.log_info = nullptr;
			configuration.log_warning = nullptr;
			configuration.log_error = nullptr;

			binderoo::Host host( configuration );

			if( eFoundParams & Options::ListCStyleBindingsForAll )
			{
				const char* pDeclarations = host.generateCPPStyleBindingDeclarationsForAllObjects( pCBindingsForAllVersions );
				test_unaligned_free( (void*)pDeclarations );
			}

			if( eFoundParams & Options::FunctionCall )
			{
				ParamHandler handler( binderoo::Slice< binderoo::DString >( &functionCallParameters[ 0 ], (size_t)iFunctionCallParameterCount ) );
				handleFunction( functionCall.data(), handler );
			}
		}
	}

}
//----------------------------------------------------------------------------

//============================================================================
