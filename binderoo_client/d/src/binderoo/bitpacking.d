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

module binderoo.bitpacking;
//----------------------------------------------------------------------------

// BitPack is a simple bit packing object, in a similar way to how C bitfields
// work.
//
// To use it, you either define a struct with all the necessary variables you
// want, or use the string macro (because D doesn't support inline aggregate
// type definitions). Each variable must be marked up with a @PackSize UDA
// to indicate how many bits it will consume as storage.
//
// Usage example:
//
// struct SomeObject
// {
//   mixin BitPack!( "@PackSize( 5 ) int foo; @PackSize( 12 ) short bar = 666; @PackSize( 2 ) int heh = 1;" );"
// }
//
// This will create a statically sized array for storage; and will also create
// properties to get and set foo, bar, and heh separately.
//
// If you wish to use more than one bitpack in your aggregate type, you must
// provide a name for each subsequent bitpack after the first or else you will
// get compile errors due to conflicting symbol names.
//
// struct SomeComplicatedObject
// {
//   mixin BitPack!( "@PackSize( 5 ) int foo; @PackSize( 12 ) short bar = 666; @PackSize( 2 ) int heh = 1;" );"
//   mixin BitPack!( "@PackSize( 3 ) int nope = 2; @PackSize( 4 ) int alsoNope;", "BunchOfNope" );"
//   mixin BitPack!( "@PackSize( 5 ) int yep; @PackSize( 5 ) int alsoYep = 9;", "BunchOfYep" );"
// }
//
//----------------------------------------------------------------------------

struct PackSize
{
	int iPackSize;
}
//----------------------------------------------------------------------------

mixin template BitPack( Descriptor, string NameAlias = Descriptor.stringof )
{
	version( BitPackCompileTimeDebug ) pragma( msg, GenerateBitPackBody!( Descriptor, NameAlias )() );

	mixin( GenerateBitPackBody!( Descriptor, NameAlias )() );
}
//----------------------------------------------------------------------------

mixin template BitPack( string ElementsWithPackingInfoAndDefaultValuesAndSemicolons, string NameAlias = "BitPackData" )
{
	mixin( "mixin BitPack!( typeof( { struct BitPackData { " ~ ElementsWithPackingInfoAndDefaultValuesAndSemicolons ~ " } return BitPackData.init; }() ), NameAlias );" );
}
//----------------------------------------------------------------------------

// IMPLEMENTATION FOLLOWS
//----------------------------------------------------------------------------

// version = BitPackCompileTimeDebug;

import binderoo.traits;
import binderoo.objectprivacy;

int GetTotalPackSize( Descriptor )()
{
	int iPackSize = 0;
	foreach( member; __traits( allMembers, Descriptor ) )
	{
		static if( IsAccessible!( Descriptor, member )
				&& is( typeof( __traits( getMember, Descriptor, member ) ) )
				&& !is( typeof( __traits( getMember, Descriptor, member ) ) == void )
				&& IsMemberVariable!( __traits( getMember, Descriptor, member ) ) )
		{
			alias PackSizeUDA = GetUDA!( __traits( getMember, Descriptor, member ), PackSize );

			static assert( !is( PackSizeUDA == void ), "Variable " ~ member ~ " requires a @PackSize definition." );
			static assert( typeof( __traits( getMember, Descriptor, member ) ).sizeof <= 8, "Variable " ~ member ~ " is larger than 64 bits, BitPacker does not support this." );
			iPackSize += PackSizeUDA.iPackSize;
		}
	}

	return iPackSize;
}
//----------------------------------------------------------------------------

auto BitMask( T )( T iBitCount )
{
	return cast( T )( ( 1 << iBitCount ) - 1 );
}
//----------------------------------------------------------------------------

int AlignTo( int Alignment )( int iVal )
{
	enum Mask = Alignment - 1;
	return ( iVal + Mask ) & ~Mask;
}
//----------------------------------------------------------------------------

template StorageByBytes( int iBytes )
{
	static if( iBytes == 1 )
	{
		alias StorageByBytes = byte;
	}
	else static if( iBytes == 2 )
	{
		alias StorageByBytes = ushort;
	}
	else static if( iBytes == 4 )
	{
		alias StorageByBytes = uint;
	}
	else static if( iBytes == 8 )
	{
		alias StorageByBytes = ulong;
	}
	else
	{
		static assert( false, "No basic type supports storage of " ~ iVal.stringof ~ " bytes." );
	}
}
//----------------------------------------------------------------------------

