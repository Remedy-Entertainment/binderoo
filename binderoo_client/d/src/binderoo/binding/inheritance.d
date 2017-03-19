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

public import binderoo.binding.attributes;
public import binderoo.typedescriptor;
import binderoo.traits;
//----------------------------------------------------------------------------

enum InheritanceStructType
{
	CPP = 0,
	D,
}
//----------------------------------------------------------------------------

enum BeginsVirtual
{
	No = 0,
	Yes = 1
}
//----------------------------------------------------------------------------

mixin template CPPStructBase( BeginsVirtual eBeginsVirtual = BeginsVirtual.No )
{
	enum StructType				= InheritanceStructType.CPP;
	alias BaseType				= void;
	alias HighestLevelCPPType	= typeof( this );

	enum OriginatesVTable	= eBeginsVirtual == BeginsVirtual.Yes;
	enum CanConstructVTable	= OriginatesVTable;

	static if( OriginatesVTable )
	{
		@BindNoSerialise void* _vtablePointer;
	}
}
//----------------------------------------------------------------------------

mixin template CPPStructInherits( ThisBaseType, BeginsVirtual eBeginsVirtual = BeginsVirtual.No )
{
	enum StructType				= InheritanceStructType.CPP;
	alias BaseType				= ThisBaseType;
	alias HighestLevelCPPType	= typeof( this );

	ThisBaseType base;
	alias base this;

	enum OriginatesVTable	= eBeginsVirtual == BeginsVirtual.Yes;
	enum CanConstructVTable	= OriginatesVTable || BaseType.CanConstructVTable;

	static assert( !OriginatesVTable || !BaseType.CanConstructVTable, "VTable chain is broken somewhere with type " ~ typeof( this ).stringof );

	static if( OriginatesVTable )
	{
		@BindNoSerialize void* _vtablePointer;
	}
}
//----------------------------------------------------------------------------

mixin template DStructInherits( ThisBaseType )
{
	enum StructType				= InheritanceStructType.D;
	alias BaseType				= ThisBaseType;
	alias HighestLevelCPPType	= BaseType.HighestLevelCPPType;

	ThisBaseType base;
	alias base this;

	enum OriginatesVTable	= false;
	enum CanConstructVTable	= BaseType.CanConstructVTable;
}
//----------------------------------------------------------------------------

string GenerateBindings( ThisType )()
{
	return GenerateStructContents!( ThisType.StructType, ThisType, ThisType.BaseType );
}
//----------------------------------------------------------------------------

// Implementation follows
//----------------------------------------------------------------------------
//----------------------------------------------------------------------------

template RawFnPointerAlias( alias decl )
{
	struct Wrapper
	{
		mixin( decl );
	}
	alias RawFnPointerAlias = typeof( &Wrapper.prototype );
}
//----------------------------------------------------------------------------

private:

enum EndLine = "\n";
enum EndStatement = ";\n";

version = MSVCInheritance;
//----------------------------------------------------------------------------

struct FoundMethod
{
	string			DPrototypeDecl;
	string			DCallWithParams;
	string			DDeclForFnPointer;
	string			DRawImportUDAs;
	string			CExplicitCast;
	string			CSignatureForMatching;
	string			DVirtualOverrideCall;
	string			DVirtualOverrideName;
	bool			bUseDVirtualOverride = false;
	
	BindRawImport	RawImportData;
}
//----------------------------------------------------------------------------

struct AllFoundMethods
{
	FoundMethod[]	nonVirtualMembers;
	FoundMethod[]	virtualMembers;
	FoundMethod[]	staticMembers;
}
//----------------------------------------------------------------------------

template OverloadsOf( ThisType, alias thisMember )
{
	import std.typetuple : TypeTuple;

	version( MSVCInheritance ) alias OverloadsOf = TypeTuple!( __traits( getOverloads, ThisType, thisMember ) );
	else alias OverloadsOf = TypeTuple!( __traits( getOverloads, ThisType, thisMember ) );
}
//----------------------------------------------------------------------------

