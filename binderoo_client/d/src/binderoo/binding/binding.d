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

module binderoo.binding.binding;
//----------------------------------------------------------------------------

public import binderoo.binding.attributes;
public import binderoo.binding.functionstub;
public import binderoo.binding.boundfunction;
public import binderoo.binding.boundobject;

public import binderoo.functiondescriptor;
public import binderoo.variabledescriptor;
public import binderoo.hash;
public import binderoo.objectprivacy;
public import binderoo.slice;

private import std.traits;
//----------------------------------------------------------------------------

mixin template BindVersionDeclaration( int iCurrentVersion )
{
	enum			BoundVersion		= iCurrentVersion;
	__gshared int	ImportedVersion		= -1;
}
//----------------------------------------------------------------------------

mixin template BindModule( int iCurrentVersion = 0, AdditionalStaticThisCalls... )
{
	shared static this()
	{
		initialiseModuleBinding();

		foreach( newCall; AdditionalStaticThisCalls )
		{
			newCall();
		}
	}
	//------------------------------------------------------------------------

	private:

	static void initialiseModuleBinding()
	{
		functionsToImport = generateImports();
		functionsToExport = generateExports();
		objectsToExport = generateObjects();

		registerImportFunctions( functionsToImport );
		registerExportedFunctions( functionsToExport );
		registerExportedObjects( objectsToExport );
	}
	//------------------------------------------------------------------------

	__gshared align( 64 ) BoundObject[]							objectsToExport;
	__gshared align( 16 ) BoundFunction[]						functionsToImport;
	__gshared align( 16 ) BoundFunction[]						functionsToExport;
	//------------------------------------------------------------------------

	template ModuleTypeDescriptors( ParentClass, Aliases... )
	{
		import std.typetuple;

		string makeATuple()
		{
			import std.conv : to;
			import binderoo.traits : IsUserType, joinWith;

			string[] indices;
			foreach( Alias; Aliases )
			{
				static if( !is( ParentClass == void ) )
				{
					enum AliasString = fullyQualifiedName!( ParentClass ) ~ "." ~ Alias;
				}
				else
				{
					enum AliasString = Alias;
				}

				static if( mixin( "IsSomeType!( " ~ AliasString ~ " )" ) )
				{
					mixin( "alias Type = " ~ AliasString ~ ";" );
					mixin( "import " ~ moduleName!( Type ) ~ ";" );

					static if( IsUserTypeButNotEnum!( Type ) && Alias == Type.stringof )
					{
						indices ~= AliasString;
					}
				}
			}

			return "alias ModuleTypeDescriptors = TypeTuple!( " ~ indices.joinWith( ", " ) ~ " );";
		}

		mixin( makeATuple() );
	}
	//------------------------------------------------------------------------

	static BoundObject[] generateObjects()
	{
		BoundObject[] gatherFor( Types... )()
		{
			BoundObject[] objects;
			foreach( Type; Types )
			{
				static if( is( Type == struct ) || is( Type == class ) )
				{
					objects ~= BoundObject( DString( fullyQualifiedName!( Type ) ),
											fnv1a_64( fullyQualifiedName!( Type ) ),
											&BoundObjectFunctions!( Type ).allocObj,
											&BoundObjectFunctions!( Type ).deallocObj,
											&BoundObjectFunctions!( Type ).thunkObj,
											BoundObjectFunctions!( Type ).TypeVal );
				}

				alias AllSubTypes = ModuleTypeDescriptors!( Type, __traits( allMembers, Type ) );

				objects ~= gatherFor!( AllSubTypes )();
			}

			return objects;
		}

		mixin( "import " ~ moduleName!( functionsToImport ) ~ ";" );
		alias ModuleTypes = ModuleTypeDescriptors!( void, __traits( allMembers, mixin( moduleName!( functionsToImport ) ) ) );
		return gatherFor!( ModuleTypes )();
	}
	//------------------------------------------------------------------------

	static BoundFunction[] generateImports()
	{
		BoundFunction.FunctionKind convert( BindRawImport.FunctionKind eKind )
		{
			final switch( eKind ) with( BindRawImport.FunctionKind )
			{
			case Static:
				return BoundFunction.FunctionKind.Static;
			case Method:
				return BoundFunction.FunctionKind.Method;
			case Virtual:
				return BoundFunction.FunctionKind.Virtual;
			}
		}

		BoundFunction[] TableGrabber( Type, string TableStaticMember )()
		{
			BoundFunction[] imports;

			static if( IsStaticMember!( Type, TableStaticMember ) )
			{
				alias TableType = typeof( __traits( getMember, Type, TableStaticMember ) );
				alias CTypeData = GetUDA!( Type, CTypeName );

				//pragma( msg, Type.stringof ~ " " ~ TableType.stringof );

				// More readable, but performs slower at compile time :-(
				/+foreach( Variable; VariableDescriptorsByUDA!( TableType, BindRawImport ) )
				{
				alias ImportData = Variable.GetUDA!( BindRawImport );
				//pragma( msg, fullyQualifiedName!( TableType ) ~ "." ~ Variable.Name ~ " is importing " ~ ImportData.strCName );

				imports ~= BoundFunction(	DString( ImportData.strCName )
				, DString( ImportData.strCSignature )
				, DString( CTypeData.name )
				, DString( CTypeData.header )
				, BoundFunction.Hashes( ImportData.uNameHash, ImportData.uSignatureHash )
				, mixin( "cast(void*) &" ~ fullyQualifiedName!( Type ) ~ "." ~ TableStaticMember ~ "." ~ Variable.Name )
				, ImportData.iIntroducedVersion
				, BoundFunction.Resolution.WaitingForImport );
				}+/

				foreach( tableMember; __traits( allMembers, TableType ) )
				{
					static if( IsAccessible!( TableType, tableMember )
							   && is( typeof( __traits( getMember, TableType, tableMember ) ) )
								   && !is( typeof( __traits( getMember, TableType, tableMember ) ) == void )
								   && IsMemberVariable!( __traits( getMember, TableType, tableMember ) )
								   && HasUDA!( __traits( getMember, TableType, tableMember ), BindRawImport ) )
					{
						alias ImportData = GetUDA!( __traits( getMember, TableType, tableMember ), BindRawImport );

						//pragma( msg, cast(string)ImportData.strCName ~ ", " ~ cast(string)ImportData.strCSignature );

/*						enum NameHash = ImportData.uNameHash;
						enum SignatureHash = ImportData.uSignatureHash;
						pragma( msg, tableMember ~ " imports " ~ ImportData.strCName ~ " ( " ~ NameHash.stringof ~ " ), " ~ ImportData.strCSignature ~ " ( " ~ SignatureHash.stringof ~ " )" );*/

						imports ~= BoundFunction(	DString( ImportData.strCName )
													, DString( ImportData.strCSignature )
													, DString( CTypeData.name )
													, DString( CTypeData.header )
													, BoundFunction.Hashes( ImportData.uNameHash, ImportData.uSignatureHash )
													, mixin( "cast(void*) &" ~ fullyQualifiedName!( Type ) ~ "." ~ TableStaticMember ~ "." ~ tableMember )
													, ImportData.iIntroducedVersion
													, BoundFunction.Resolution.WaitingForImport
													, BoundFunction.CallingConvention.CPP
													, convert( ImportData.eKind ) );
					}
				}
			}

			return imports;
		}

		BoundFunction[] gatherFor( Types... )()
		{
			BoundFunction[] imports;
			foreach( Type; Types )
			{
				alias Members = TypeTuple!( __traits( allMembers, Type ) );

				imports ~= TableGrabber!( Type, "__vtableData" )();
				imports ~= TableGrabber!( Type, "__methodtableData" )();

				imports ~= gatherFor!( ModuleTypeDescriptors!( Type, Members ) )();
			}

			return imports;
		}

		mixin( "import " ~ moduleName!( functionsToImport ) ~ ";" );

		alias Types = ModuleTypeDescriptors!( void, __traits( allMembers, mixin( moduleName!( functionsToImport ) ) ) );
		return gatherFor!( Types )();
	}

	static BoundFunction[] generateExports()
	{
		BoundFunction[] functionGrabber( Type, Symbols... )()
		{
			BoundFunction[] foundExports;

			foreach( SymbolName; Symbols )
			{
				mixin( "alias Symbol = " ~ SymbolName  ~ ";" );

				static if( isSomeFunction!( Symbol ) && HasUDA!( Symbol, BindExport ) )
				{
					alias Descriptor = FunctionDescriptor!( Symbol );
					alias ExportData = Descriptor.GetUDA!( BindExport );

					static assert( Descriptor.IsCPlusPlusFunction, fullyQualifiedName!( Symbol ) ~ " can only be exported as extern( C++ ) for now." );

					enum FullName = fullyQualifiedName!( Symbol );
					enum Signature = FunctionString!( Descriptor ).CSignature;

					//pragma( msg, "Exporting " ~ FullName ~ ": " ~ Signature );

					foundExports ~= BoundFunction( DString( FullName )
													, DString( Signature )
													, DString( "" )
													, DString( "" )
													, BoundFunction.Hashes( fnv1a_64( FullName ), fnv1a_64( Signature ) )
													, mixin( "&" ~ fullyQualifiedName!( Symbol ) )
													, ExportData.iIntroducedVersion
													, BoundFunction.Resolution.Exported
													, BoundFunction.CallingConvention.CPP
													, BoundFunction.FunctionKind.Static );
				}

			}

			return foundExports;
		}


		mixin( "import " ~ moduleName!( functionsToImport ) ~ ";" );
		return functionGrabber!( void, __traits( allMembers, mixin( moduleName!( functionsToImport ) ) ) );
	}

}
//----------------------------------------------------------------------------

