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

module binderoo.binding.serialise;
//-----------------------------------------------------------------------------

import binderoo.binding.attributes;
import binderoo.variabledescriptor;
import binderoo.traits;

import core.memory;
import std.json;
//-----------------------------------------------------------------------------

pragma( inline ) JSONValue serialise( Type )( ref Type val ) if( isScalarType!( Type ) || is( Type == string ) )
{
	return JSONValue( val );
}
//-----------------------------------------------------------------------------

pragma( inline ) void deserialise( Type )( ref Type target, JSONValue source ) if( isScalarType!( Type ) || is( Type == string ) )
{
	static if( isIntegral!( Type ) )
	{
		static if( isSigned!( Type ) )
		{
			target = cast( Type ) source.integer;
		}
		else
		{
			target = cast( Type ) source.uinteger;
		}
	}
	else static if( isFloatingPoint!( Type ) )
	{
		target = cast( Type ) source.floating;
	}
	else static if( is( Type == string ) )
	{
		target = source.str;
	}
}
//-----------------------------------------------------------------------------

pragma( inline ) JSONValue serialise( Type )( ref Type array ) if( IsSomeArray!( Type ) && !is( Type == string ) )
{
	// Deeper inspection of array type so that we can serialise pointers/reference types/etc.
	JSONValue[] values;
	values.reserve( array.length );
	foreach( ref currVal; array )
	{
		values ~= serialise( currVal );
	}

	return JSONValue( values );
}
//-----------------------------------------------------------------------------

pragma( inline ) void deserialise( Type )( ref Type target, JSONValue source ) if( IsSomeArray!( Type ) && !is( Type == string ) )
{
	// Deeper inspection of array type so that we can serialise pointers/reference types/etc.

	target = null;
	target.length = source.array.length;

	foreach( iIndex, ref currVal; source.array )
	{
		deserialise( target[ iIndex ], currVal );
	}
}
//-----------------------------------------------------------------------------

pragma( inline ) JSONValue serialise( Type )( ref Type pointer ) if( isPointer!( Type ) )
{
	// TODO: Deeper pointer inspection
//	if( GC.addrOf( pointer ) !is null )
	{
		// Owned by GC
		size_t* ptr = cast( size_t* )&pointer;
		JSONValue pointerData = [ "index" : *ptr ];
		if( pointer !is null )
		{
			pointerData.object[ "data" ] = serialise( *pointer );
		}
		else
		{
			pointerData.object[ "data" ] = JSONValue();
		}

		return pointerData;
	}
/*	else
	{
		// Not owned by D, serialise the pointer value
		size_t* ptr = cast( size_t* )&pointer;
		JSONValue rawPtr = [ "raw" : *ptr, "instance" : size_t.max ];
		return rawPtr;
	}*/
}
//-----------------------------------------------------------------------------

pragma( inline ) void deserialise( Type )( ref Type target, JSONValue source ) if( isPointer!( Type ) )
{
	// TODO: Deeper pointer inspection
	size_t rawPtr = source.object[ "index" ].uinteger;
	if( rawPtr != 0 )
	{
		target = new PointerTarget!( Type );
		deserialise( *target, source.object[ "data" ] );
	}
	else
	{
		target = null;
	}
}
//-----------------------------------------------------------------------------

JSONValue serialise( Type )( ref Type object ) if( is( Type == struct ) || is( Type == union ) || is( Type == class ) || is( Type == interface ) )
{
	// THIS IS HIGHLY ANNOYING, I HAVE TO ASSIGN AN ASSOCIATIVE ARRAY
	// TO BEGIN WITH JUST TO SET IT AS AN OBJECT. WHO WROTE THIS JEEZ.
	//JSONValue objectRoot = [ "ObjectType" : CTypeString!( Type ) ];
	JSONValue objectRoot;
	objectRoot.type = JSON_TYPE.OBJECT;

	alias Variables = VariableDescriptors!( Type );

	foreach( Variable; Variables )
	{
		objectRoot.object[ Variable.Name ] = serialise( Variable.get( object ) );
	}

	return objectRoot;
}
//-----------------------------------------------------------------------------

void deserialise( Type )( ref Type target, JSONValue source ) if( is( Type == struct ) || is( Type == union ) || is( Type == class ) || is( Type == interface ) )
{
	alias Variables = VariableDescriptors!( Type );

	foreach( Variable; Variables )
	{
		JSONValue* val = ( Variable.ElementName in source.object );
		if( val !is null )
		{
			deserialise( Variable.get( target ), *val );
		}
	}
}
//-----------------------------------------------------------------------------

//============================================================================