AllFoundMethods FindAllMethods( SuperType, ThisType, BaseType )( )
{
	FoundMethod Rewrite( alias Function )( )
	{
		static if( HasUDA!( Function, BindMethod ) )
		{
			enum FunctionName		= __traits( identifier, Function );

			alias VersionDetails	= GetUDA!( Function, BindMethod );
			enum IntroducedVersion	= VersionDetails.iIntroducedVersion;
			enum MaxVersion			= VersionDetails.iMaxVersion;
			enum RawImportType		= __traits( isStaticFunction, Function ) ? BindRawImport.FunctionKind.Static : BindRawImport.FunctionKind.Method;
		}
		else static if( HasUDA!( Function, BindConstructor ) )
		{
			enum FunctionName		= "cppConstructor";

			alias VersionDetails	= GetUDA!( Function, BindConstructor );
			enum IntroducedVersion	= VersionDetails.iIntroducedVersion;
			enum MaxVersion			= VersionDetails.iMaxVersion;
			enum RawImportType		= BindRawImport.FunctionKind.Constructor;
		}
		else static if( HasUDA!( Function, BindDestructor ) )
		{
			enum FunctionName		= "cppDestructor";

			alias VersionDetails	= GetUDA!( Function, BindDestructor );
			enum IntroducedVersion	= VersionDetails.iIntroducedVersion;
			enum MaxVersion			= VersionDetails.iMaxVersion;
			enum RawImportType		= BindRawImport.FunctionKind.Destructor;
		}
		else static if( HasUDA!( Function, BindVirtual ) )
		{
			enum FunctionName		= __traits( identifier, Function );

			alias VersionDetails	= GetUDA!( Function, BindVirtual );
			enum IntroducedVersion	= VersionDetails.iIntroducedVersion;
			enum MaxVersion			= VersionDetails.iMaxVersion;
			enum RawImportType		= BindRawImport.FunctionKind.Virtual;
		}
		else static if( HasUDA!( Function, BindVirtualDestructor ) )
		{
			enum FunctionName		= "cppDestructor";

			alias VersionDetails	= GetUDA!( Function, BindVirtualDestructor );
			enum IntroducedVersion	= VersionDetails.iIntroducedVersion;
			enum MaxVersion			= VersionDetails.iMaxVersion;
			enum RawImportType		= BindRawImport.FunctionKind.VirtualDestructor;
		}
		else
		{
			enum FunctionName		= __traits( identifier, Function );
			alias VersionDetails	= void;
			enum IntroducedVersion	= -1;
			enum MaxVersion			= -1;
			enum RawImportType		= BindRawImport.FunctionKind.Invalid;
		}

		FoundMethod method;

		static if( !is( VersionDetails == void ) )
		{
			static if( __traits( compiles, __traits( parent, Function ).init ) )
			{
				alias ParentType = typeof( __traits( parent, Function ).init );
				enum FunctionIsStatic = __traits( isStaticFunction, Function ) ? "static " : "";
			}
			else
			{
				alias ParentType = void;
				enum FunctionIsStatic = __traits( isStaticFunction, Function ) ? "static " : "";
			}

			enum Attributes
			{
				None	= 0b000,
				Const	= 0b001,
				Ref		= 0b010,
				Static	= 0b100,
			}

			Attributes GetAttribs()
			{
				Attributes ret;
				foreach( attr; __traits( getFunctionAttributes, Function ) )
				{
					switch( attr ) with( Attributes )
					{
					case "const":
						ret |= Const;
						break;
					case "ref":
						ret |= Ref;
						break;
					default:
						break;
					}
				}

				static if( __traits( isStaticFunction, Function ) ) ret |= Attributes.Static;

				return ret;
			}

			static if( HasUDA!( SuperType, BindVersion ) )
			{
				enum IncludeVersions = GetUDA!( SuperType, BindVersion ).strVersions;
			}
			else
			{
				enum string[] IncludeVersions = string[].init;
			}

			static if( HasUDA!( SuperType, BindExcludeVersion ) )
			{
				enum ExcludeVersions = GetUDA!( SuperType, BindExcludeVersion ).strVersions;
			}
			else
			{
				enum string[] ExcludeVersions = string[].init;
			}


			import std.traits		: ParameterIdentifierTuple
									, ParameterTypeTuple
									, ParameterStorageClassTuple
									, ParameterStorageClass
									, ReturnType
									, moduleName;

			alias ParamTypes		= ParameterTypeTuple!Function;
			alias ParamNames		= ParameterIdentifierTuple!Function;
			alias ParamStorages		= ParameterStorageClassTuple!Function;
			alias ParamReturnType	= ReturnType!Function;

			enum FunctionAttribs	= GetAttribs();
			enum DReturnsRef		= FunctionAttribs & Attributes.Ref ? "ref" : "";
			enum CReturnsRef		= FunctionAttribs & Attributes.Ref ? "&" : "";
			enum FunctionIsConst	= FunctionAttribs & Attributes.Const ? " const" : "";

			string storageToString( uint eClass )
			{
				string[] strOutputs;

				if( eClass & ParameterStorageClass.ref_ )
					strOutputs ~= "ref";

				string output = strOutputs.joinWith( " " );
				if( output.length > 0 )
					output ~= " ";
				return output;
			}

			string storageToCRef( uint eClass )
			{
				return ( eClass & ParameterStorageClass.ref_ ) ? "&" : "";
			}

			string[] strDParams;
			string[] strDCallParams;
			string[] strDOverrideCallParams;
			string[] strCParams;
			string[] strCTypes;

			static if( !is( ParentType == void ) && !( FunctionAttribs & Attributes.Static ) )
			{
				strCParams ~= ParentType.stringof ~ "* const thisptr";
				strDCallParams ~= "cast(" ~ SuperType.stringof ~ "*)&this";
			}

			foreach( iIndex, Type; ParamTypes )
			{
				string strCType = CTypeString!( Type ) ~ storageToCRef( ParamStorages[ iIndex ] );

				strDParams ~= storageToString( ParamStorages[ iIndex ] ) ~ ParamTypes[ iIndex ].stringof ~ " " ~ ParamNames[ iIndex ];
				strDCallParams ~= ParamNames[ iIndex ];
				strDOverrideCallParams ~= ParamNames[ iIndex ];
				strCParams ~= strCType ~ " " ~ ParamNames[ iIndex ];
				strCTypes ~= strCType;
			}
	
			string[] strUDAs;
			foreach( UDA; __traits( getAttributes, Function ) )
			{
				strUDAs ~= UDA.stringof;
			}

			method.DPrototypeDecl = strUDAs.joinWith( "@", "", " " ) ~ " " ~ FunctionIsStatic ~ DReturnsRef ~ " " ~ ParamReturnType.stringof ~ " " ~ FunctionName ~ "(" ~ strDParams.joinWith( ", " ) ~ ")" ~ FunctionIsConst;
			method.DCallWithParams = strDCallParams.joinWith( ", " );

			static if( !( FunctionAttribs & Attributes.Static ) )
			{
				strDParams = [ SuperType.stringof ~ "* thisptr" ] ~ strDParams;
			}
			method.DDeclForFnPointer = "import " ~ moduleName!SuperType ~ "; extern (C++) static " ~ DReturnsRef ~ " " ~ ParamReturnType.stringof ~ " prototype(" ~ strDParams.joinWith( ", " ) ~ ");";
			method.DVirtualOverrideName = SuperType.stringof ~ ".CPPLinkage_" ~ FunctionName;
			static if( !is( ParamReturnType == void ) )
			{
				method.DVirtualOverrideCall = "extern (C++) static " ~ DReturnsRef ~ " " ~ ParamReturnType.stringof ~ " CPPLinkage_" ~ FunctionName ~ "(" ~ strDParams.joinWith( ", " ) ~ ") { return thisptr." ~ FunctionName ~ "( " ~ strDOverrideCallParams.joinWith(", " ) ~ " ); }";
			}
			else
			{
				method.DVirtualOverrideCall = "extern (C++) static void CPPLinkage_" ~ FunctionName ~ "(" ~ strDParams.joinWith( ", " ) ~ ") { thisptr." ~ FunctionName ~ "( " ~ strDOverrideCallParams.joinWith(", " ) ~ " ); }";
			}

			method.CSignatureForMatching = CTypeString!ParamReturnType ~ CReturnsRef ~ "(" ~ strCTypes.joinWith( ", " ) ~ ")" ~ FunctionIsConst;
			static if( !is( ParentType == void ) )
			{
				// TODO: THIS PART IS TEH BROKENS
				static if( !( FunctionAttribs & Attributes.Static ) )
				{
					method.CExplicitCast = CTypeString!ParamReturnType ~ CReturnsRef ~ "(" ~ CTypeString!( SuperType.HighestLevelCPPType ) ~ "::*)(" ~ strCTypes.joinWith( ", " ) ~ ")" ~ FunctionIsConst;
				}
				else
				{
					method.CExplicitCast = CTypeString!ParamReturnType ~ CReturnsRef ~ "(*)(" ~ strCTypes.joinWith( ", " ) ~ ")";
				}

				method.RawImportData = BindRawImport( CTypeString!( SuperType.HighestLevelCPPType ) ~ "::" ~ FunctionName, method.CExplicitCast, IncludeVersions, ExcludeVersions, RawImportType, 0, ( FunctionAttribs & Attributes.Const ), false, IntroducedVersion, MaxVersion );
			}
			else
			{
				method.CExplicitCast = CTypeString!ParamReturnType ~ CReturnsRef ~ "(*)(" ~ strCTypes.joinWith( ", " ) ~ ")";
				method.RawImportData = BindRawImport( FunctionName, method.CExplicitCast, IncludeVersions, ExcludeVersions, RawImportType, 0, ( FunctionAttribs & Attributes.Const ), false, IntroducedVersion, MaxVersion );
			}
		}

		return method;
	}

	AllFoundMethods foundMethods;

	static if( !is( BaseType == void ) )
	{
		foundMethods = FindAllMethods!( SuperType, BaseType, BaseType.BaseType )( );
	}

	foreach( thisMember; __traits( allMembers, ThisType ) )
	{
		alias TheseOverloads = OverloadsOf!( ThisType, thisMember );

		static if( TheseOverloads.length > 0 )
		{
/+			version( MSVCInheritance )
			{
				import std.meta : Reverse;
				alias OverloadRange = Reverse!TheseOverloads;
			}
			else
			{
				alias OverloadRange = TheseOverloads;
			}+/

			foreach_reverse( ThisOverload; TheseOverloads )
			{
				enum ThisFoundMethod = Rewrite!ThisOverload;
				static if( ThisType.StructType == InheritanceStructType.CPP )
				{
					FoundMethod foundMethod = ThisFoundMethod;

					final switch( foundMethod.RawImportData.eKind ) with( BindRawImport.FunctionKind )
					{
					case Static:
						foundMethod.RawImportData.iOrderInTable = cast(int)foundMethods.staticMembers.length;
						foundMethods.staticMembers ~= foundMethod;
						break;
					case Method:
					case Constructor:
					case Destructor:
						foundMethod.RawImportData.iOrderInTable = cast(int)foundMethods.nonVirtualMembers.length;
						foundMethods.nonVirtualMembers ~= foundMethod;
						break;
					case Virtual:
					case VirtualDestructor:
						foundMethod.RawImportData.iOrderInTable = cast(int)foundMethods.virtualMembers.length;
						foundMethods.virtualMembers ~= foundMethod;
						break;
					case Invalid:
						break;
					}
				}
				else static if( ThisFoundMethod.RawImportData.eKind != BindRawImport.FunctionKind.Invalid )
				{
					static assert( ThisFoundMethod.RawImportData.eKind == BindRawImport.FunctionKind.Virtual, "Bound method " ~ thisMember ~ " in D struct " ~ ThisType.stringof ~ " is not a virtual override!" );

					import std.algorithm : find;

					auto found = foundMethods.virtualMembers.find!( ( a, b ) => a.RawImportData.uNameHash == b.RawImportData.uNameHash && a.RawImportData.uSignatureHash == b.RawImportData.uSignatureHash )( ThisFoundMethod );
					if( found.length > 0 )
					{
						found[ 0 ].bUseDVirtualOverride = true;
					}
				}
			}
		}
	}

	return foundMethods;
}
//----------------------------------------------------------------------------