// Module internals
//----------------------------------------------------------------------------
public void registerImportFunctions( BoundFunction[] imports )
{
	foreach( iCurrIndex, ref forImport; imports )
	{
		auto found = ( forImport.functionHashes in importFunctionIndices );
		assert( found is null, "Hash collision with imported function! \"" ~ cast(string)forImport.strFunctionName ~ "\" with signature \"" ~ cast(string)forImport.strFunctionSignature ~ "\" <-> \"" ~ cast(string)importFunctions[ *found ].strFunctionName ~ "\" with signature \"" ~ cast(string)importFunctions[ *found ].strFunctionSignature ~ "\"" );

		size_t uIndex = importFunctions.length;
		importFunctions ~= forImport;
		importFunctionIndices[ forImport.functionHashes ] = uIndex;
	}
}
//----------------------------------------------------------------------------

public void registerExportedFunctions( BoundFunction[] exports )
{
	exportFunctions.reserve( exportFunctions.length + exports.length );

	foreach( ref forExport; exports )
	{
		auto found = ( forExport.functionHashes in exportFunctionIndices );
		if( found !is null )
		{
			assert( found is null, "Hash collision with exported function! \"" ~ cast(string)forExport.strFunctionName ~ "\" with signature \"" ~ cast(string)forExport.strFunctionSignature ~ "\" <-> \"" ~ cast(string)exportFunctions[ *found ].strFunctionName ~ "\" with signature \"" ~ cast(string)exportFunctions[ *found ].strFunctionSignature ~ "\"" );
		}

		size_t uIndex = exportFunctions.length;
		exportFunctions ~= forExport;
		exportFunctionIndices[ forExport.functionHashes ] = uIndex;
	}
}
//----------------------------------------------------------------------------

