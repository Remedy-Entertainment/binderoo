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

module binderoo.traits;
//----------------------------------------------------------------------------

private import std.traits;
//----------------------------------------------------------------------------

// Get the instance of an attribute bound to a symbol.
template GetUDA( alias symbol, Attribute )
{
	template Impl( A... )
	{
		static if( A.length == 0 )
		{
			alias void Impl;
		}
		else static if( is( A[ 0 ] ) )
		{
			static if( is( A[ 0 ] == Attribute ) )
			{
				enum Attribute Impl = Attribute();
			}
			else
			{
				alias Impl!( A[1..$] ) Impl;
			}
		}
		else static if( is( typeof( A[ 0 ] ) == Attribute ) )
		{
			enum Impl = A[ 0 ];
		}
		else
		{
			alias Impl!( A[ 1..$ ] ) Impl;
		}
	}

	alias GetUDA = Impl!( __traits( getAttributes, symbol ) );
}
//----------------------------------------------------------------------------

template HasUDA( alias symbol, Attribute )
{
	enum HasUDA = !is( GetUDA!( symbol, Attribute ) == void );
}
//----------------------------------------------------------------------------

template IsConst( T )
{
	enum IsConst = is( T == const( BaseT ), BaseT );
}
//----------------------------------------------------------------------------

template IsImmutable( T )
{
	enum IsImmutable = is( T == immutable( BaseT ), BaseT );
}
//----------------------------------------------------------------------------

template IsInOut( T )
{
	enum IsInOut = is( T == inout( BaseT ), BaseT );
}
//----------------------------------------------------------------------------

template IsUserType( T )
{
	enum IsUserType = is( T == struct ) || is( T == class ) || is( T == enum ) || is( T == interface ) || is( T == union );
}
//----------------------------------------------------------------------------

template IsUserTypeButNotEnum( T )
{
	enum IsUserTypeButNotEnum = is( T == struct ) || is( T == class ) || is( T == interface ) || is( T == union );
}
//----------------------------------------------------------------------------

template IsStaticMember( T, alias Member )
{
	static if( __traits( compiles, __traits( getMember, T, Member ) ) )
	{
		enum IsStaticMember = IsVariable!( __traits( getMember, T, Member ) );
	}
	else
	{
		enum IsStaticMember = false;
	}
}
//----------------------------------------------------------------------------

template IsPointer( T )
{
	enum IsPointer = false;
}
//----------------------------------------------------------------------------

template IsPointer( T : T* )
{
	enum IsPointer = true;
}
//----------------------------------------------------------------------------

template ArrayValueType( A : T[], T )
{
	alias ArrayValueType = T;
}
//----------------------------------------------------------------------------

template ArrayValueType( A : T[ E ], T, E )
{
	alias ArrayValueType = T;
}
//----------------------------------------------------------------------------

template ArrayKeyType( A : T[ E ], T, E )
{
	alias ArrayKeyType = E;
}
//----------------------------------------------------------------------------

template IsSomeArray( T )
{
	enum IsSomeArray = false;
}
//----------------------------------------------------------------------------

template IsSomeArray( A : T[], T )
{
	enum IsSomeArray = true;
}
//----------------------------------------------------------------------------

template IsSomeArray( A : T[ E ], T, E )
{
	enum IsSomeArray = true;
}
//----------------------------------------------------------------------------

template IsPlainArray( T )
{
	enum IsPlainArray = false;
}
//----------------------------------------------------------------------------

template IsPlainArray( A : T[], T )
{
	enum IsPlainArray = true;
}
//----------------------------------------------------------------------------

template IsAssociativeArray( T )
{
	enum IsAssociativeArray = false;
}
//----------------------------------------------------------------------------

template IsAssociativeArray( A : T[ E ], T, E )
{
	enum IsAssociativeArray = true;
}
//----------------------------------------------------------------------------

template IsSomeType( T )
{
	enum IsSomeType = true;
}
//----------------------------------------------------------------------------

template IsSomeType( T : void )
{
	enum IsSomeType = false;
}
//----------------------------------------------------------------------------

template IsSomeType( alias symbol )
{
	enum IsSomeType = is( symbol );
}
//----------------------------------------------------------------------------

template IsVariable( X... ) if ( X.length == 1 )
{
	static if( is( X[ 0 ] == void ) || is( typeof( X[ 0 ] ) == void ) )
	{
		enum IsVariable = false;
	}
	else static if ( !IsSomeType!( X[ 0 ] ) )
	{
		static if( isSomeFunction!( X[ 0 ] ) )
		{
			enum IsVariable = isFunctionPointer!( X[ 0 ] ) || isDelegate!( X[ 0 ] );
		}
		else
		{
			enum IsVariable = is( typeof( X [ 0 ] ) )
							&& !is( typeof( X [ 0 ] ) == void )
							&& IsMutable!( typeof( X[ 0 ] ) );
		}
	}
	else
	{
		enum IsVariable = false;
	}
}
//----------------------------------------------------------------------------

template IsMemberVariable( X... ) if( X.length == 1 )
{
	static if( IsVariable!( X[ 0 ] ) )
	{
		enum IsMemberVariable = is( typeof( { enum OffsetOf = X[ 0 ].offsetof; } ) );
	}
	else
	{
		enum IsMemberVariable = false;
	}
}
//----------------------------------------------------------------------------

template PointerOf( T )
{
	alias PointerOf = T*;
}
//----------------------------------------------------------------------------

