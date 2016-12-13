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

module binderoo.binding.functionstub;
//----------------------------------------------------------------------------

public import binderoo.functiondescriptor;
public import binderoo.binding.attributes;
public import binderoo.scripting.attributes;

public import std.traits : fullyQualifiedName, moduleName;
//----------------------------------------------------------------------------

auto ParamTypes( Func, uint iIndex )() if( Func.IsMemberFunction )
{
	static if ( iIndex < Func.ParameterCount )
	{
		enum StorageType = Func.Parameter!( iIndex ).IsRef ? "ref " : "";
		enum Joiner = ( !Func.IsStatic || iIndex > 0 ) ? ", " : "";

		return Joiner ~ StorageType ~ fullyQualifiedName!( Func.Parameter!( iIndex ).Type ) ~ ParamTypes!( Func, iIndex + 1 )();
	}
	else
	{
		return "";
	}
}
//----------------------------------------------------------------------------

template RawMemberFunctionPointer( Func, RewriteThis = Func.ObjectType ) if( Func.IsMemberFunction )
{
	enum RefString = Func.ReturnsRef ? "ref " : "";

	struct Magic
	{
		mixin( "import " ~ moduleName!( Func.ObjectType ) ~ ";" );	// HI I'M MISTER HACKSEEKS LOOK AT ME
		mixin( "import " ~ moduleName!( RewriteThis ) ~ ";" );		// HI I'M MISTER HACKSEEKS LOOK AT ME
		static if( Func.IsStatic )
		{
			mixin( "static public extern( C++ ) "  ~ RefString ~ Func.ReturnType.stringof ~ " prototype( " ~ ParamTypes!( Func, 0u )() ~ " );" );
		}
		else
		{
			mixin( "static public extern( C++ ) "  ~ RefString ~ Func.ReturnType.stringof ~ " prototype( " ~ RewriteThis.stringof ~ "*" ~ ParamTypes!( Func, 0u ) ~ " );" );
		}
	}

	alias RawMemberFunctionPointer = typeof( &Magic.prototype );
}
//----------------------------------------------------------------------------

template RawMemberFunctionPointer( Func ) if( !Func.IsMemberFunction )
{
	alias RawMemberFunctionPointer = Func.FunctionPointerType;
}
//----------------------------------------------------------------------------

//============================================================================