public void registerExportedObjects( BoundObject[] exports )
{
	exportObjects.reserve( exportObjects.length + exports.length );

	foreach( ref forExport; exports )
	{
		auto found = ( forExport.uFullyQualifiedNameHash in exportObjectIndices );
		if( found !is null )
		{
			assert( found is null, "Hash collision with exported object! \"" ~ cast(string)forExport.strFullyQualifiedName ~ "\" <-> \"" ~ cast(string)exportObjects[ *found ].strFullyQualifiedName ~ "\"" );
		}

		size_t uIndex = exportObjects.length;
		exportObjects ~= forExport;
		exportObjectIndices[ forExport.uFullyQualifiedNameHash ] = uIndex;
	}
}
//----------------------------------------------------------------------------

public string[] generateCPPStyleBindingDeclaration( BoundFunction[] functions )
{
	import std.string;
	import std.algorithm;
	import std.conv;

	string[] splitSignature( string signature )
	{
		auto result = signature.replace( "()", "" )
			.replace( "(", ", " )
			.replace( ")", "" )
			.split( ", " );

		return result;
	}

	string[] outputs;

	string[] includes;

/*	outputs ~=	"#ifdef private\n"
				"  #undef private\n"
				"#endif\n"
				"\n"
				"#ifdef protected\n"
				"  #undef protected\n"
				"#endif\n"
				"\n"
				"// Dirty hack\n"
				"#define _ALLOW_KEYWORD_MACROS\n"
				"#define private public\n"
				"#define protected public";*/

	outputs ~=	"#include \"binderoo/defs.h\"\n"
				"#include \"binderoo/exports.h\"";

	foreach( ref boundFunction; functions )
	{
		if( boundFunction.strRequiredInclude.Length > 0 )
		{
			string fullName = cast( string )boundFunction.strRequiredInclude;

			if( !includes.canFind( fullName ) )
			{
				includes ~= fullName;
			}
		}
	}


	outputs ~= includes.joinWith( "#include \"", "\"", "\n" );

	size_t[][ string ] functionsByClass;

	foreach( iIndex, ref boundFunction; functions )
	{
		string className = cast( string )boundFunction.strOwningClass;

		functionsByClass[ className ] ~= iIndex;
	}

	foreach( foundClass; functionsByClass.byKeyValue )
	{
		string strClass = foundClass.key;
		string strClassWithoutNamespaces = strClass.replace( "::", "_" );

		string definitionLines[];

		string strExportVersion = "iExportVersion_" ~ strClassWithoutNamespaces;
		string strNumExportedMethods = "numExportedMethods_" ~ strClassWithoutNamespaces;
		string strVTableOf = "vtableOf_" ~ strClassWithoutNamespaces;
		string strExportedMethods = "exportedMethods_" ~ strClassWithoutNamespaces;
		string strExportedClass = "exportedClass_" ~ strClassWithoutNamespaces;

		definitionLines ~= "static const int " ~ strExportVersion ~ " = 1; // VERSION NUMBER IS A HACK";
		definitionLines ~= "static size_t " ~ strNumExportedMethods ~ " = " ~ to!string( foundClass.value.length ) ~ ";";
		if( foundClass.value.length == 0 )
		{
			definitionLines ~= "static binderoo::ExportedMethod* " ~ strExportedMethods ~ " = nullptr;";
		}
		else
		{
			definitionLines ~= "static void** getVTable_" ~ strClassWithoutNamespaces ~ "() { " ~ foundClass.key ~ " thisInstance; return *(void***)&thisInstance; }";
			definitionLines ~= "static void** " ~ strVTableOf ~ " = getVTable_" ~ strClassWithoutNamespaces ~ "();";
			definitionLines ~= "static binderoo::ExportedMethod " ~ strExportedMethods ~ "[] =";
			definitionLines ~= "{";

			foreach( iCount, iIndex; foundClass.value )
			{
				BoundFunction func = functions[ iIndex ];

				if( func.eFunctionKind == BoundFunction.FunctionKind.Virtual )
				{
					definitionLines ~= "\tbinderoo::ExportedMethod( \"" ~ cast( string )func.strFunctionName ~ "\", \"" ~ cast( string )func.strFunctionSignature ~ "\", " ~ strVTableOf ~ "[ " ~ to!string( iCount ) ~ " ] ),";
				}
				else
				{
					auto strOriginalSig = cast( string )func.strFunctionSignature;
					auto foundOpenBrackets = strOriginalSig.indexOf( '(' );
					auto strReturnType = strOriginalSig[ 0 .. foundOpenBrackets ];
					auto foundCloseBrackets = strOriginalSig.indexOf( ')' );
					auto strParameters = strOriginalSig[ foundOpenBrackets .. foundCloseBrackets + 1 ];
					auto strTypeCast = "( " ~ strReturnType ~ "(" ~ strClass ~ "::*)" ~ strParameters ~ " )";

					definitionLines ~= "\tbinderoo::ExportedMethod( \"" ~ cast( string )func.strFunctionName ~ "\", \"" ~ cast( string )func.strFunctionSignature ~ "\", " ~ strTypeCast ~ "&" ~ cast(string)func.strFunctionName ~ " ),";
				}
			}
			definitionLines ~= "};";
		}

		definitionLines ~= "static binderoo::ExportedClass " ~ strExportedClass ~ "( " ~ strExportVersion ~ ", binderoo::DString( \"" ~ foundClass.key ~ "\" ), binderoo::DString( \"<unknown>\" ), binderoo::ExportedMethods( " ~ strExportedMethods ~ ", " ~ strNumExportedMethods ~ " ) );";

		outputs ~= definitionLines.joinWith( "\n" );
	}

	return outputs;
}
//----------------------------------------------------------------------------

