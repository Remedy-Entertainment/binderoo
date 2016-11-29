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
//	version = InheritanceInterfaceInspection;
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

enum InheritanceStructType
{
	CPP,
	D,
}
//----------------------------------------------------------------------------

template BaseTypes( Type )
{
	static if( is( Type == void ) )
	{
		alias BaseTypes = TypeTuple!();
	}
	else static if( __traits( compiles, typeof( Type.base ) ) && HasUDA!( Type.base, InheritanceBase ) )
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

	enum GenerateBaseAccessors = "\tprivate pragma( inline ) final @property " ~ Type.stringof ~ "() { return " ~ generateMassiveBaseString( iDepth ) ~ "; }\n" ~ BaseString;
}
//----------------------------------------------------------------------------

string GenerateImports( ThisType, BaseType )()
{
	@InheritanceGeneratedVTable
	@BindNoExportObject
	struct VTable
	{
		public import std.typetuple;
		public import binderoo.binding.functionstub;
		public import binderoo.objectprivacy;

		static string DOverridesEnumGen()
		{
			static if( ThisType.StructType == InheritanceStructType.D )
			{
				string[] strNewOverrides;

				foreach( Function; FunctionDescriptors!( ThisType ) )
				{
					static if( Function.HasUDA!( BindVirtual ) )
					{
						enum OldFunctionDecl = "extern( C++ ) " ~ FunctionString!( Function ).DDeclNoLinkage;
						strNewOverrides ~= "{ \"" ~ OldFunctionDecl ~ "\", \"CPPLinkage_" ~ Function.Name ~ "\" }";
					}
				}

				return "\t\tenum DOverride[] DOverrides = [ " ~ strNewOverrides.joinWith( ", " ) ~ " ];\n\n";
			}
			else
			{
				return "\t\tenum DOverride[] DOverrides = [];\n\n";
			}
		}

		mixin( DOverridesEnumGen() );

		static if( is( BaseType == void ) )
		{
			alias Types = TypeTuple!( ThisType );
		}
		else
		{
			alias Types = TypeTuple!( BaseTypes!( BaseType ), BaseType, ThisType );
		}

		static private string generateTypeMixin()
		{
			import std.algorithm;
			import std.conv;
			import binderoo.traits;
			import binderoo.functiondescriptor;

			enum ThisModule = "\t\tpublic import " ~ moduleName!( ThisType ) ~ ";";

			string[] modules;
			string[] pointers;
			string[] identifiers;

			enum OwnerIsAbstract = HasUDA!( ThisType, BindAbstract ) ? "true" : "false";

			int iIndex = 0;
			foreach( CurrType; Types )
			{
				static if( __traits( compiles, CurrType.MethodDescriptor ) && !is( CurrType.MethodDescriptor == void ) )
				{
					enum CurrTypeModule = "\t\tpublic import " ~ moduleName!( CurrType ) ~ ";";

					if( CurrTypeModule != ThisModule && !modules.canFind( CurrTypeModule ) )
					{
						modules ~= CurrTypeModule;
					}

					foreach( Function; FunctionDescriptors!( CurrType.MethodDescriptor ) )
					{
						static if( Function.HasUDA!( BindVirtual ) )
						{
							alias FunctionDetails = Function.GetUDA!( BindVirtual );
						}
						else static if( Function.HasUDA!( BindVirtualDestructor ) )
						{
							alias FunctionDetails = Function.GetUDA!( BindVirtualDestructor );
						}
						else
						{
							alias FunctionDetails = void;
						}
						
						static if( !is( FunctionDetails == void ) )
						{
							enum OverrideFound = DOverrides.find!( ( a, b ) => a.strFunctionSignature == b )( FunctionString!( Function ).DDecl );

							string strIsConst = Function.IsConst ? "true" : "false";

							string orderInTable = to!string( iIndex++ );
							string identifier = "function" ~ orderInTable;

							identifiers ~= identifier;

							static if( OverrideFound.length == 0 )
							{
								string UDAs = "\t\t@NoScriptVisibility @BindRawImport( \"" ~ TypeString!( ThisType, false ).CDecl ~ "::" ~ Function.Name ~ "\", \"" ~ FunctionString!( Function ).CSignature ~ "\", BindRawImport.FunctionKind.Virtual, " ~ orderInTable ~ ", " ~ strIsConst ~ ", " ~ OwnerIsAbstract ~ ", " ~ to!string( FunctionDetails.iIntroducedVersion ) ~ ", " ~ to!string( FunctionDetails.iMaxVersion ) ~ " )";
								pointers ~= UDAs ~ "\n\t\tRawMemberFunctionPointer!( FunctionDescriptor!(" ~ fullyQualifiedName!( Function.ObjectType ) ~ ", \"" ~ Function.Name ~ "\", " ~ to!string( Function.OverloadIndex ) ~ " )" ~ ", " ~ ThisType.stringof ~ " ) " ~ identifier ~ ";";
							}
							else
							{
								pointers ~= "\t\t@NoScriptVisibility\n\t\tRawMemberFunctionPointer!( FunctionDescriptor!(" ~ fullyQualifiedName!( Function.ObjectType ) ~ ", \"" ~ Function.Name ~ "\", " ~ to!string( Function.OverloadIndex ) ~ " )" ~ ", " ~ ThisType.stringof ~ " ) " ~ identifier ~ " = &" ~ TypeString!( ThisType, false ).DDecl ~ "." ~ OverrideFound[ 0 ].strFunctionCDeclCallName ~ ";";
							}
						}
					}
				}
			}

			string result;
			if( pointers.length > 0 )
			{
				if( modules.length > 0 )
				{
					result ~= modules.joinWith( "\n" ) ~ "\n\n";
				}
				result ~= pointers.joinWith( "\n\n" ) ~ "\n\n";
			}

			result ~= "\t\tenum FunctionCount = " ~ to!string( identifiers.length ) ~ ";\n\n"
					~ "\t\tfinal void** getPointer() { return cast(void**)&this; }\n\n";

			return result;
		}

		static string generateCompleteRepresentation()
		{
			return "\t@InheritanceGeneratedVTable\n"
					~ "\t@BindNoExportObject\n"
					~ "\tstruct VTable\n"
					~ "\t{\n"
					//~ DOverridesEnumGen()
					~ generateTypeMixin()
					~ "\t}\n";
		}

		static string generateAccessorsString()
		{
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
						enum HasVirtual = Function.HasUDA!( BindVirtual );
						enum HasVirtualDestructor = Function.HasUDA!( BindVirtualDestructor );

						static if( HasVirtual || HasVirtualDestructor )
						{
							static if( !Function.HasUDA!( BindDisallow ) && DOverrides.find!( ( a, b ) => a.strFunctionSignature == b )( FunctionString!( Function ).DDecl ).length == 0 )
							{

								string[] parameterNames = [ "thisObj" ];

								static if( FunctionString!( Function ).ParameterNames.length > 0 )
								{
									parameterNames ~= FunctionString!( Function ).ParameterNames;
								}

								string pointerName = "function" ~ to!string( iIndex );
								static if( HasVirtual )
								{
									functionCalls ~= "\t@InheritanceVirtualCall pragma( inline ) " ~ FunctionString!( Function ).DDeclNoLinkage ~ "\n\t{ " ~ ThisType.stringof ~ "* thisObj = cast(" ~ ThisType.stringof ~ "*)&this; return __vtableData." ~ pointerName ~ "( " ~ parameterNames.joinWith( ", " ) ~ " ); }\n";
								}
								else static if( HasVirtualDestructor )
								{
									functionCalls ~= "\t@InheritanceVirtualCall pragma( inline ) void cppDestructor( uint iDestructorValue )\n\t{ " ~ ThisType.stringof ~ "* thisObj = cast(" ~ ThisType.stringof ~ "*)&this; return __vtableData." ~ pointerName ~ "( thisObj, iDestructorValue ); }\n";
								}
							}
							++iIndex;
						}
					}
				}
			}

			return functionCalls.joinWith( "\n" );
		}

		version( InheritanceVTableDebug ) pragma( msg, ThisType.stringof ~ " vtable:\n" ~ generateTypeMixin() );
	}
	//------------------------------------------------------------------------

	@BindNoExportObject
	struct MethodTable
	{
		public import std.typetuple;
		public import binderoo.binding.functionstub;
		public import binderoo.objectprivacy;

		static if( is( BaseType == void ) )
		{
			alias Types = TypeTuple!( ThisType );
		}
		else
		{
			alias Types = TypeTuple!( BaseTypes!( BaseType ), BaseType, ThisType );
		}

		static private string generateTypeMixin()
		{
			import std.algorithm;
			import std.conv;
			import binderoo.traits;
			import binderoo.functiondescriptor;

			enum ThisModule = "\t\tpublic import " ~ moduleName!( ThisType ) ~ ";";

			string[] modules;
			string[] pointers;

			enum OwnerIsAbstract = HasUDA!( ThisType, BindAbstract ) ? "true" : "false";

			int iIndex = 0;
			foreach( CurrType; Types )
			{
				static if( __traits( compiles, CurrType.MethodDescriptor ) && !is( CurrType.MethodDescriptor == void ) )
				{
					enum CurrTypeModule = "\t\tpublic import " ~ moduleName!( CurrType ) ~ ";";

					if( CurrTypeModule != ThisModule && !modules.canFind( CurrTypeModule ) )
					{
						modules ~= CurrTypeModule;
					}

					foreach( Function; FunctionDescriptors!( CurrType.MethodDescriptor ) )
					{
						static if( Function.HasUDA!( BindMethod ) )
						{
							alias FunctionDetails = Function.GetUDA!( BindMethod );

							enum IsConst = Function.IsConst ? "true" : "false";
							enum FunctionKind = Function.IsStatic ? "BindRawImport.FunctionKind.Static" : "BindRawImport.FunctionKind.Method";

							string orderInTable = to!string( iIndex++ );
							string identifier = "function" ~ orderInTable;

							string UDAs = "\t\t@NoScriptVisibility @BindRawImport( \"" ~ TypeString!( ThisType, false ).CDecl ~ "::" ~ Function.Name ~ "\", \"" ~ FunctionString!( Function ).CSignature ~ "\", " ~ FunctionKind ~ ", " ~ orderInTable ~ ", " ~ IsConst ~ ", " ~ OwnerIsAbstract ~ ", "  ~ to!string( FunctionDetails.iIntroducedVersion ) ~ ", " ~ to!string( FunctionDetails.iMaxVersion ) ~ " )";
							pointers ~= UDAs ~ "\n\t\tRawMemberFunctionPointer!( FunctionDescriptor!(" ~ fullyQualifiedName!( Function.ObjectType ) ~ ", \"" ~ Function.Name ~ "\", " ~ to!string( Function.OverloadIndex ) ~ " )" ~ ", " ~ ThisType.stringof ~ " ) " ~ identifier ~ ";";
						}
						else static if( Function.HasUDA!( BindConstructor ) )
						{
							alias FunctionDetails = Function.GetUDA!( BindConstructor );
							enum FunctionKind = "BindRawImport.FunctionKind.Constructor";

							string orderInTable = to!string( iIndex++ );
							string identifier = "function" ~ orderInTable;

							string UDAs = "\t\t@NoScriptVisibility @BindRawImport( \"" ~ TypeString!( ThisType, false ).CDecl ~ "::" ~ TypeString!( ThisType, false ).UnqualifiedCDecl ~ "\", \"" ~ FunctionString!( Function ).CSignature ~ "\", " ~ FunctionKind ~ ", " ~ orderInTable ~ ", false, " ~ OwnerIsAbstract ~ ", "  ~ to!string( FunctionDetails.iIntroducedVersion ) ~ ", " ~ to!string( FunctionDetails.iMaxVersion ) ~ " )";
							pointers ~= UDAs ~ "\n\t\tRawMemberFunctionPointer!( FunctionDescriptor!(" ~ fullyQualifiedName!( Function.ObjectType ) ~ ", \"" ~ Function.Name ~ "\", " ~ to!string( Function.OverloadIndex ) ~ " )" ~ ", " ~ ThisType.stringof ~ " ) " ~ identifier ~ ";";
						}
					}
				}
			}

			if( pointers.length > 0 )
			{
				if( modules.length > 0 )
				{
					return modules.joinWith( "\n" ) ~ "\n\n" ~ pointers.joinWith( "\n\n" ) ~ "\n\n";
				}
				return pointers.joinWith( "\n\n" ) ~ "\n\n";
			}
			else
			{
				return "";
			}
		}

		static string generateCompleteRepresentation()
		{
			return "\t@BindNoExportObject\n"
					~ "\tstruct MethodTable\n"
					~ "\t{\n"
					~ generateTypeMixin()
					~ "\t}\n";
		}

		static string generateAccessorsString()
		{
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
						enum HasBindMethod = Function.HasUDA!( BindMethod );
						enum HasBindConstructor = Function.HasUDA!( BindConstructor );
						static if( HasBindMethod || HasBindConstructor )
						{
							static if( !Function.HasUDA!( BindDisallow ) )
							{
								string[] parameterNames;
								
								static if( !Function.IsStatic )
								{
									parameterNames ~= "thisObj";
								}
								static if( FunctionString!( Function ).ParameterNames.length > 0 )
								{
									parameterNames ~= FunctionString!( Function ).ParameterNames;
								}

								static if( Function.IsStatic )
								{
									functionCalls ~= "\t@InheritanceMethodCall pragma( inline ) " ~ FunctionString!( Function ).DDeclNoLinkage ~ "\n\t{ return __methodtableData.function" ~ to!string( iIndex ) ~ "( " ~ parameterNames.joinWith( ", " ) ~ " ); }\n";
								}
								else
								{
									static if( HasBindMethod )
									{
										functionCalls ~= "\t@InheritanceMethodCall pragma( inline ) " ~ FunctionString!( Function ).DDeclNoLinkage ~ "\n\t{ " ~ ThisType.stringof ~ "* thisObj = cast(" ~ ThisType.stringof ~ "*)&this; return __methodtableData.function" ~ to!string( iIndex ) ~ "( " ~ parameterNames.joinWith( ", " ) ~ " ); }\n";
									}
									else static if( HasBindConstructor )
									{
										functionCalls ~= "\t@InheritanceMethodCall pragma( inline ) void cppConstructor( " ~ FunctionString!( Function ).ParameterDeclarations ~ ")\n\t{ " ~ ThisType.stringof ~ "* thisObj = cast(" ~ ThisType.stringof ~ "*)&this; return __methodtableData.function" ~ to!string( iIndex ) ~ "( " ~ parameterNames.joinWith( ", " ) ~ " ); }\n";
									}

									static if( HasBindMethod && Function.HasUDA!( BindGetter ) )
									{
										static assert( Function.ParameterCount == 0, "Getter function " ~ Function.Name ~ " has parameters! It cannot be marked as a getter property." );
										static assert( Function.HasReturnType, "Getter function " ~ Function.Name ~ " does not return anything!" );

										enum PropertyName = Function.GetUDA!( BindGetter ).strPropertyName;

										functionCalls ~= "\t@InheritanceMethodCall pragma( inline ) @property " ~ PropertyName ~ "()\n\t{ auto thisObj = &this; return __methodtableData.function" ~ to!string( iIndex ) ~ "( thisObj ); }\n";
									}

									static if( HasBindMethod && Function.HasUDA!( BindSetter ) )
									{
										static assert( Function.ParameterCount == 1, "Setter function " ~ Function.Name ~ " has extra parameters! It cannot be marked as a getter property." );

										enum PropertyName = Function.GetUDA!( BindSetter ).strPropertyName;

										functionCalls ~= "\t@InheritanceMethodCall pragma( inline ) @property " ~ PropertyName ~ "( " ~ Function.Parameter!( 0 ).Type.stringof ~ " val )\n\t{ auto thisObj = &this; __methodtableData.function" ~ to!string( iIndex ) ~ "( thisObj, val ); return val; }\n";
									}
								}
							}
							++iIndex;
						}
					}
				}
			}

			return functionCalls.joinWith( "\n" );
		}

		version( InheritanceMTableDebug ) pragma( msg, ThisType.stringof ~ " method table:\n" ~ generateTypeMixin() );
	}

