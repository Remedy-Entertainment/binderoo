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

module binderoo.objectprivacy;
//-----------------------------------------------------------------------------

// Privacy level. Handy.
enum PrivacyLevel : string
{
	Public				= "public",
	Private				= "private",
	Protected			= "protected",
	Export				= "export",
	Package				= "package",
	Inaccessible		= "inaccessible"
};
//----------------------------------------------------------------------------

template PrivacyOf( T... )
{
	enum PrivacyOf = PrivacyLevel.Inaccessible;
}
//----------------------------------------------------------------------------

template PrivacyOf( alias symbol )
{
	static if( __traits( compiles, __traits( getProtection, symbol ) ) )
	{
		enum PrivacyOf = cast(PrivacyLevel) __traits( getProtection, symbol );
	}
	else
	{
		enum PrivacyOf = PrivacyLevel.Inaccessible;
	}
}
//----------------------------------------------------------------------------

template PrivacyOf( T, alias name )
{
	static if( __traits( compiles, __traits( getMember, T, name ) ) )
	{
		enum PrivacyOf = PrivacyOf!( __traits( getMember, T, name ) );
	}
	else
	{
		enum PrivacyOf = PrivacyLevel.Inaccessible;
	}
}
//----------------------------------------------------------------------------

template IsExternallyAccessible( alias symbol )
{
	enum IsExternallyAccessible = PrivacyOf!( symbol ) == PrivacyLevel.Public
								|| PrivacyOf!( symbol ) == PrivacyLevel.Export;
}
//----------------------------------------------------------------------------

template IsExternallyAccessible( T, alias name )
{
	enum IsExternallyAccessible = PrivacyOf!( T, name ) == PrivacyLevel.Public
								|| PrivacyOf!( T, name ) == PrivacyLevel.Export;
}
//----------------------------------------------------------------------------

template IsAccessible( alias symbol )
{
	enum IsAccessible = PrivacyOf!( symbol ) != PrivacyLevel.Inaccessible;
}
//----------------------------------------------------------------------------

template IsAccessible( T, alias name )
{
	enum IsAccessible = PrivacyOf!( T, name ) != PrivacyLevel.Inaccessible;
}
//----------------------------------------------------------------------------

//============================================================================
