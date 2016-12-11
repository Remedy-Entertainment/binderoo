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
//----------------------------------------------------------------------------

import binderoo.binding.attributes;
import binderoo.variabledescriptor;
import binderoo.traits;

import core.memory;
import std.json;
//----------------------------------------------------------------------------

//version = SerialisePointers;
//----------------------------------------------------------------------------

pragma( inline ) JSONValue serialise( Type )( ref Type val ) if( is( Type == delegate ) )
{
	return JSONValue.init;
}
//----------------------------------------------------------------------------

pragma( inline ) void deserialise( Type )( ref Type target, JSONValue source ) if( is( Type == delegate ) )
{
}
//----------------------------------------------------------------------------

pragma( inline ) JSONValue serialise( Type )( ref Type val ) if( is( Type == function ) )
{
	return JSONValue.init;
}
//----------------------------------------------------------------------------

pragma( inline ) void deserialise( Type )( ref Type target, JSONValue source ) if( is( Type == function ) )
{
}
//----------------------------------------------------------------------------

pragma( inline ) JSONValue serialise( Type )( ref Type val ) if( isScalarType!( Type ) || is( Type == string ) )
{
	return JSONValue( val );
}
//----------------------------------------------------------------------------

pragma( inline ) void deserialise( Type )( ref Type target, JSONValue source ) if( isScalarType!( Type ) || is( Type == string ) )
{
	static if( isIntegral!( Type ) )
	{
		if( source.type == JSON_TYPE.INTEGER )
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
		if( source.type == JSON_TYPE.INTEGER )
		{
			target = cast( Type ) source.integer;
		}
		else if( source.type == JSON_TYPE.UINTEGER )
		{
			target = cast( Type ) source.uinteger;
		}
		else
		{
			target = cast( Type ) source.floating;
		}
	}
	else static if( is( Type == string ) )
	{
		target = source.str;
	}
}
//----------------------------------------------------------------------------

pragma( inline ) JSONValue serialise( ElementType, size_t Length )( ref __vector( ElementType[ Length ] ) val )
{
	return serialise( *cast( ElementType[ Length ]* )&val );
}
//----------------------------------------------------------------------------

pragma( inline ) void deserialise( ElementType, size_t Length )( ref __vector( ElementType[ Length ] ) target, JSONValue source )
{
	deserialise( *cast( ElementType[ Length ]* )&target, source );
}
//----------------------------------------------------------------------------

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
//----------------------------------------------------------------------------

pragma( inline ) void deserialise( Type )( ref Type target, JSONValue source ) if( IsSomeArray!( Type ) && !is( Type == string ) )
{
	// Deeper inspection of array type so that we can serialise pointers/reference types/etc.

	static if( !IsStaticArray!( Type ) )
	{
		target = null;
		target.length = source.array.length;
	}

	foreach( iIndex, ref currVal; source.array )
	{
		static if( IsStaticArray!( Type ) )
		{
			if( iIndex >= target.length )
			{
				break;
			}
		}
		deserialise( target[ iIndex ], currVal );
	}
}
//----------------------------------------------------------------------------

pragma( inline ) JSONValue serialise( Type )( ref Type pointer ) if( isPointer!( Type ) )
{
	version( SerialisePointers )
	{
		JSONValue serialiseRawPointer( ref Type pointer )
		{
			size_t* ptr = *( cast( size_t** )&pointer );
			JSONValue rawPtr = [ "raw" : *ptr, "instance" : size_t.max ];
			return rawPtr;
		}

		static if( !is( Type == void* ) )
		{
			JSONValue serialiseObject( ref Type pointer )
			{
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
		}

		// TODO: Deeper pointer inspection
		static if( is( Type == void* ) )
		{
			return serialiseRawPointer( pointer );
		}
		else
		{
	//		if( GC.addrOf( pointer ) !is null )
			{
				// Owned by GC
				return serialiseObject( pointer );
			}
	/*		else
			{
				// Not owned by D, serialise the pointer value
			}*/
		}
	}
	else
	{
		return JSONValue.init;
	}
}
//----------------------------------------------------------------------------

pragma( inline ) void deserialise( Type )( ref Type target, JSONValue source ) if( isPointer!( Type ) )
{
	version( SerialisePointers )
	{
		static if( is( Type == void* ) )
		{
			size_t* ptr = *( cast( size_t** )&target );
			*ptr = cast( size_t ) source.integer;
		}
		else
		{
			// TODO: Deeper pointer inspection
			auto rawPtr = source.object[ "index" ].uinteger;
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
	}
}
//----------------------------------------------------------------------------

JSONValue serialise( Type )( ref Type object ) if( is( Type == struct ) || is( Type == union ) || is( Type == class ) || is( Type == interface ) )
{
	// THIS IS HIGHLY ANNOYING, I HAVE TO ASSIGN AN ASSOCIATIVE ARRAY
	// TO BEGIN WITH JUST TO SET IT AS AN OBJECT. WHO WROTE THIS JEEZ.
	//JSONValue objectRoot = [ "ObjectType" : CTypeString!( Type ) ];
	JSONValue objectRoot;
	objectRoot.type = JSON_TYPE.OBJECT;

	foreach( iIndex, member; Type.init.tupleof )
	{
		static if( IsMutable!( typeof( Type.tupleof[ iIndex ] ) ) && !HasUDA!( Type.tupleof[ iIndex ], BindNoSerialise ) )
		{
			objectRoot.object[ __traits( identifier, Type.tupleof[ iIndex ] ) ] = serialise( object.tupleof[ iIndex ] );
		}
	}

	return objectRoot;
}
//----------------------------------------------------------------------------

void deserialise( Type )( ref Type target, JSONValue source ) if( is( Type == struct ) || is( Type == union ) || is( Type == class ) || is( Type == interface ) )
{
	foreach( iIndex, member; Type.init.tupleof )
	{
		static if( IsMutable!( typeof( Type.tupleof[ iIndex ] ) ) && !HasUDA!( Type.tupleof[ iIndex ], BindNoSerialise ) )
		{
			JSONValue* val = ( __traits( identifier, Type.tupleof[ iIndex ] ) in source.object );
			if( val !is null )
			{
				deserialise( target.tupleof[ iIndex ], *val );
			}
		}
	}
}
//----------------------------------------------------------------------------

//============================================================================