/+	__gshared VTable		__vtableData;
	__gshared MethodTable	__methodtableData;

	version( InheritanceVTableDebug ) pragma( msg, ThisType.stringof ~ " accessors:\n" ~ VTable.generateAccessorsString() ~ "\n" );
	mixin( VTable.generateAccessorsString() );

	version( InheritanceMTableDebug ) pragma( msg, MethodTable.generateAccessorsString() );
	mixin( MethodTable.generateAccessorsString() );+/

	return VTable.generateCompleteRepresentation()
			~ "\n"
			~ MethodTable.generateCompleteRepresentation()
			~ "\n"
			~ "\t__gshared VTable		__vtableData;\n"
			~ "\t__gshared MethodTable	__methodtableData;\n"
			~ "\n"
			~ VTable.generateAccessorsString()
			~ "\n"
			~ MethodTable.generateAccessorsString()
			~ "\n";
}
//----------------------------------------------------------------------------

struct DOverride
{
	string strFunctionSignature;
	string strFunctionCDeclCallName;
}
//----------------------------------------------------------------------------

string DStructOverrideSetup( T )()
{
	string[] strNewStubs;

	foreach( Function; FunctionDescriptors!( T ) )
	{
		static if( Function.HasUDA!( BindVirtual ) )
		{
			enum OldFunctionDecl = "extern( C++ ) " ~ FunctionString!( Function ).DDeclNoLinkage;
			static if( Function.ParameterCount == 0 )
			{
				enum NewFunctionDecl = "static extern( C++ ) " ~ TypeString!( Function.ReturnType ).DDecl ~ " CPPLinkage_" ~ Function.Name ~ "( " ~ T.stringof ~ "* thisObj )";
			}
			else
			{
				enum NewFunctionDecl = "static extern( C++ ) " ~ TypeString!( Function.ReturnType ).DDecl ~ " CPPLinkage_" ~ Function.Name ~ "( " ~ T.stringof ~ "* thisObj, " ~ FunctionString!( Function ).ParameterDeclarations ~ " )";
			}

			static if( Function.HasReturnType )
			{
				enum NewFunctionStub = "\t@BindOverrides( \"" ~ OldFunctionDecl ~ "\" )\n"
										~ "\t" ~ NewFunctionDecl ~ "\n"
										~ "\t{\n"
										~ "\t\treturn thisObj." ~ Function.Name ~ "( " ~ FunctionString!( Function ).ParameterNames ~ " );\n"
										~ "\t}\n";

			}
			else
			{
				enum NewFunctionStub = "\t@BindOverrides( \"" ~ OldFunctionDecl ~ "\" )\n"
										~ "\t" ~ NewFunctionDecl ~ "\n"
										~ "\t{\n"
										~ "\t\tthisObj." ~ Function.Name ~ "( " ~ FunctionString!( Function ).ParameterNames ~ " );\n"
										~ "\t}\n";
			}
			strNewStubs ~= NewFunctionStub;
		}
	}

	return strNewStubs.joinWith( "\n" );
}
//----------------------------------------------------------------------------

