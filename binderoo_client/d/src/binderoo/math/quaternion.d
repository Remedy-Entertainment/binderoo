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

module binderoo.math.quaternion;
//----------------------------------------------------------------------------

public import binderoo.math.vector;
public import binderoo.math.angle;
import binderoo.math.constants;

import core.stdc.math;
//----------------------------------------------------------------------------

align( 16 )
struct QuaternionFloat
{
	// Operator wrappers. So you can do standard arithmetic/logic things
	// and make it look natural.
	//------------------------------------------------------------------------

	pragma( inline ) QuaternionFloat opBinary( string op )( const QuaternionFloat rhs ) const	if( op == "*" )		{ return mul( rhs ); }
	pragma( inline ) QuaternionFloat opBinary( string op )( const VectorFloat rhs ) const		if( op == "*" )		{ return mul3( rhs ); }
	pragma( inline ) QuaternionFloat opUnary( string op )() const								if( op == "-" )		{ return invert(); }
	//------------------------------------------------------------------------

	// QuaternionFloat creation
	//------------------------------------------------------------------------

	pragma( inline ) this( float x, float y, float z, float w )
	{
		m_data = VectorFloat( x, y, z, w );
	}
	//------------------------------------------------------------------------

	static pragma( inline ) QuaternionFloat createPitch( Radians fPitch )
	{
		// TODO: Bring in SIMD sin/cos

		float fHalf = fPitch * 0.5f;

		float fSin = sinf( fHalf );
		float fCos = cosf( fHalf );

		return QuaternionFloat( fSin, 0.0f, 0.0f, fCos );
	}
	//------------------------------------------------------------------------

	static pragma( inline ) QuaternionFloat createYaw( Radians fYaw )
	{
		// TODO: Bring in SIMD sin/cos

		float fHalf = fYaw * 0.5f;

		float fSin = sinf( fHalf );
		float fCos = cosf( fHalf );

		return QuaternionFloat( 0.0f, fSin, 0.0f, fCos );
	}
	//------------------------------------------------------------------------

	static pragma( inline ) QuaternionFloat createRoll( Radians fRoll )
	{
		// TODO: Bring in SIMD sin/cos

		float fHalf = fRoll * 0.5f;

		float fSin = sinf( fHalf );
		float fCos = cosf( fHalf );

		return QuaternionFloat( 0.0f, 0.0f, fSin, fCos );
	}
	//------------------------------------------------------------------------

	static pragma( inline ) QuaternionFloat createFromAxisAngle( const VectorFloat vAxis, Radians fAngle )
	{
		// TODO: Bring in SIMD sin/cos

		float fHalf = fAngle * 0.5f;

		float fSin = sinf( fHalf );
		float fCos = cosf( fHalf );

		return QuaternionFloat( ( vAxis * fSin ).merge!( Merge.LeftX, Merge.LeftY, Merge.LeftZ, Merge.RightW )( VectorFloat( fCos ) ) );
	}
	//------------------------------------------------------------------------

	static pragma( inline ) QuaternionFloat createPitch( Degrees fPitch )		{ return createPitch( fPitch.rad ); }
	static pragma( inline ) QuaternionFloat createYaw( Degrees fYaw )			{ return createYaw( fYaw.rad ); }
	static pragma( inline ) QuaternionFloat createRoll( Degrees fRoll )			{ return createRoll( fRoll.rad ); }
	static pragma( inline ) QuaternionFloat createFromAxisAngle( const VectorFloat vAxis, Degrees fAngle ) { return createFromAxisAngle( vAxis, fAngle.rad ); }
	//------------------------------------------------------------------------

	static pragma( inline ) QuaternionFloat identity()
	{
		return QuaternionFloat( 0.0, 0.0, 0.0, 1.0 );
	}
	//------------------------------------------------------------------------

	pragma( inline ) QuaternionFloat mul( const QuaternionFloat rhs ) const
	{
		const VectorFloat vThisW				= m_data.wwww;
		const VectorFloat vOtherW				= rhs.m_data.wwww;

		const VectorFloat vDotXYZ				= m_data.dot3( rhs.m_data );
		const VectorFloat vNewW					= vThisW * vOtherW - vDotXYZ;

		const VectorFloat vThisScaledVec		= m_data * vOtherW;
		const VectorFloat vOtherScaledVec		= rhs.m_data * vThisW;
		const VectorFloat vCrossXYZ				= m_data.cross3( rhs.m_data );

		const VectorFloat vXYZResult			= vThisScaledVec + vOtherScaledVec + vCrossXYZ;

		const VectorFloat vResult				= vXYZResult.merge!( Merge.LeftX, Merge.LeftY, Merge.LeftZ, Merge.RightW )( vNewW );

		return QuaternionFloat( vResult );
	}
	//------------------------------------------------------------------------

	pragma( inline ) QuaternionFloat mul3( const VectorFloat rhs ) const
	{
		// https://blog.molecular-matters.com/2013/05/24/a-faster-quaternion-vector-multiplication/

		const VectorFloat vWComponent			= m_data.wwww;
		const VectorFloat vTwo					= VectorFloat( 2.0f, 2.0, 2.0f, 0.0f );

		const VectorFloat vT					= vTwo * m_data.cross3( rhs );
		const VectorFloat vResult				= rhs + ( vWComponent * vT ) + m_data.cross3( vT );

		return QuaternionFloat( vResult );

	}
	//------------------------------------------------------------------------

	pragma( inline ) QuaternionFloat invert() const
	{
		return QuaternionFloat( m_data ^ SignMask!( VectorFloat, true, true, true, false )() );
	}
	//------------------------------------------------------------------------

	pragma( inline ) QuaternionFloat normalize() const
	{
		return QuaternionFloat( m_data.normalize4() );
	}
	//------------------------------------------------------------------------

	final this( string s )			{ m_data = VectorFloat( s ); }
	final string toString()			{ return m_data.toString(); }
	//------------------------------------------------------------------------

private:
	VectorFloat m_data = VectorFloat( 0.0, 0.0, 0.0, 1.0 );

	this( VectorFloat data )
	{
		m_data = data;
	}
	//------------------------------------------------------------------------
}
//----------------------------------------------------------------------------

//============================================================================
