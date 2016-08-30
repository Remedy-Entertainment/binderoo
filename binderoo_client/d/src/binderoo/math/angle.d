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

enum Pi( T : float ) = 3.141592654f;
enum Pi( T : double ) = 3.141592653589793238;
//----------------------------------------------------------------------------

enum HalfPi( T ) = Pi!T * T( 0.5 );
enum QuarterPi( T ) = Pi!T * T( 0.25 );
//----------------------------------------------------------------------------

enum PercentOfPi( T, T percent ) = Pi!T * percent;
//----------------------------------------------------------------------------

struct Degrees
{
	float	m_data = 0.0f;
	alias	m_data this;
}
//----------------------------------------------------------------------------

struct Radians
{
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

//============================================================================