string GenerateInterfaceRepresentation( T, Base, InheritanceStructType structType )()
{
	import binderoo.variabledescriptor;
	import binderoo.functiondescriptor;

	string typeGen()
	{
		string[] outputs;

		foreach( UDA; TypeDescriptor!( T ).UDAs )
		{
			outputs ~= "@" ~ UDA.stringof;
		}

		static if( is( T == struct ) )
		{
			outputs ~= "struct " ~ T.stringof;
		}
		else if( is( T == class ) )
		{
			outputs ~= "class " ~ T.stringof;
		}

		return outputs.joinWith( "\n" );
	}

	string variableGen()
	{
		string[] outputs;
		foreach( Variable; VariableDescriptors!( T ) )
		{
			string[] varDecl;

			foreach( UDA; Variable.UDAs )
			{
				varDecl ~= "@" ~ UDA.stringof;
			}

			varDecl ~= Variable.Type.Name;
			varDecl ~= Variable.Name;

			outputs ~= "\t" ~ varDecl.joinWith( " " ) ~ ";";
		}

		return outputs.joinWith( "\n" ) ~ "\n";
	}

	string functionGen()
	{
		string[] outputs;
		foreach( Function; FunctionDescriptors!( T ) )
		{
			static if( !Function.HasUDA!( InheritanceVirtualCall ) && !Function.HasUDA!( InheritanceMethodCall ) )
			{
				string[] funcDecl;

				foreach( UDA; Function.UDAs )
				{
					funcDecl ~= "@" ~ UDA.stringof;
				}

				funcDecl ~= FunctionString!( Function ).DDecl ~ ";";

				outputs ~= "\t" ~ funcDecl.joinWith( " " );
			}
		}

		return outputs.joinWith( "\n" ) ~ "\n";
	}

	static if( !is( Base == void ) )
	{
		enum BaseAccessors = GenerateBaseAccessors!( Base ) ~ "\n";
	}
	else
	{
		enum BaseAccessors = "";
	}

	static if( structType == InheritanceStructType.D )
	{
		enum CPPOverrides = DStructOverrideSetup!( T )() ~ "\n";
	}
	else
	{
		enum CPPOverrides = "";
	}

	enum OutputObject = typeGen() ~ "\n"
						~ "{\n"
						~ "\tenum StructType = " ~ structType.stringof ~ ";\n\n"
						~ GenerateImports!( T, Base )
						~ "\n"
						~ functionGen()
						~ "\n"
						~ variableGen()
						~ "\n"
						~ BaseAccessors
						~ CPPOverrides
						~ "}\n";

	return OutputObject;
}
//----------------------------------------------------------------------------

