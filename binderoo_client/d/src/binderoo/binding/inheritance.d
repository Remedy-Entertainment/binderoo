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

module binderoo.binding.inheritance;
//----------------------------------------------------------------------------

import binderoo.traits;
//----------------------------------------------------------------------------

//version = InheritanceDebug;
version( InheritanceDebug )
{
//	version = InheritanceInspectionDebug;
//	version = InheritanceVTableDebug;
//	version = InheritanceMTableDebug;
}
version = InheritanceMSVC;

import std.typecons;
import std.typetuple;

import binderoo.binding.functionstub;
import binderoo.objectprivacy;

struct InheritanceBase { }
struct InheritanceGeneratedVTable { }
struct InheritanceVirtualCall { }
struct InheritanceMethodCall { }
//----------------------------------------------------------------------------

template BaseTypes( Type )
{
	static if( __traits( compiles, typeof( Type.base ) ) && HasUDA!( Type.base, InheritanceBase ) )
	{
		alias BaseTypes = TypeTuple!( BaseTypes!( typeof( Type.base ) ), typeof( Type.base ) );
	}
	else
	{
		alias BaseTypes = TypeTuple!();
	}
}
//----------------------------------------------------------------------------

private string generateMassiveBaseString( uint iDepth )
{
	string output = "base";

	foreach( iCurrDepth; 1 .. iDepth + 1 )
	{
		output ~= ".base";
	}

	return output;
}
//----------------------------------------------------------------------------

template GenerateBaseAccessors( Type, uint iDepth = 0u )
{
	static if( __traits( compiles, typeof( Type.base ) ) && HasUDA!( Type.base, InheritanceBase ) )
	{
		alias BaseType = typeof( Type.base );
		enum BaseString = GenerateBaseAccessors!( BaseType, iDepth + 1 );
	}
	else
	{
		enum BaseString = "";
	}

	enum GenerateBaseAccessors = "private pragma( inline ) final @property " ~ Type.stringof ~ "() { return " ~ generateMassiveBaseString( iDepth ) ~ "; }\n" ~ BaseString;

}
//----------------------------------------------------------------------------

