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

// Really cheap and nasty method invoker for objects
// What can it do: Take a string that looks like variable.variable.function()
// What can't it do: Anything fancy, like assignments and operators etc.
// Parameters need to be plain types, they can't do variable lookups yet.

module binderoo.scripting.scripting;
//----------------------------------------------------------------------------

public import binderoo.scripting.attributes;
public import binderoo.functiondescriptor;
public import binderoo.variabledescriptor;

private import std.string;
//----------------------------------------------------------------------------

enum ExecutionError : int
{
	Success = 0,
	CommandIncomplete,
	SymbolNotFound,
	IncorrectParameters,
}
//----------------------------------------------------------------------------

struct ExecutionResult
{
	ExecutionError	m_eError				= ExecutionError.Success;
	string			m_strAdditionalInfo		= "";

	bool opCast( T )() const pure @safe nothrow if( is( T == bool ) ) { return m_eError == ExecutionError.Success; }
}
//----------------------------------------------------------------------------

struct Symbol
{
	enum Type : uint { Incomplete, ObjectAlias, FunctionCall };

	this( string token ) pure nothrow
	{
		auto uOpenBracketPosition = token.indexOf( '(' );
		auto uCloseBracketPosition = token.indexOf( ')' );

		type = ( uOpenBracketPosition != -1 ? ( uCloseBracketPosition != -1 ? Type.FunctionCall : Type.Incomplete ) : Type.ObjectAlias );

		final switch( type )
		{
		case Type.Incomplete:
			name = token;
			break;
		case Type.ObjectAlias:
			name = token;
			break;
		case Type.FunctionCall:
			name = token[ 0 .. uOpenBracketPosition ];
			if( uOpenBracketPosition != uCloseBracketPosition - 1 )
			{
				parameters = token[ uOpenBracketPosition + 1 .. uCloseBracketPosition ].split!(',')();
			}
			break;
		}
	}

	string		name;
	string[]	parameters;
	Type		type;
}
//----------------------------------------------------------------------------

private Symbol[] symbolize( string[] tokens ) pure nothrow
{
	Symbol[] symbols;
	foreach( ref token; tokens )
	{
		symbols ~= Symbol( token );
	}

	return symbols;
}
//----------------------------------------------------------------------------

private string[] split( char delim = '.' )( string source ) pure @safe nothrow
{
	// There must be an easier way to handle differences between 32 and 64 bit iteration...
	auto uCommaPosition = cast( typeof( source.length ) )-1;
	auto uOpenBracketPosition = cast( typeof( source.length ) )-1;
	auto uCloseBracketPosition = cast( typeof( source.length ) )-1;

	foreach( uIndex, ref c; source )
	{
		if( c == '(' )
		{
			uOpenBracketPosition = uIndex;
		}
		else if( c == ')' )
		{
			uCloseBracketPosition = uIndex;
		}
		else if ( c == delim && uOpenBracketPosition == -1 || uCloseBracketPosition != -1 )
		{
			uCommaPosition = uIndex;
			break;
		}
	}

	if( uCommaPosition == -1 )
	{
		uCommaPosition = source.length;
	}

	string[] returnSlice = [ source[ 0 .. uCommaPosition ] ];
	if( uCommaPosition != source.length )
	{
		returnSlice ~=split( source[ uCommaPosition + 1 .. $ ] );
	}
	return returnSlice;
}
//----------------------------------------------------------------------------

private Symbol[] symbolize( string command )
{
	return command.removechars( " " )
			.split
			.symbolize;
}
//----------------------------------------------------------------------------

private void executeObjectAlias( T )( ref T obj, Symbol[] symbols, out ExecutionResult result )
{
	alias Variables = VariableDescriptors!( T );

	string generateMixin()
	{
		string output;
		foreach( Variable; Variables )
		{
			output ~= "case \"" ~ Variable.Name ~ "\":\n"
					~ "execute( obj." ~ Variable.Name ~ ", symbols[ 1 .. $ ], result );\n"
					~ "break;\n";
		}

		return output;
	}

	switch( symbols[ 0 ].name )
	{
		mixin( generateMixin() );
		default:
			result = ExecutionResult( ExecutionError.SymbolNotFound, "Symbol \"" ~ symbols[ 0 ].name ~ "\" not found" );
			break;
	}
}
//----------------------------------------------------------------------------