mixin template DStructInherits( T )
{
	enum StructType					= InheritanceStructType.D;

	version( InheritanceInspectionDebug ) pragma( msg, "D Inheritance: Struct " ~ typeof( this ).stringof );
	version( InheritanceInspectionDebug ) pragma( msg, typeof( this ).stringof ~ " base accessors:\n" ~ GenerateBaseAccessors!( T ) );

	mixin( DStructOverrideSetup!( typeof( this ) )() );
	mixin( GenerateBaseAccessors!( T ) );
	mixin( GenerateImports!( typeof( this ), T )() );

	static if( T.VTable.FunctionCount > 0 )
	{
		//pragma( msg, typeof(this).stringof ~ " will call base constructor " ~ T.stringof ~ " with a vtable" );
		@InheritanceBase T			base = T( &__vtableData );
	}
	else
	{
		static if( VTable.FunctionCount > 0 )
		{
			// This is meant to be a void** to be 100% correct. But the compiler won't let me.
			@BindNoSerialise void*	__vtable = &__vtableData;
		}
		// TODO: Nicer method of non-virtual bases
		@InheritanceBase T			base;
	}

	alias base						this;

/+	static auto opCall()
	{
		typeof( this ) newObj;
		return newObj;
	}+/

	version( InheritanceInterfaceInspection ) pragma( msg, GenerateInterfaceRepresentation!( typeof( this ), T, StructType )() );
}
//----------------------------------------------------------------------------