mixin template GenerateImports( ThisType )
{
	@InheritanceGeneratedVTable struct VTable
	{
		public import std.typetuple;
		public import binderoo.binding.functionstub;
		public import binderoo.objectprivacy;

		static private string generateTypeMixin()
		{
			alias Types = TypeTuple!( BaseTypes!( ThisType ), ThisType );

			import std.algorithm;
			import std.conv;
			import binderoo.traits;
			import binderoo.functiondescriptor;

			enum ThisModule = "public import " ~ moduleName!( ThisType ) ~ ";";

			string[] modules;
			string[] pointers;
			string[] identifiers;

			int iIndex = 0;
			foreach( CurrType; Types )
			{
				static if( __traits( compiles, CurrType.MethodDescriptor ) && !is( CurrType.MethodDescriptor == void ) )
				{
					enum CurrTypeModule = "public import " ~ moduleName!( CurrType ) ~ ";";

					if( CurrTypeModule != ThisModule && !modules.canFind( CurrTypeModule ) )
					{
						modules ~= CurrTypeModule;
					}

					foreach( Function; FunctionDescriptors!( CurrType.MethodDescriptor ) )
					{
						static if( Function.HasUDA!( BindVirtual ) )
						{
							alias FunctionDetails = Function.GetUDA!( BindVirtual );

							string UDAs = "@NoScriptVisibility @BindRawImport( \"" ~ TypeString!( ThisType, false ).CDecl ~ "::" ~ Function.Name ~ "\", \"" ~ FunctionString!( Function ).CSignature ~ "\", BindRawImport.FunctionKind.Virtual, " ~ to!string( FunctionDetails.iIntroducedVersion ) ~ ", " ~ to!string( FunctionDetails.iMaxVersion ) ~ " )";
							string identifier = "function" ~ to!string( iIndex++ );

							identifiers ~= identifier;
							pointers ~= UDAs ~ "\nRawMemberFunctionPointer!( FunctionDescriptor!(" ~ fullyQualifiedName!( Function.ObjectType ) ~ ", \"" ~ Function.Name ~ "\", " ~ to!string( Function.OverloadIndex ) ~ " )" ~ ", " ~ ThisType.stringof ~ " ) " ~ identifier ~ ";";
						}
					}
				}
			}

			if( pointers.length > 0 )
			{
				return modules.joinWith( "\n" ) ~ "\n" ~ pointers.joinWith( "\n\n" ) ~ "\n\n" ~ "enum FunctionCount = " ~ to!string( identifiers.length ) ~ ";\n\n";
			}
			else
			{
				return "enum FunctionCount = " ~ to!string( identifiers.length ) ~ ";\n\n";
			}
		}

		static string generateAccessorsString()
		{
			alias Types = TypeTuple!( BaseTypes!( ThisType ), ThisType );

			import std.algorithm;
			import std.conv;
			import binderoo.traits;
			import binderoo.functiondescriptor;

			string[] functionCalls;

			int iIndex = 0;
			string[] pointers;
			foreach( CurrType; Types )
			{
				static if( __traits( compiles, CurrType.MethodDescriptor ) && !is( CurrType.MethodDescriptor == void ) )
				{
					foreach( Function; FunctionDescriptors!( CurrType.MethodDescriptor ) )
					{
						static if( Function.HasUDA!( BindVirtual ) )
						{
							static if( !Function.HasUDA!( BindDisallow ) )
							{
								string[] parameterNames = [ "thisObj" ];
								//string staticParameterNames[] = [ ThisType.stringof ~ "* thisObj" ];

								static if( FunctionString!( Function ).ParameterNames.length > 0 )
								{
									parameterNames ~= FunctionString!( Function ).ParameterNames;
									//staticParameterNames ~= FunctionString!( Function ).ParameterDeclarations;
								}

								string pointerName = "function" ~ to!string( iIndex );
								functionCalls ~= "@InheritanceVirtualCall pragma( inline ) " ~ FunctionString!( Function ).DDeclNoLinkage ~ " { auto thisObj = &this; return __vtableData." ~ pointerName ~ "( " ~ parameterNames.joinWith( ", " ) ~ " ); }";
								//functionCalls ~= "static private auto __vtablecall_" ~ pointerName ~ "( " ~ staticParameterNames.joinWith( ", " ) ~ " ) { return __vtableData." ~ pointerName ~ "( " ~ parameterNames.joinWith( ", " ) ~ " ); }";
							}
							++iIndex;
						}
					}
				}
			}

			return functionCalls.joinWith( "\n" );
		}

		mixin( generateTypeMixin() );

		version( InheritanceVTableDebug ) pragma( msg, ThisType.stringof ~ " vtable:\n" ~ generateTypeMixin() );

		final void** getPointer() { return cast(void**)&this; }
	}
	//------------------------------------------------------------------------

	struct MethodTable
	{
		public import std.typetuple;
		public import binderoo.binding.functionstub;
		public import binderoo.objectprivacy;

		static private string generateTypeMixin()
		{
			alias Types = TypeTuple!( BaseTypes!( ThisType ), ThisType );

			import std.algorithm;
			import std.conv;
			import binderoo.traits;
			import binderoo.functiondescriptor;

			enum ThisModule = "public import " ~ moduleName!( ThisType ) ~ ";";

			string[] modules;
			string[] pointers;

			int iIndex = 0;
			foreach( CurrType; Types )
			{
				static if( __traits( compiles, CurrType.MethodDescriptor ) && !is( CurrType.MethodDescriptor == void ) )
				{
					enum CurrTypeModule = "public import " ~ moduleName!( CurrType ) ~ ";";

					if( CurrTypeModule != ThisModule && !modules.canFind( CurrTypeModule ) )
					{
						modules ~= CurrTypeModule;
					}

					foreach( Function; FunctionDescriptors!( CurrType.MethodDescriptor ) )
					{
						static if( Function.HasUDA!( BindMethod ) )
						{
							alias FunctionDetails = Function.GetUDA!( BindMethod );

							string UDAs = "@NoScriptVisibility @BindRawImport( \"" ~ TypeString!( ThisType, false ).CDecl ~ "::" ~ Function.Name ~ "\", \"" ~ FunctionString!( Function ).CSignature ~ "\", BindRawImport.FunctionKind.Method, " ~ to!string( FunctionDetails.iIntroducedVersion ) ~ ", " ~ to!string( FunctionDetails.iMaxVersion ) ~ " )";
							string identifier = "function" ~ to!string( iIndex++ );

							pointers ~= UDAs ~ "\nRawMemberFunctionPointer!( FunctionDescriptor!(" ~ fullyQualifiedName!( Function.ObjectType ) ~ ", \"" ~ Function.Name ~ "\", " ~ to!string( Function.OverloadIndex ) ~ " )" ~ ", " ~ ThisType.stringof ~ " ) " ~ identifier ~ ";";
						}
					}
				}
			}

			if( pointers.length > 0 )
			{
				return modules.joinWith( "\n" ) ~ "\n" ~ pointers.joinWith( "\n\n" ) ~ "\n";
			}
			else
			{
				return "";
			}
		}

		static string generateAccessorsString()
		{
			alias Types = TypeTuple!( BaseTypes!( ThisType ), ThisType );

			import std.algorithm;
			import std.conv;
			import binderoo.traits;
			import binderoo.functiondescriptor;

			string[] functionCalls;

			int iIndex = 0;
			foreach( CurrType; Types )
			{
				static if( __traits( compiles, CurrType.MethodDescriptor ) && !is( CurrType.MethodDescriptor == void ) )
				{
					foreach( Function; FunctionDescriptors!( CurrType.MethodDescriptor ) )
					{
						static if( Function.HasUDA!( BindMethod ) )
						{
							static if( !Function.HasUDA!( BindDisallow ) )
							{
								string[] parameterNames;
								parameterNames ~= "thisObj";
								static if( FunctionString!( Function ).ParameterNames.length > 0 )
								{
									parameterNames ~= FunctionString!( Function ).ParameterNames;
								}
								functionCalls ~= "pragma( inline ) " ~ FunctionString!( Function ).DDeclNoLinkage ~ " { auto thisObj = &this; return __methodtableData.function" ~ to!string( iIndex ) ~ "( " ~ parameterNames.joinWith( ", " ) ~ " ); }";

								static if( Function.HasUDA!( BindGetter ) )
								{
									static assert( Function.ParameterCount == 0, "Getter function " ~ Function.Name ~ " has parameters! It cannot be marked as a getter property." );
									static assert( Function.HasReturnType, "Getter function " ~ Function.Name ~ " does not return anything!" );

									enum PropertyName = Function.GetUDA!( BindGetter ).strPropertyName;

									functionCalls ~= "pragma( inline ) @property " ~ PropertyName ~ "() { auto thisObj = &this; return __methodtableData.function" ~ to!string( iIndex ) ~ "( thisObj ); }";
								}

								static if( Function.HasUDA!( BindSetter ) )
								{
									static assert( Function.ParameterCount == 1, "Setter function " ~ Function.Name ~ " has extra parameters! It cannot be marked as a getter property." );

									enum PropertyName = Function.GetUDA!( BindSetter ).strPropertyName;

									functionCalls ~= "pragma( inline ) @property " ~ PropertyName ~ "( " ~ Function.Parameter!( 0 ).Type.stringof ~ " val ) { auto thisObj = &this; __methodtableData.function" ~ to!string( iIndex ) ~ "( thisObj, val ); return val; }";
								}
							}
							++iIndex;
						}
					}
				}
			}

			return functionCalls.joinWith( "\n" );
		}

		mixin( generateTypeMixin() );

		version( InheritanceMTableDebug ) pragma( msg, ThisType.stringof ~ " method table:\n" ~ generateTypeMixin() );
	}

	__gshared VTable		__vtableData;
	__gshared MethodTable	__methodtableData;

	/+version( InheritanceVTableDebug )+/ pragma( msg, VTable.generateAccessorsString() );
	mixin( VTable.generateAccessorsString() );

	/+version( InheritanceMTableDebug )+/ pragma( msg, MethodTable.generateAccessorsString() );
	mixin( MethodTable.generateAccessorsString() );
}
//----------------------------------------------------------------------------