public string generateCPPStyleBindingDeclarationsForAllObjects()
{
	string[] declarations = generateCPPStyleBindingDeclaration( importFunctions );

	import std.stdio;
	foreach( decl; declarations )
	{
		writeln( decl, "\n//----------------------------------------------------------------------------\n" );
	}

	return declarations.joinWith( "\n//----------------------------------------------------------------------------\n" );
}
//----------------------------------------------------------------------------

public const(BoundFunction)[] getAllImportedFunctions()
{
	return importFunctions;
}
//----------------------------------------------------------------------------

public const(BoundFunction)[] getAllExportedFunctions()
{
	return exportFunctions;
}
//----------------------------------------------------------------------------

public const(BoundObject)[] getAllExportedObjects()
{
	return exportObjects;
}
//----------------------------------------------------------------------------

// Module external interface
//----------------------------------------------------------------------------

export extern( C ) void importFunctionsFrom( binderoo.slice.Slice!( BoundFunction ) exports )
/*in
{
	foreach( ref exportedFunction; exports )
	{
		assert( exportedFunction.eResolution == BoundFunction.Resolution.Exported, "Function " ~ cast(string) exportedFunction.strFunctionName ~ " is not marked as exported!" );
		auto foundIndex = ( exportedFunction.functionHashes in importFunctionIndices );
		if( foundIndex !is null )
		{
			assert( importFunctions[ *foundIndex ].eResolution == BoundFunction.Resolution.WaitingForImport, "Function " ~ cast(string) exportedFunction.strFunctionName ~ " is not waiting for import!" );
		}
	}
}
out
{
	foreach( ref importedFunction; importFunctions )
	{
		assert( importedFunction.eResolution == BoundFunction.Resolution.WaitingForImport, "Function " ~ cast(string) importedFunction.strFunctionName ~ " is still waiting for import!" );
	}
}
body*/
{
	import std.stdio;
	import std.conv;

	foreach( ref exportedFunction; exports )
	{
		auto foundIndex = ( exportedFunction.functionHashes in importFunctionIndices );
		if( foundIndex !is null )
		{
			void** pTarget = cast(void**)importFunctions[ *foundIndex ].pFunction;
			*pTarget = exportedFunction.pFunction;
			importFunctions[ *foundIndex ].eResolution = BoundFunction.Resolution.Imported;
		}
	}
}
//----------------------------------------------------------------------------