mixin template CPPStructInherits( T, NewMethods = void )
{
	static assert( HasUDA!( typeof( this ), CTypeName ), typeof( this ).stringof ~ " is a C++ object but does not have a @CTypeName attribute defined." );
	static assert( HasUDA!( T, CTypeName ), typeof( this ).stringof ~ " is a C++ object but " ~ T.stringof ~ " does not have a @CTypeName attribute defined." );

	enum StructType					= InheritanceStructType.CPP;

	version( InheritanceInspectionDebug ) pragma( msg, "C++ Inheritance: Struct " ~ typeof( this ).stringof );
	version( InheritanceInspectionDebug ) pragma( msg, typeof( this ).stringof ~ " base accessors:\n" ~ GenerateBaseAccessors!( T ) );
	version( InheritanceInspectionDebug ) pragma( msg, GenerateImports!( typeof( this ), T )() );

	mixin( GenerateBaseAccessors!( T ) );
	mixin( GenerateImports!( typeof( this ), T )() );

	static if( T.VTable.FunctionCount > 0 )
	{
		//pragma( msg, typeof(this).stringof ~ " will call base constructor " ~ T.stringof ~ " with a vtable" );
		@InheritanceBase T			base = T( &__vtableData );
	}
	else
	{
		static if( VTable.FunctionCount > 0 )
		{
			// This is meant to be a void** to be 100% correct. But the compiler won't let me.
			@BindNoSerialise void*	__vtable = &__vtableData;
		}
		// TODO: Nicer method of non-virtual bases
		@InheritanceBase T			base;
	}

	alias base						this;
	alias MethodDescriptor			= NewMethods;
	//------------------------------------------------------------------------

	static if( VTable.FunctionCount > 0 )
	{
		import binderoo.traits : HasUDA, GetUDA;
		static auto opCall( VTableType )( VTableType* newVTable ) if( HasUDA!( VTableType, InheritanceGeneratedVTable ) )
		{
			typeof( this ) newObj;
			static if( T.VTable.FunctionCount > 0 )
			{
				newObj.base = T( newVTable );
			}
			else
			{
				newObj.__vtable = newVTable;
			}

			return newObj;
		}
	}
	//------------------------------------------------------------------------

	static auto opCall()
	{
		typeof( this ) newObj;
		return newObj;
	}

	version( InheritanceInterfaceInspection ) pragma( msg, GenerateInterfaceRepresentation!( typeof( this ), T, StructType )() );
}
//----------------------------------------------------------------------------

