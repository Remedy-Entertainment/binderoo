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
		DMD,
		LDC,
	};

	struct Compiler
	{
		DString								strCompilerLocation;
		DString								strLinkerLocation;
		CompilerType						eType;
	};

	typedef fastdelegate::FastDelegate0< void > ThreadOSUpdateFunction;
	typedef fastdelegate::FastDelegate1< ThreadOSUpdateFunction, int32_t >	ThreadRunFunction;

	typedef void*(* ThreadCreateFunction )( ThreadRunFunction );
	typedef void(* ThreadSleepFunction )( size_t );
	typedef void(* ThreadDestroyFunction )( void* );

	struct ServiceConfiguration
	{
		Slice< Compiler >					compilers;
		Slice< MonitoredFolder >			folders;

		CompilerType						eCurrentCompiler;

		AllocatorFunc						alloc;
		DeallocatorFunc						free;
		CAllocatorFunc						calloc;
		ReallocatorFunc						realloc;

		UnalignedAllocatorFunc				unaligned_alloc;
		UnalignedDeallocatorFunc			unaligned_free;

		ThreadCreateFunction				create_thread;
		ThreadSleepFunction					sleep_thread;
		ThreadDestroyFunction				destroy_thread;
	};

	class ServiceImplementation;

	class Service
	{
	public:
		Service( ServiceConfiguration& configuration );
		~Service();

	private:
		ServiceConfiguration		config;
		ServiceImplementation*		pImplementation;
	};
	//------------------------------------------------------------------------
}
//----------------------------------------------------------------------------

#endif // !defined( _BINDEROO_SERVICE_H_ )

//============================================================================
