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
	enum			IsPointer						= std.traits.isPointer!( T );

	// Arrays are a bit special. We handle associative arrays, arrays, and not-an-array separately.
	static if( std.traits.isAssociativeArray!( T ) )
	{
		// We define IsElementAssociativeArray to true AND IsElementArray to false here. This provides a complete descriptor regardless of the type.
		enum		IsSomeArray						= true;
		enum		IsAssociativeArray				= true;
		enum		IsArray							= false;
		alias 		ArrayValueType					= TypeDescriptor!( std.traits.ValueType!( T ) );
		alias		ArrayKeyType					= TypeDescriptor!( std.traits.KeyType!( T ) );
	}
	else static if( std.traits.isArray!( T ) )
	{
		// The key type is aliased to void here as we don't actually have a key type.
		enum		IsSomeArray						= true;
		enum		IsAssociativeArray				= false;
		enum		IsArray							= true;
		alias		ArrayValueType					= TypeDescriptor!( binderoo.traits.ArrayType!( T ) );
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

struct CTypeName
{
	string name;
	ulong hash;

	this( string n )
	{
		import binderoo.hash;
		name = n;
		hash = fnv1a_64( name );
	}
}
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
	else static if( is( T == ushort ) )
	{
		enum CTypeString = "unsigned short";
	}
	else static if( is( T == uint ) )
	{
		enum CTypeString = "unsigned int";
	}
	else static if( is( T == wchar ) )
	{
		enum CTypeString = "wchar_t";
	}
	else static if( is( T == byte ) )
	{
		enum CTypeString = "char";
	}
	else static if( is( T == ubyte ) )
	{
		enum CTypeString = "unsigned char";
	}
	else static if( is( T == long ) )
	{
		enum CTypeString = "int64_t";
	}
	else static if( is( T == ulong ) )
	{
		enum CTypeString = "uint64_t";
	}
	else
	{
		enum CTypeString = T.stringof;
	}
}
//----------------------------------------------------------------------------

struct TypeString( T, bool bIsRef = false )
{
	static private string typeStringD( string T, bool bIsRef )
	{
		return ( bIsRef ? "ref " : "" ) ~ T;
	}

	static private string typeStringC( string T , bool bIsRef )
	{
		return T ~ ( bIsRef ? "&" : "" );
	}
	//------------------------------------------------------------------------

	enum			FullyQualifiedDDecl				= typeStringD( fullyQualifiedName!( T ), bIsRef );
	enum			DDecl							= typeStringD( T.stringof, bIsRef );
	enum			CDecl							= typeStringC( CTypeString!( T ), bIsRef );
}
//----------------------------------------------------------------------------

template TypeString( Desc : TypeDescriptor!( T, bIsRef ), T, bool bIsRef )
{
	alias TypeString = TypeString!( T, bIsRef );
}
//----------------------------------------------------------------------------

//============================================================================
