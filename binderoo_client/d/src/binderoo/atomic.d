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

module binderoo.atomic;
//----------------------------------------------------------------------------

// Atomic is directly analagous to std::atomic in the C++ Standard Library and
// adheres to the standard functionality defined with it.

import core.atomic;
import binderoo.traits;
//----------------------------------------------------------------------------

template AtomicStorageOf( T )
{
	static assert( T.sizeof <= 8, T.stringof ~ " cannot be used as an atomic variable. Please use basic types only" );

	static if( T.sizeof < 4 )
	{
		static if( IsUnsigned!T )
		{
			alias AtomicStorageOf = uint;
		}
		else
		{
			alias AtomicStorageOf = int;
		}
	}
	else
	{
		alias AtomicStorageOf = T;
	}
}
//----------------------------------------------------------------------------

struct Atomic( T ) if( IsIntegral!T )
{
	alias Storage = AtomicStorageOf!T;

	Storage m_val;

	// C++ std::atomic API

	pragma( inline ) Storage exchange( ref const( Storage ) val )				{ cas( &m_val, &m_val, val ); }
	pragma( inline ) Storage load( ) const										{ return atomicLoad( m_val ); }
	pragma( inline ) void store( ref const( Storage ) val )						{ atomicStore( m_val, val ); }

	alias fetch_add = fetch!"+";
	alias fetch_sub = fetch!"-";
	alias fetch_and = fetch!"&";
	alias fetch_or = fetch!"|";
	alias fetch_xor = fetch!"^";
	//--------------------------------------------------------------------

	// Convenience accessors
	pragma( inline ) Storage opCast( CastType : Storage )()						{ return load(); }
	pragma( inline ) Storage opAssign( ref const( Storage ) val )				{ store( val ); return val; }

	static if( !is( T == Storage ) )
	{
		pragma( inline ) T opCast( CastType : T )()								{ return cast( T )load(); }
		pragma( inline ) Storage opAssign( ref const( Storage ) val )			{ store( cast( T )val ); return val; }
	}
	//--------------------------------------------------------------------

	pragma( inline ) Storage opOpAssign( string op )( ref const( Storage ) val ) if( op == "+" )	{ return fetch_add( val ) + val; }
	pragma( inline ) Storage opOpAssign( string op )( ref const( Storage ) val ) if( op == "-" 	)	{ return fetch_sub( val ) - val; }
	pragma( inline ) Storage opOpAssign( string op )( ref const( Storage ) val ) if( op == "&" )	{ return fetch_and( val ) & val; }
	pragma( inline ) Storage opOpAssign( string op )( ref const( Storage ) val ) if( op == "|" )	{ return fetch_or( val ) | val; }
	pragma( inline ) Storage opOpAssign( string op )( ref const( Storage ) val ) if( op == "^" )	{ return fetch_xor( val ) ^ val; }
	//--------------------------------------------------------------------

	pragma( inline ) Storage opUnary( string op )( ) if( op == "++" )			{ return fetch_add( 1 ) + 1; }
	pragma( inline ) Storage opUnary( string op )( ) if( op == "--" 	)			{ return fetch_sub( 1 ) - 1; }

	pragma( inline ) Storage fetch( string op )( ref const( Storage ) val )		{ return atomicOp!op( m_val, val ); }

}
//----------------------------------------------------------------------------

//============================================================================