export extern( C ) void getExportedObjects( binderoo.slice.Slice!( BoundObject )* pOutput )
{
	*pOutput = binderoo.slice.Slice!( BoundObject )( exportObjects );
}
//----------------------------------------------------------------------------

export extern( C ) void getExportedFunctions( binderoo.slice.Slice!( BoundFunction )* pOutput )
{
	*pOutput = binderoo.slice.Slice!( BoundFunction )( exportFunctions );
}
//----------------------------------------------------------------------------

export extern( C ) void* createObjectByName( DString name )
{
	return createObjectByHash( fnv1a_64( cast( string ) name ) );
}
//----------------------------------------------------------------------------

export extern( C ) void* createObjectByHash( ulong objectHash )
{
	auto foundIndex = ( objectHash in exportObjectIndices );
	if( foundIndex !is null )
	{
		void* pObj = exportObjects[ *foundIndex ].alloc( 1 );
		return pObj;
	}

	return null;
}
//----------------------------------------------------------------------------

export extern( C ) void destroyObjectByName( DString name, void* pObj )
{
	return destroyObjectByHash( fnv1a_64( cast( string ) name ), pObj );
}
//----------------------------------------------------------------------------

export extern( C ) void destroyObjectByHash( ulong objectHash, void* pObj )
{
	auto foundIndex = ( objectHash in exportObjectIndices );
	if( foundIndex !is null )
	{
		exportObjects[ *foundIndex ].free( pObj );
	}
}
//----------------------------------------------------------------------------

alias BindingRawAllocator = extern( C ) void* function( size_t size );

export extern( C ) const(char)* generateCPPStyleBindingDeclarationsForAllObjects( BindingRawAllocator allocator )
{
	import core.stdc.string;

	string fullDeclaration = generateCPPStyleBindingDeclarationsForAllObjects();

	size_t outputSize = fullDeclaration.length + 1;
	char* pOutput = cast(char*)allocator( outputSize );

	if( fullDeclaration.length > 0 )
	{
		memcpy( pOutput, fullDeclaration.ptr, outputSize );
	}

	pOutput[ fullDeclaration.length ] = 0;

	return pOutput;
}
//----------------------------------------------------------------------------

private:

__gshared BoundFunction[]							importFunctions;
__gshared size_t[ BoundFunction.Hashes ]			importFunctionIndices;
__gshared BoundFunction[]							exportFunctions;
__gshared size_t[ BoundFunction.Hashes ]			exportFunctionIndices;
__gshared BoundObject[]								exportObjects;
__gshared size_t[ ulong ]							exportObjectIndices;

//============================================================================