mixin template CPPStructBase( NewMethods = void )
{
	static assert( HasUDA!( typeof( this ), CTypeName ), typeof( this ).stringof ~ " is a C++ object but does not have a @CTypeName attribute defined." );

	version( InheritanceInspectionDebug ) pragma( msg, "C++ Inheritance: Struct " ~ typeof( this ).stringof );
	version( InheritanceInspectionDebug ) pragma( msg, GenerateImports!( typeof( this ), void )() );

	enum StructType				= InheritanceStructType.CPP;

	alias MethodDescriptor		= NewMethods;

	mixin( GenerateImports!( typeof( this ), void )() );

	static if( VTable.FunctionCount > 0 )
	{
		// This is meant to be a void** to be 100% correct. But the compiler won't let me.
		@BindNoSerialise void*		__vtable = &__vtableData;

		import binderoo.traits : HasUDA, GetUDA;
		static auto opCall( VTableType )( VTableType* newVTable ) if( HasUDA!( VTableType, InheritanceGeneratedVTable ) )
		{
			typeof( this ) newObj;
			newObj.__vtable = newVTable;
			return newObj;
		}
	}

	static auto opCall()
	{
		typeof( this ) newObj;
		return newObj;
	}

	// NOTE: DESTRUCTION IS ONLY DONE IN BOUND OBJECT CREATION AND DESTRUCTION CURRENTLY

	version( InheritanceInterfaceInspection ) pragma( msg, GenerateInterfaceRepresentation!( typeof( this ), void, StructType )() );
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

void constructObject( Type )( ref Type obj )
{
	obj = Type();
	static if( __traits( hasMember, Type, "cppConstructor" ) )
	{
		obj.cppConstructor();
	}

	static if( __traits( hasMember, Type, "OnConstruct" ) )
	{
		obj.OnConstruct();
	}
}
//----------------------------------------------------------------------------

void destructObject( Type )( ref Type obj )
{
	static if( __traits( hasMember, Type, "OnDestruct" ) )
	{
		obj.OnDestruct();
	}

	static if( __traits( hasMember, Type, "cppDestructor" ) )
	{
		obj.cppDestructor( 0 );
	}

	destroy( obj );
}
//----------------------------------------------------------------------------

//============================================================================
