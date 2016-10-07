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

module binderoo.typedescriptor;
//----------------------------------------------------------------------------

public import binderoo.traits;
public import std.traits;
//----------------------------------------------------------------------------

struct TypeDescriptor( T, bool bIsRef = false )
{
	template HasUDA( Attr )
	{
		static if( is( T == void ) )
		{
			enum HasUDA = false;
		}
		else
		{
			enum HasUDA = binderoo.traits.HasUDA!( T, Attr );
		}
	}
	//-------------------------------------------------------------------------

	template GetUDA( Attr )
	{
		static if( is( T == void ) )
		{
			alias GetUDA = void;
		}
		else
		{
			alias GetUDA = binderoo.traits.GetUDA!( T, Attr );
		}
	}
	//-------------------------------------------------------------------------

	alias			Type							= T;
	enum			Name							= T.stringof;

	alias			UnqualifiedType					= Unqualified!( T );

	enum			Size							= T.sizeof;

	enum			IsScalarType					= std.traits.isScalarType!( T );
	enum			IsBasicType						= std.traits.isBasicType!( T );
	enum			IsAggregateType					= std.traits.isAggregateType!( T );
	enum			IsUserType						= binderoo.traits.IsUserType!( T );

	enum			IsVoid							= is( T == void );
	enum			IsEnum							= is( T == enum );
	enum			IsStruct						= is( T == struct );
	enum			IsClass							= is( T == class );
	enum			IsInterface						= is( T == interface );

	enum			IsConst							= binderoo.traits.IsConst!( T );
	enum			IsImmutable						= binderoo.traits.IsImmutable!( T );
	enum			IsRef							= bIsRef;
	enum			IsPointer						= binderoo.traits.IsPointer!( T );

	// Arrays are a bit special. We handle associative arrays, arrays, and not-an-array separately.
	static if( binderoo.traits.IsAssociativeArray!( T ) )
	{
		// We define IsElementAssociativeArray to true AND IsElementArray to false here. This provides a complete descriptor regardless of the type.
		enum		IsSomeArray						= true;
		enum		IsAssociativeArray				= true;
		enum		IsArray							= false;
		alias 		ArrayValueType					= TypeDescriptor!( binderoo.traits.ArrayValueType!( T ) );
		alias		ArrayKeyType					= TypeDescriptor!( binderoo.traits.ArrayKeyType!( T ) );
	}
	else static if( binderoo.traits.IsPlainArray!( T ) )
	{
		// The key type is aliased to void here as we don't actually have a key type.
		enum		IsSomeArray						= true;
		enum		IsAssociativeArray				= false;
		enum		IsArray							= true;
		alias		ArrayValueType					= TypeDescriptor!( binderoo.traits.ArrayValueType!( T ) );
		alias		ArrayKeyType					= TypeDescriptor!( void );
	}
	else
	{
		// And the array types and identifying enumerations are set to void and false here.
		enum		IsSomeArray						= false;
		enum		IsAssociativeArray				= false;
		enum		IsArray							= false;
		alias		ArrayValueType					= TypeDescriptor!( void );
		alias		ArrayKeyType					= TypeDescriptor!( void );
	}

}
//----------------------------------------------------------------------------
//----------------------------------------------------------------------------

// Mark up your user types with this
struct CTypeName
{
	string name;
	string header;
	ulong hash;

	@disable this();

	this( string n )
	{
		import binderoo.hash;
		name = n;
		hash = fnv1a_64( name );
	}

	this( string n, string h )
	{
		import binderoo.hash;
		name = n;
		header = h;
		hash = fnv1a_64( name );
	}
}
//----------------------------------------------------------------------------

// Dealing with a native type or library type? Stick this somewhere visible.
enum CTypeNameUndefinedOverride			= "undefined";
enum CTypeNameOverride( T )				= CTypeNameUndefinedOverride;
//----------------------------------------------------------------------------

// Default overrides
enum CTypeNameOverride( T : ushort )	= "unsigned short";
enum CTypeNameOverride( T : uint )		= "unsigned int";
enum CTypeNameOverride( T : wchar )		= "wchar_t";
enum CTypeNameOverride( T : byte )		= "char";
enum CTypeNameOverride( T : ubyte )		= "unsigned char";
enum CTypeNameOverride( T : long )		= "int64_t";
enum CTypeNameOverride( T : ulong )		= "uint64_t";
enum CTypeNameOverride( T : bool )		= "bool"; // Returns char otherwise when parsing functions? o_O
//----------------------------------------------------------------------------

template CTypeString( T )
{
	template TemplateParameters( uint iIndex, T... )
	{
		static if( iIndex < T.length )
		{
			enum TemplateParameters = CTypeString!( T[ iIndex ] ) ~ ( iIndex < T.length - 1 ? ", " ~ TemplateParameters!( iIndex + 1, T ) : "" );
		}
		else
		{
			enum TemplateParameters = "";
		}
	}

	template TemplateParametersString( T )
	{
		static if( IsTemplatedType!( T ) )
		{
			enum TemplateParametersString = "< " ~ TemplateParameters!( 0u, TemplateParametersOf!( T ) ) ~ " >";
		}
		else
		{
			enum TemplateParametersString = "";
		}
	}

	template TemplateTypeString( T : Obj!( Params ), alias Obj, Params... )
	{
		enum TemplateTypeString = Obj.stringof;
	}

	template TemplateTypeString( T )
	{
		enum TemplateTypeString = T.stringof;
	}

	static if( isPointer!( T ) )
	{
		enum CTypeString = CTypeString!( PointerTarget!( T ) ) ~ "*";
	}
	else static if( IsConst!( T ) || IsImmutable!( T ) )
	{
		enum CTypeString = "const " ~ CTypeString!( Unqual!( T ) );
	}
	else static if( CTypeNameOverride!( T ) != CTypeNameUndefinedOverride )
	{
		enum CTypeString = CTypeNameOverride!( T );
	}
	else static if( IsUserType!( T ) )
	{
		static if( HasUDA!( T, CTypeName ) )
		{
			enum CTypeString = GetUDA!( T, CTypeName ).name ~ TemplateParametersString!( T );
		}
		else
		{
			enum CTypeString = TemplateTypeString!( T ) ~ TemplateParametersString!( T );
		}
	}
	else
	{
		enum CTypeString = T.stringof;
	}
}
//----------------------------------------------------------------------------

// Value writing is required for template parameters
template CTypeString( long val )
{
	import std.conv : to; enum CTypeString = to!string( val );
}
//----------------------------------------------------------------------------

template CTypeString( ulong val )
{
	import std.conv : to; enum CTypeString = to!string( val );
}
//----------------------------------------------------------------------------

struct TypeString( T, bool bIsRef = false )
{
	static private string typeStringD( string T )
	{
		return ( bIsRef ? "ref " : "" ) ~ T;
	}

	static private string typeStringC( string T )
	{
		return T ~ ( bIsRef ? "&" : "" );
	}
	//------------------------------------------------------------------------

	enum			FullyQualifiedDDecl				= typeStringD( fullyQualifiedName!( T ) );
	enum			DDecl							= typeStringD( T.stringof );
	enum			CDecl							= typeStringC( CTypeString!( T ) );
}
//----------------------------------------------------------------------------

template TypeString( Desc : TypeDescriptor!( T, bIsRef ), T, bool bIsRef )
{
	alias TypeString = TypeString!( T, bIsRef );
}
//----------------------------------------------------------------------------

//============================================================================
