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

module binderoo.math.angle;
//----------------------------------------------------------------------------

struct Degrees
{
	enum max = Degrees( 180.0f );
	enum min = Degrees( -180.0f );

	package this( float fSomeFloatValue )
	{
		m_data = fSomeFloatValue;
	}
	//------------------------------------------------------------------------

	package void opAssign( float fSomeFloatValue )
	{
		m_data = fSomeFloatValue;
	}
	//------------------------------------------------------------------------

	this( Radians rRadians )
	{
		m_data = ToDegrees( rRadians ).m_data;
	}
	//------------------------------------------------------------------------

	void opAssign( Radians rRadians )
	{
		m_data = ToDegrees( rRadians ).m_data;
	}
	//------------------------------------------------------------------------

	Degrees opUnary( string s )() if( s == "-" )
	{
		return Degrees( -m_data );
	}
	//------------------------------------------------------------------------

	Degrees opBinary( string s )( float rhs ) if( s == "*" || s == "/" )
	{
		mixin( "return Degrees( m_data " ~ s ~ " rhs );" );
	}
	//------------------------------------------------------------------------

	string toString()
	{
		return floatToStringSimple( m_data ) ~ ".deg";
	}
	//------------------------------------------------------------------------

	final this( string val )
	{
		import std.string : endsWith;
		import std.conv : to;
		if( val.endsWith( ".deg" ) )
		{
			m_data = to!float( val[ 0 .. $ - 4 ] );
		}
		else if( val.endsWith( ".rad" ) )
		{
			m_data = to!float( val[ 0 .. $ - 4 ] ).deg.m_data;
		}
	}
	//------------------------------------------------------------------------

	float	m_data = 0.0f;
	alias	m_data this;
}
//----------------------------------------------------------------------------

struct Radians
{
	enum max = Radians( 3.1415926f );
	enum min = Radians( -3.14159260f );

	package this( float fSomeFloatValue )
	{
		m_data = fSomeFloatValue;
	}
	//------------------------------------------------------------------------

	package void opAssign( float fSomeFloatValue )
	{
		m_data = fSomeFloatValue;
	}
	//------------------------------------------------------------------------

	this( Degrees dDegrees )
	{
		m_data = ToRadians( dDegrees ).m_data;
	}
	//------------------------------------------------------------------------

	void opAssign( Degrees dDegrees )
	{
		m_data = ToRadians( dDegrees ).m_data;
	}
	//------------------------------------------------------------------------

	Radians opUnary( string s )() if( s == "-" )
	{
		return Radians( -m_data );
	}
	//------------------------------------------------------------------------

	Radians opBinary( string s )( float rhs ) if( s == "*" || s == "/" )
	{
		mixin( "return Radians( m_data " ~ s ~ " rhs );" );
	}
	//------------------------------------------------------------------------

	final string toString()
	{
		return floatToStringSimple( m_data ) ~ ".rad";
	}
	//------------------------------------------------------------------------

	final this( string val )
	{
		import std.string : endsWith;
		import std.conv : to;
		if( val.endsWith( ".rad" ) )
		{
			m_data = to!float( val[ 0 .. $ - 4 ] );
		}
		else if( val.endsWith( ".deg" ) )
		{
			m_data = to!float( val[ 0 .. $ - 4 ] ).rad.m_data;
		}
	}
	//------------------------------------------------------------------------

	float	m_data = 0.0f;
	alias	m_data this;
}
//----------------------------------------------------------------------------

pragma( inline ) auto ToRadians( T )( T val )
{
	return cast( T )( val * 0.01745329251994329576923690768489 );
}
//----------------------------------------------------------------------------

pragma( inline ) auto ToRadians( T : Degrees )( T val )
{
	return Radians( val.m_data * 0.01745329251994329576923690768489 );
}
//----------------------------------------------------------------------------

pragma( inline ) auto ToRadians( T : Radians )( T val )
{
	return val;
}
//----------------------------------------------------------------------------

pragma( inline ) auto ToDegrees( T )( T val )
{
	return cast( T )( val * 57.295779513082320876798154814105 );
}
//----------------------------------------------------------------------------

pragma( inline ) auto ToDegrees( T : Degrees )( T val )
{
	return val;
}
//----------------------------------------------------------------------------

pragma( inline ) auto ToDegrees( T : Radians )( T val )
{
	return Degrees( val.m_data * 57.295779513082320876798154814105 );
}
//----------------------------------------------------------------------------

pragma( inline ) auto deg( float fDegrees )
{
	return Degrees( fDegrees );
}
//----------------------------------------------------------------------------

pragma( inline ) auto deg( Radians radians )
{
	return ToDegrees( radians );
}
//----------------------------------------------------------------------------

pragma( inline ) auto deg( Degrees degrees )
{
	return degrees;
}
//----------------------------------------------------------------------------

pragma( inline ) auto rad( float fRadians )
{
	return Radians( fRadians );
}
//----------------------------------------------------------------------------

pragma( inline ) auto rad( Radians radians )
{
	return radians;
}
//----------------------------------------------------------------------------

pragma( inline ) auto rad( Degrees degrees )
{
	return ToRadians( degrees );
}
//----------------------------------------------------------------------------
//----------------------------------------------------------------------------

// Don't go any further if you value your sanity.
//----------------------------------------------------------------------------
//----------------------------------------------------------------------------

// No. Seriously.
//----------------------------------------------------------------------------
//----------------------------------------------------------------------------

// ...alright then.
//----------------------------------------------------------------------------
//----------------------------------------------------------------------------

// Works at CTFE. Exactly what we want.
string floatToStringSimple( float val )
{
	string output;

	int major = cast( int )val;
	int minor = cast( int )( ( val % 1 ) * 10000000.0f );

	if( major < 0 )
	{
		output ~= '-';
		major = -major;
		minor = -minor;
	}

	if( major == 0 )
	{
		output ~= '0';
	}

	string working = "";
	while( major > 0 )
	{
		working ~= cast( char )( major % 10 ) + '0';
		major /= 10;
	}

	foreach_reverse( c; working ) output ~= c;

	if( minor > 0 )
	{
		output ~= '.';

		working = "";
		while( minor > 0 )
		{
			working ~= cast( char )( minor % 10 ) + '0';
			minor /= 10;
		}

		while( working[ 0 ] == '0' )
		{
			working = working[ 1 .. $ ];
		}

		foreach_reverse( c; working ) output ~= c;
	}
	
	return output;
}
//----------------------------------------------------------------------------

//============================================================================
