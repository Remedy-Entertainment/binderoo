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

module binderoo.binding.boundobject;
//----------------------------------------------------------------------------

public import binderoo.slice;
public import binderoo.typedescriptor;

import binderoo.binding.serialise;
//----------------------------------------------------------------------------

//version = BoundSerialise;
//----------------------------------------------------------------------------

alias BoundObjectAllocator		= extern( C ) void* function( size_t uCount );
alias BoundObjectDeallocator	= extern( C ) void function( void* pObject );
alias BoundObjectThunk			= extern( C ) void* function( void* );
alias BoundObjectSerialise		= extern( C ) const( char )* function( void* );
alias BoundObjectDeserialise	= extern( C ) void function( void*, const( char )* );

@CTypeName( "binderoo::BoundObject", "binderoo/boundobject.h" )
struct BoundObject
{
	@CTypeName( "binderoo::BoundObject::Type", "binderoo/boundobject.h" )
	enum Type : int
	{
		Undefined,
		Value,
		Reference,
	}

	DString						strFullyQualifiedName;
	ulong						uFullyQualifiedNameHash;

	BoundObjectAllocator		alloc;
	BoundObjectDeallocator		free;
	BoundObjectThunk			thunk;
	BoundObjectSerialise		serialise;
	BoundObjectDeserialise		deserialise;

	Type						eType = Type.Undefined;
}
//----------------------------------------------------------------------------

struct BoundObjectFunctions( Type )
{
	static if( is( Type == struct ) )
	{
		enum TypeVal = BoundObject.Type.Value;
		enum TypeSize = Type.sizeof;
		alias CastType = Type*;
	}
	else
	{
		enum TypeVal = BoundObject.Type.Reference;
		enum TypeSize = __traits( classInstanceSize, Type );
		alias CastType = Type;
	}


	static extern( C ) void* thunkObj( void* pObj )
	{
		static if( is( Type == class ) )
		{
			return cast( void* )cast( CastType )cast( Object )pObj;
		}
		else
		{
			// TODO: Work out how to thunk value types
			return pObj;
		}
	}

	static extern( C ) void* allocObj( size_t uCount = 1 )
	in
	{
		assert( uCount == 1, "Only one object supported for allocation right now!" );
	}
	body
	{
		import std.conv : emplace;
		import core.stdc.stdlib : malloc;
		import core.memory : GC;

		// TODO: Provide allocator API
		auto mem = malloc( TypeSize )[ 0 .. TypeSize ];

		GC.addRange( mem.ptr, TypeSize );

		static if( is( Type == struct ) )
		{
			Type* pVal = cast(Type*)mem;
			*pVal = Type();
		}
		else
		{
			static assert( false, "Classes aren't ready to be used like this. Please stick to structs." );

			Type pVal = cast(Type)mem;
			emplace!( Type )( mem[ 0 .. TypeSize ] );
		}

		return cast(void*)mem;
	}

	static extern( C ) void deallocObj( void* pObj )
	in
	{
		assert( thunkObj( pObj ) !is null, "Calling " ~ Type.stringof ~ " deallocator on a different type!" );
	}
	body
	{
		import core.stdc.stdlib : free;
		import core.memory : GC;

		// TODO: Provide allocator API
		auto val = cast( CastType )thunkObj( pObj );
		destroy( val );

		GC.removeRange( pObj );

		free( pObj );
	}

	static extern( C ) const( char )* serialiseObj( void* pObj )
	in
	{
		assert( thunkObj( pObj ) !is null, "Calling " ~ Type.stringof ~ " serialiser on a different type!" );
	}
	body
	{
		version( BoundSerialise )
		{
			import std.json;
			import std.string : toStringz;

			static if( is( Type == struct ) )
			{
				CastType actualObj = cast( CastType )pObj;
				JSONValue serialised = serialise( *actualObj );
			}
			else
			{
				CastType actualObj = cast( CastType )pObj;
				JSONValue serialised = serialise( actualObj );
			}

			string strJSON = toJSON( &serialised );

			return strJSON.toStringz;
		}
		else
		{
			return null;
		}
	}

	static extern( C ) void deserialiseObj( void* pObj, const( char )* pData )
	in
	{
		assert( thunkObj( pObj ) !is null, "Calling " ~ Type.stringof ~ " deserialiser on a different type!" );
	}
	body
	{
		version( BoundSerialise )
		{
			import std.json;
			import core.stdc.string : strlen;

			const( char )[] strJSONSource = pData[ 0 .. strlen( pData ) ];
			JSONValue json = parseJSON( strJSONSource );

			CastType castObj = cast( CastType )pObj;
			static if( is( Type == struct ) )
			{
				deserialise( *castObj, json );
			}
			else
			{
				deserialise( castObj, json );
			}
		}
		else
		{

		}
	}
}
//----------------------------------------------------------------------------

//============================================================================