string GenerateVTable( FoundMethod[] VirtualMethods, bool bOriginatesVTable, bool bCanConstructVTable )
{
	if( VirtualMethods.length == 0 )
	{
		return "";
	}

	import std.conv : to;

	string strOutput =	"\t@BindNoExportObject struct VTable" ~ EndLine
						~ "\t{" ~ EndLine;

	foreach( iIndex, Method; VirtualMethods )
	{
		if( Method.bUseDVirtualOverride )
		{
			strOutput ~=	"\t\tRawFnPointerAlias!( \"" ~ Method.DDeclForFnPointer ~ "\" ) virtual" ~ iIndex.to!string ~ " = &" ~ Method.DVirtualOverrideName ~ EndStatement
							~ EndLine;
		}
		else
		{
			strOutput ~=	/+"\t\t@NoScriptVisibility" ~ EndLine
							~+/ "\t\t" ~ Method.RawImportData.toUDAString ~ EndLine
							~ "\t\tRawFnPointerAlias!( \"" ~ Method.DDeclForFnPointer ~ "\" ) virtual" ~ iIndex.to!string ~ EndStatement
							~ EndLine;
		}
	}

	strOutput ~=		"\t\tenum FunctionCount = " ~ VirtualMethods.length.to!string ~ EndStatement
						~ "\t\tfinal void** getPointer() { return cast( void** )&this; }" ~ EndLine
						~ "\t}" ~ EndLine
						~ EndLine
						~ "\t__gshared VTable _vtableData" ~ EndStatement
						~ EndLine;

	foreach( iIndex, Method; VirtualMethods )
	{
		if( Method.bUseDVirtualOverride )
		{
			strOutput		~= "\t" ~ Method.DVirtualOverrideCall ~ EndLine
							~ EndLine;
		}
		else
		{
			strOutput		~= "\t" ~ Method.DPrototypeDecl ~ EndLine
							~ "\t{" ~ EndLine
							~ "\t\treturn ( cast( VTable* )_vtablePointer ).virtual" ~ iIndex.to!string ~ "(" ~ Method.DCallWithParams ~ ")" ~ EndStatement
							~ "\t}" ~ EndLine
							~ EndLine;
		}
	}

	if( bCanConstructVTable )
	{
		strOutput			~= "\tvoid setupVTable()" ~ EndLine
							~ "\t{" ~ EndLine;
		if( bOriginatesVTable )
		{
			strOutput		~= "\t\t_vtablePointer = _vtableData.getPointer()" ~ EndStatement;
		}
		else
		{
			strOutput		~= "\t\tbase.setupVTable( _vtableData.getPointer() )" ~ EndStatement;
		}
		strOutput			~= "\t}" ~ EndLine
							~ EndLine;

		strOutput			~= "\tvoid setupVTable( void* pNewVTable )" ~ EndLine
							~ "\t{" ~ EndLine;
		if( bOriginatesVTable )
		{
			strOutput		~= "\t\t_vtablePointer = pNewVTable" ~ EndStatement;
		}
		else
		{
			strOutput		~= "\t\tbase.setupVTable( pNewVTable )" ~ EndStatement;
		}
		strOutput			~= "\t}" ~ EndLine
							~ EndLine;
	}

	return strOutput;
}
//----------------------------------------------------------------------------

