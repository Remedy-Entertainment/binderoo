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

module binderoo.slice;
//----------------------------------------------------------------------------

public import binderoo.typedescriptor;

@CTypeName( "binderoo::Slice", "binderoo/slice.h" )
struct Slice( Type )
{
	size_t					uLength;
	Type*					pData;

	final @property			Length() const										{ return uLength; }

	final Type[]			opIndex()											{ return pData[ 0 .. uLength ]; }
	final ref Type			opIndex( size_t iElement )							{ return pData[ iElement ]; }
	final Type[]			opSlice( size_t iFrom, size_t iTo )					{ return pData[ iFrom .. iTo ]; }
	final size_t			opDollar()											{ return uLength; }

	final Type[]			opCast( T : Type[] )()								{ return pData[ 0 .. uLength ]; }
	final Type[]			toSlice()											{ return pData[ 0 .. uLength ]; }

	this( Type[] from )
	{
		uLength = from.length;
		pData = from.ptr;
	}
	//------------------------------------------------------------------------
}
//----------------------------------------------------------------------------

alias DString = Slice!( immutable( char ) );
//----------------------------------------------------------------------------

//============================================================================