template IsMutable( T )
{
	enum IsMutable = !( is( T == const )
						|| is( T == immutable )
						|| is( T == inout ) );
}
//----------------------------------------------------------------------------

template Unqualified( T )
{
	static if(		is( T A == immutable A )
				||	is( T A == shared inout const A )
				||	is( T A == shared inout A )
				||	is( T A == inout const A )
				||	is( T A == inout A )
				||	is( T A == shared const A )
				||	is( T A == shared A )
				||	is( T A == const A ) )
	{
		alias Unqualified = A;
	}
	else
	{
		alias Unqualified = T;
	}
}
//----------------------------------------------------------------------------

template TemplateParametersOf( T )
{
	static if( !IsMutable!( T ) )
	{
		alias UnqualifiedType = Unqualified!( T );
		alias TemplateParametersOf = TemplateParametersOf!( UnqualifiedType );
	}
	else
	{
		private import std.typetuple;
		alias TemplateParametersOf = TypeTuple!( );
	}
}
//----------------------------------------------------------------------------

template TemplateParametersOf( T : U!( Params ), alias U, Params... )
{
	private import std.typetuple;

	alias TemplateParametersOf = TypeTuple!( Params );
}
//----------------------------------------------------------------------------

template TemplateParametersOf( T : __vector( Type[ Length ] ), Type, size_t Length )
{
	private import std.typetuple;

	alias TemplateParametersOf = TypeTuple!( Type[ Length ] );
}
//----------------------------------------------------------------------------

template IsTemplatedType( T )
{
	static if( IsMutable!( T ) )
	{
		enum IsTemplatedType = false;
	}
	else
	{
		alias IsTemplatedType = IsTemplatedType!( Unqualified!( T ) );
	}
}
//----------------------------------------------------------------------------

template IsTemplatedType( T : U!( Params ), alias U, Params... )
{
	enum IsTemplatedType = true;
}
//----------------------------------------------------------------------------

template TemplateOf( T )
{
	alias TemplateOf = void;
}
//----------------------------------------------------------------------------

template TemplateOf( T : U!( Params ), alias U, Params... )
{
	alias TemplateOf = U;
}
//----------------------------------------------------------------------------

template SupportsAppend( T : U[], U )
{
	enum SupportsAppend = true;
}
//----------------------------------------------------------------------------

// This one currently fails under some circumstances.
/+template FullyQualifiedNameInsideModule( T )
{
	static if( is( T : U*, U ) )
	{
		enum FullyQualifiedNameInsideModule = FullyQualifiedNameInsideModule!( U ) ~ "*";
	}
	else static if( __traits( compiles, __traits( parent, T ) ) )
	{
		alias Symbol = Identity!( __traits( parent, T ) );

		static if( is( Symbol ) )
		{
			enum FullyQualifiedNameInsideModule = FullyQualifiedNameInsideModule!( Symbol ) ~ "." ~ T.stringof;
		}
		else
		{
			enum FullyQualifiedNameInsideModule = T.stringof;
		}

	}
	else
	{
		enum FullyQualifiedNameInsideModule = T.stringof;
	}
}
//----------------------------------------------------------------------------
+/
string[] gatherImports( T )()
{
	// Not complete, does not parse member types correctly
	string[] modules;

	void addModule( string name )
	{
		import std.algorithm;
		if( !modules.canFind( name ) )
		{
			modules ~= "import " ~ name ~ ";";
		}
	}

	static if( IsUserType!( T ) )
	{
		import std.traits;
		import binderoo.objectprivacy;

		addModule( moduleName!( T ) );

		static if( IsTemplatedType!( T ) )
		{
			foreach( Parameter; TemplateParametersOf!( T ) )
			{
				static if ( is( Parameter ) )
				{
					modules ~= gatherImports!( T );
				}
			}
		}

		foreach( member; __traits( allMembers, T ) )
		{
			static if( IsAccessible!( T, member ) && IsMemberVariable!( __traits( getMember, T, member ) ) && IsUserType!( typeof( __traits( getMember, T, member ) ) ) )
			{
				addModule( moduleName!( typeof( __traits( getMember, T, member ) ) ) );
			}
		}
	}

	return modules;
}
//----------------------------------------------------------------------------

auto joinWith( T )( T[] values, T joiner ) pure @safe nothrow if( SupportsAppend!( T ) )
{
	T output;

	foreach( ref value; values )
	{
		if( output.length > 0 )
		{
			output ~= joiner;
		}
		output ~= value;
	}

	return output;
}
//----------------------------------------------------------------------------

auto joinWith( T )( T[] values, T preJoiner, T postJoiner, T separator ) pure @safe nothrow if( SupportsAppend!( T ) )
{
	T output;

	foreach( ref value; values )
	{
		if( output.length > 0 )
		{
			output ~= postJoiner ~ separator;
		}
		output ~= preJoiner ~ value;
	}

	if( output.length > 0 )
	{
		return output ~ postJoiner;
	}

	return output;
}
//----------------------------------------------------------------------------

auto joinWithReverse( T )( T[] values, T joiner ) pure @safe nothrow if( SupportsAppend!( T ) )
{
	T output;

	foreach_reverse( ref value; values )
	{
		if( output.length > 0 )
		{
			output ~= joiner;
		}
		output ~= value;
	}

	return output;
}
//----------------------------------------------------------------------------

//============================================================================