string GenerateMTable( FoundMethod[] NonVirtualMethods, FoundMethod[] StaticMethods )
{
	if( NonVirtualMethods.length == 0 && StaticMethods.length == 0 )
	{
		return "";
	}

	import std.conv : to;

	FoundMethod[] AllMethods = NonVirtualMethods ~ StaticMethods;

	string strOutput =	"\t@BindNoExportObject struct MTable" ~ EndLine
						~ "\t{" ~ EndLine;

	foreach( iIndex, Method; AllMethods )
	{
		strOutput ~=	/+"\t\t@NoScriptVisibility" ~ EndLine
						~+/ "\t\t" ~ Method.RawImportData.toUDAString ~ EndLine
						~ "\t\tRawFnPointerAlias!( \"" ~ Method.DDeclForFnPointer ~ "\" ) method" ~ iIndex.to!string ~ EndStatement
						~ EndLine;
	}

	strOutput ~=		"\t\tenum FunctionCount = " ~ AllMethods.length.to!string ~ EndStatement
						~ "\t}" ~ EndLine
						~ EndLine
						~ "\t__gshared MTable _methodtableData" ~ EndStatement
						~ EndLine;

	foreach( iIndex, Method; AllMethods )
	{
		strOutput		~= "\t" ~ Method.DPrototypeDecl ~ EndLine
						~ "\t{" ~ EndLine
						~ "\t\treturn _methodtableData.method" ~ iIndex.to!string ~ "(" ~ Method.DCallWithParams ~ ")" ~ EndStatement
						~ "\t}" ~ EndLine
						~ EndLine;
	}

	return strOutput;
}
//----------------------------------------------------------------------------