private void executeFunctionCall( T )( ref T obj, Symbol[] symbols, out ExecutionResult result )
{
	alias Functions = FunctionDescriptors!( T );

	template ShouldIgnore( alias T )
	{
		enum ShouldIgnore = T.HasUDA!( NoScriptVisibility )
							|| T.Name.startsWith( "op" )
							|| T.Name == "factory"
							|| T.Name == "__ctor";
	}

	string generateImportMixin()
	{
		import std.algorithm;

		string[] modules;

		foreach( Function; Functions )
		{
			static if( !ShouldIgnore!( Function ) )
			{
				foreach( Parameter; Function.ParametersAsTuple )
				{
					static if( Parameter.Descriptor.IsUserType )
					{
						string moduleName = moduleName!( Parameter.Type );

						if( !modules.canFind( moduleName ) )
						{
							modules ~= "import " ~ moduleName ~ ";";
						}
					}
				}
			}
		}

		return modules.joinWith( "\n" );
	}

	string generateFunctionParametersCallMixin( Function )()
	{
		import std.conv : to;

		string[] parameters;
		foreach( iIndex, Parameter; Function.ParametersAsTuple )
		{
			parameters ~= "param" ~ to!string( iIndex );
		}

		return parameters.joinWith( ", " );
	}

	string generateFunctionParametersDeclarationMixin( Function )()
	{
		import std.conv : to;

		string[] parameters;
		foreach( iIndex, Parameter; Function.ParametersAsTuple )
		{
			parameters ~= "auto param" ~ to!string( iIndex ) ~ " = std.conv.to!( " ~ fullyQualifiedName!( Parameter.UnqualifiedType ) ~ " )( symbols[ 0 ].parameters[ " ~ iIndex.stringof ~ " ] )";
		}

		return parameters.joinWith( "  ", ";\n", ";\n" );
	}

	string generateSwitchMixin()
	{
		string output;
		foreach( Function; Functions )
		{
			static if( !ShouldIgnore!( Function ) )
			{
				output ~=	"case \"" ~ Function.Name ~ "\":\n"
							~ "if( symbols[ 0 ].parameters.length == " ~ Function.ParametersAsTuple.length.stringof ~ " )\n"
							~ "{\n"
							~ generateFunctionParametersDeclarationMixin!( Function )
							~ "  obj." ~ Function.Name ~ "( " ~ generateFunctionParametersCallMixin!( Function )() ~ " );\n"
							~ "}\n"
							~ "else { result = ExecutionResult( ExecutionError.IncorrectParameters, \"Expected " ~ Function.ParametersAsTuple.length.stringof ~ " parameters, received \" ~ to!string( symbols[ 0 ].parameters.length ) ); }\n"
							~ "break;\n";
			}
		}

		return output;
	}

	mixin( generateImportMixin() );
	import std.conv;

	switch( symbols[ 0 ].name )
	{
		mixin( generateSwitchMixin() );
		default:
			result = ExecutionResult( ExecutionError.SymbolNotFound, "Function \"" ~ symbols[ 0 ].name ~ "\" not found" );
			break;
	}
}
//----------------------------------------------------------------------------

void execute( T )( ref T obj, Symbol[] symbols, out ExecutionResult result )
{
	if( symbols.length > 0 )
	{
		final switch( symbols[ 0 ].type )
		{
			case Symbol.Type.ObjectAlias:
				obj.executeObjectAlias( symbols, result );
				break;
			case Symbol.Type.FunctionCall:
				obj.executeFunctionCall( symbols, result );
				break;
			case Symbol.Type.Incomplete:
				result = ExecutionResult( ExecutionError.CommandIncomplete, "Incomplete symbol \"" ~ symbols[ 0 ].name ~ "\"" );
				break;
		}
	}
	else
	{
		result = ExecutionResult( ExecutionError.CommandIncomplete, "Command did not resolve to a function" );
	}
}
//----------------------------------------------------------------------------

ExecutionResult execute( T )( ref T obj, string command )
{
	ExecutionResult result;

	execute( obj, symbolize( command ), result );

	return result;
}
//----------------------------------------------------------------------------

//============================================================================