mixin template CPPStructInherits( T, NewMethods = void )
{
	version( InheritanceInspectionDebug ) pragma( msg, "Inheritance: Struct " ~ typeof( this ).stringof );
	version( InheritanceInspectionDebug ) pragma( msg, GenerateBaseAccessors!( T ) );

	static if( __traits( hasMember, T, "__vtableData" ) )
	{
		//pragma( msg, typeof(this).stringof ~ " will call base constructor " ~ T.stringof ~ " with a vtable" );
		@InheritanceBase T			base = T( &__vtableData );
	}
	else
	{
		// TODO: Nicer method of non-virtual bases
		@InheritanceBase T			base;
	}

	alias base						this;
	alias MethodDescriptor			= NewMethods;
	//------------------------------------------------------------------------

	mixin( GenerateBaseAccessors!( T ) );

	mixin GenerateImports!( typeof( this ) );

	import binderoo.traits : HasUDA, GetUDA;
	this( VTableType )( VTableType* newVTable ) if( HasUDA!( VTableType, InheritanceGeneratedVTable ) )
	{
		base = T( newVTable );
	}
	//------------------------------------------------------------------------
}
//----------------------------------------------------------------------------

mixin template CPPStructVirtualBase( NewMethods = void, AlsoInherits = void )
{
	static if( !is( AlsoInherits == void ) )
	{
		mixin CPPStructInherits!( AlsoInherits, NewVirtuals, NewMethods );
	}
	else
	{
		alias MethodDescriptor		= NewMethods;

		mixin GenerateImports!( typeof( this ) );
	}

	// This is meant to be a void** to be 100% correct. But the compiler won't let me.
	void*						__vtable = &__vtableData;

	import binderoo.traits : HasUDA, GetUDA;
	this( VTableType )( VTableType* newVTable ) if( HasUDA!( VTableType, InheritanceGeneratedVTable ) )
	{
		__vtable = newVTable;
	}
}
//----------------------------------------------------------------------------

template HasInheritedAnywhere( Type, BaseType ) if( is( Type == struct ) )
{
	static if( is( Type == BaseType ) )
	{
		enum HasInheritedAnywhere = true;
	}
	else static if( __traits( compiles, typeof( Type.base ) ) && HasUDA!( Type.base, InheritanceBase ) )
	{
		alias NextType = typeof( Type.base );
		enum HasInheritedAnywhere = HasInheritedAnywhere!( NextType, BaseType );
	}
	else
	{
		enum HasInheritedAnywhere = false;
	}
}
//----------------------------------------------------------------------------

template HasInheritedAnywhere( Type, BaseType ) if( !is( Type == struct ) )
{
	enum HasInheritedAnywhere = false;
}
//----------------------------------------------------------------------------

template HasInheritedDirectly( Type, BaseType ) if( is( Type == struct ) )
{
	enum HasInheritedDirectly = __traits( compiles, typeof( T.base ) )
								&& HasUDA!( T.base, InheritanceBase )
								&& is( typeof( T.base ) == BaseType );
}
//----------------------------------------------------------------------------

//============================================================================