string GenerateBitPackBody( Descriptor, string NameAlias )()
{
	import std.conv : to;
	import std.algorithm : min, max;
	import std.math : abs;

	enum TotalPackSize = GetTotalPackSize!( Descriptor )();
	enum ArraySize = AlignTo!4( AlignTo!8( TotalPackSize ) >> 3 );

	string strOutput;

	ubyte[ ArraySize ] initialisers = 0;
	int iBitStart = 0;

	foreach( member; __traits( allMembers, Descriptor ) )
	{
		static if( IsAccessible!( Descriptor, member )
				&& is( typeof( __traits( getMember, Descriptor, member ) ) )
				&& !is( typeof( __traits( getMember, Descriptor, member ) ) == void )
				&& IsMemberVariable!( __traits( getMember, Descriptor, member ) ) )
		{
			alias PackSizeUDA = GetUDA!( __traits( getMember, Descriptor, member ), PackSize );

			enum VariableName = member;
			enum VariableTypeName = typeof( __traits( getMember, Descriptor, member ) ).stringof;
			alias VariableType = typeof( __traits( getMember, Descriptor, member ) );
			enum StorageType = StorageByBytes!( VariableType.sizeof ).stringof;
			mixin( "enum InitValue = Descriptor.init." ~ VariableName ~ ";" );

			int iThisVariableBitStart = iBitStart;
			int iBitsLeft = PackSizeUDA.iPackSize;

			version( BitPackCompileTimeDebug ) strOutput ~= "// " ~ VariableName ~ " accessors";
			version( BitPackCompileTimeDebug ) strOutput ~= "// -> Start bit: " ~ to!string( iThisVariableBitStart ) ~ ", total size: " ~ to!string( iBitsLeft );

			string strGetter = "@property " ~ VariableTypeName ~ " " ~ VariableName ~ "() { " ~ StorageType ~ " storage = 0; ";
			string strSetter = "@property " ~ VariableTypeName ~ " " ~ VariableName ~ "( " ~ VariableTypeName ~ " val ) in { import std.conv : to; assert( val >= 0, \"Negative values currently unsupported.\" ); assert( val < " ~ to!string( 1 << PackSizeUDA.iPackSize ) ~ ", \"Value \" ~ to!string( val ) ~ \" is larger than " ~ VariableName ~ " can hold.\" ); } body { ";

			while( iBitsLeft > 0 )
			{
				int iThisArrayIndex = iBitStart >> 3;
				int iThisStartBit = ( iBitStart & 0x7 );
				int iBitsThisAccess = min( iBitsLeft, 8 - iThisStartBit );
				ubyte iThisMask = cast( ubyte )( BitMask( iBitsThisAccess ) << iThisStartBit );
				ubyte iThisInvertMask = ~iThisMask;
				int iTotalShift = abs( iBitsLeft - PackSizeUDA.iPackSize );

				initialisers[ iThisArrayIndex ] = cast( ubyte )( ( initialisers[ iThisArrayIndex ] & iThisInvertMask ) | ( ( ( InitValue >> iTotalShift ) & BitMask( iBitsThisAccess ) ) << iThisStartBit ) );
				
				version( BitPackCompileTimeDebug ) strOutput ~= "// -> Array index: " ~ to!string( iThisArrayIndex ) ~ ", bits this access: " ~ to!string( iBitsThisAccess ) ~ ", start bit: " ~ to!string( iThisStartBit ) ~ ", this mask: " ~ to!string( iThisMask );

				strGetter ~= "storage |= ( cast( " ~ StorageType ~ " )( " ~ NameAlias ~ "[ " ~ to!string( iThisArrayIndex ) ~ " ] & " ~ to!string( iThisMask ) ~ " ) >> " ~ to!string( iThisStartBit ) ~ " ) << " ~ to!string( iTotalShift ) ~ "; ";
				strSetter ~= NameAlias ~ "[ " ~ to!string( iThisArrayIndex ) ~ " ] = cast( ubyte )( ( " ~ NameAlias ~ "[ " ~ to!string( iThisArrayIndex ) ~ " ] & " ~ to!string( iThisInvertMask ) ~ " ) | ( ( ( val >> " ~ to!string( iTotalShift ) ~ " ) & " ~ to!string( BitMask( iBitsThisAccess ) ) ~ " ) << " ~ to!string( iThisStartBit ) ~ " ) ); ";
				iBitsLeft -= iBitsThisAccess;
				iBitStart += iBitsThisAccess;
			}
				
			strOutput ~= strGetter ~ "return *( cast( " ~ VariableTypeName ~ "* )&storage ); }\n";
			strOutput ~= strSetter ~ "return val; }\n";
			strOutput ~= "\n";
		}
	}

	strOutput ~= "ubyte[ " ~ ArraySize.stringof ~ " ] " ~ NameAlias ~ " = " ~ to!string( initialisers ) ~ ";\n";

	return strOutput;
}
//----------------------------------------------------------------------------

unittest
{
	struct TestStruct
	{
		mixin BitPack!( "@PackSize( 5 ) int foo = 14; @PackSize( 12 ) short bar = 666; @PackSize( 2 ) int pizzazz = 1;" );
	}

	TestStruct instance;

	import std.conv : to;

	assert( instance.foo, "Initial value of foo is not 14, it is " ~ instance.foo );
	assert( instance.bar, "Initial value of bar is not 666, it is " ~ instance.bar );
	assert( instance.pizzazz, "Initial value of pizzazz is not 1, it is " ~ instance.pizzazz );

	instance.foo = 5;
	instance.bar = 1536;
	instance.pizzazz = 2;

	assert( instance.foo, "Set value of foo is not 5, it is " ~ instance.foo );
	assert( instance.bar, "Set value of bar is not 1536, it is " ~ instance.bar );
	assert( instance.pizzazz, "Set value of pizzazz is not 2, it is " ~ instance.pizzazz );

	instance.pizzazz = 1;
	instance.bar = cast( short )65535;
	instance.foo = 127;

	assert( instance.foo, "Set value of foo is not 1, it is " ~ instance.foo );
	assert( instance.bar, "Set value of bar is not 4095, it is " ~ instance.bar );
	assert( instance.pizzazz, "Set value of pizzazz is not 31, it is " ~ instance.pizzazz );
}
//----------------------------------------------------------------------------

//============================================================================