string GenerateStructContents( InheritanceStructType StructType, ThisType, BaseType )()
{
	static assert( StructType != InheritanceStructType.CPP || HasUDA!( ThisType, CTypeName ), ThisType.stringof ~ " is a C++ object but has no @CTypeName UDA defined." );
	enum AllMethods = FindAllMethods!( ThisType, ThisType, BaseType )( );

	return	GenerateVTable( AllMethods.virtualMembers, ThisType.OriginatesVTable, ThisType.CanConstructVTable )
			~ GenerateMTable( AllMethods.nonVirtualMembers, AllMethods.staticMembers );

}
//----------------------------------------------------------------------------

public void constructObject( Type )( ref Type obj )
{
	obj = Type();
	static if( __traits( hasMember, Type, "cppConstructor" ) )
	{
		obj.cppConstructor();
	}

	static if( __traits( hasMember, Type, "setupVTable" ) ) 
	{
		obj.setupVTable();
	}

	static if( __traits( hasMember, Type, "OnConstruct" ) )
	{
		obj.OnConstruct();
	}
}
//----------------------------------------------------------------------------

public void destructObject( Type )( ref Type obj )
{
	static if( __traits( hasMember, Type, "OnDestruct" ) )
	{
		obj.OnDestruct();
	}

	static if( __traits( hasMember, Type, "cppDestructor" ) )
	{
		obj.cppDestructor();
	}

	destroy( obj );
}
//----------------------------------------------------------------------------

//============================================================================
