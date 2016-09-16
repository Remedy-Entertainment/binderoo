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

module binderoo.binding.attributes;
//----------------------------------------------------------------------------

struct BindIgnore { }
//----------------------------------------------------------------------------

struct BindRawImport
{
	enum FunctionKind : char
	{
		Static,
		Method,
		Virtual,
	}

	string			strCName;
	string			strCSignature;
	FunctionKind	eKind;
	ulong			uNameHash;
	ulong			uSignatureHash;
	int				iIntroducedVersion		= -1;
	int				iMaxVersion				= -1;

	@disable this();
	@disable this( string name );

	this( string name, string signature, FunctionKind kind, int introducedVersion = -1, int maxVersion = -1 )
	{
		import binderoo.hash;

		strCName						= name;
		strCSignature					= signature;
		eKind							= kind;
		uNameHash						= fnv1a_64( name );
		uSignatureHash					= fnv1a_64( signature );
		iIntroducedVersion				= introducedVersion;
		iMaxVersion						= maxVersion;
	}
}
//----------------------------------------------------------------------------

// A function marked with BindDisallow will not define the wrapper function
// in cases where you still need to know about it.
struct BindDisallow
{
}
//----------------------------------------------------------------------------

// A type marked with BindAbstract will indicate that the corresponding C++
// type cannot instantiate thanks to the existence of pure virtual methods.
// These types will not attempt to auto-generate C++ bindings.
// TODO: Add more restrictions for instantiation etc
struct BindAbstract
{
}
//----------------------------------------------------------------------------

struct BindVirtual
{
	int		iIntroducedVersion		= -1;
	int		iMaxVersion				= -1;
}
//----------------------------------------------------------------------------

struct BindMethod
{
	int		iIntroducedVersion		= -1;
	int		iMaxVersion				= -1;
}
//----------------------------------------------------------------------------

struct BindConstructor
{
	int		iIntroducedVersion		= -1;
	int		iMaxVersion				= -1;
}
//----------------------------------------------------------------------------

struct BindDestructor
{
	int		iIntroducedVersion		= -1;
	int		iMaxVersion				= -1;
}
//----------------------------------------------------------------------------

struct BindVirtualDestructor
{
	int		iIntroducedVersion		= -1;
	int		iMaxVersion				= -1;
}
//----------------------------------------------------------------------------

struct BindStatic
{
	int		iIntroducedVersion		= -1;
	int		iMaxVersion				= -1;
}
//----------------------------------------------------------------------------

struct BindExport
{
	int		iIntroducedVersion		= -1;
	int		iMaxVersion				= -1;
}
//----------------------------------------------------------------------------

struct BindGetter
{
	string	strPropertyName;
}
//----------------------------------------------------------------------------

struct BindSetter
{
	string strPropertyName;
}
//----------------------------------------------------------------------------

struct BindBinaryMatch
{
}
//----------------------------------------------------------------------------

struct Documentation
{
	struct ParameterDocumentation
	{
		string						strParamName;
		string						strParamDescription;
	}

	string							strFuncDescription;
	string							strReturnDescription;
	ParameterDocumentation[]		vecTemplateParameterDescriptions;
	ParameterDocumentation[]		vecParameterDescriptions;

}
//----------------------------------------------------------------------------

//============================================================================
