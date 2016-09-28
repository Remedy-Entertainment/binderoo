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

module binderoo.math.vector;
//----------------------------------------------------------------------------

import core.simd;
import binderoo.math.constants;
//----------------------------------------------------------------------------

public enum Merge
{
	LeftMask	= 0b010000,
	RightMask	= 0b100000,
	ElemMask	= 0b001111,

	ElemX		= 0b000001,
	ElemY		= 0b000010,
	ElemZ		= 0b000100,
	ElemW		= 0b001000,

	LeftX		= LeftMask | ElemX,
	LeftY		= LeftMask | ElemY,
	LeftZ		= LeftMask | ElemZ,
	LeftW		= LeftMask | ElemW,

	RightX		= RightMask | ElemX,
	RightY		= RightMask | ElemY,
	RightZ		= RightMask | ElemZ,
	RightW		= RightMask | ElemW,
}
//----------------------------------------------------------------------------

align( 16 )
struct VectorFloat
{
	// Operator wrappers. So you can do standard arithmetic/logic things
	// and make it look natural.
	//------------------------------------------------------------------------

	pragma( inline ) VectorFloat opBinary( string op )( const( VectorFloat ) rhs ) const	if( op == "+" )	{ return add( rhs ); }
	pragma( inline ) VectorFloat opBinary( string op )( const( VectorFloat ) rhs ) const	if( op == "-" )	{ return sub( rhs ); }
	pragma( inline ) VectorFloat opBinary( string op )( const( VectorFloat ) rhs ) const	if( op == "*" )	{ return mul( rhs ); }
	pragma( inline ) VectorFloat opBinary( string op )( float rhs ) const					if( op == "*" )	{ return mul( rhs ); }
	pragma( inline ) VectorFloat opBinary( string op )( const( VectorFloat ) rhs ) const	if( op == "/" )	{ return div( rhs ); }
	pragma( inline ) VectorFloat opBinary( string op )( float rhs ) const					if( op == "/" )	{ return div( rhs ); }
	pragma( inline ) VectorFloat opBinary( string op )( const( VectorFloat ) rhs ) const	if( op == "&" )	{ return and( rhs ); }
	pragma( inline ) VectorFloat opBinary( string op )( const( VectorFloat ) rhs ) const	if( op == "|" )	{ return or( rhs ); }
	pragma( inline ) VectorFloat opBinary( string op )( const( VectorFloat ) rhs ) const	if( op == "^" )	{ return xor( rhs ); }
	pragma( inline ) VectorFloat opUnary( string op )() const								if( op == "~" )	{ return not(); }
	pragma( inline ) VectorFloat opUnary( string op )() const								if( op == "-" )	{ return negate(); }
	//------------------------------------------------------------------------

	// Vector creation
	//------------------------------------------------------------------------

	this( const( float4 ) val )
	{
		m_data = val;
	}
	//------------------------------------------------------------------------

	this( float x, float y, float z, float w = 0.0f )
	{
		m_data.array = [ x, y, z, w ];
	}
	//------------------------------------------------------------------------

	this( float val )
	{
		m_data.array = [ val, val, val, val ];
	}
	//------------------------------------------------------------------------

	// TODO: PUT IN ENUMS ONCE THE COMPILER CAN HANDLE IT
	pragma( inline ) static @property XAxis()										{ return VectorFloat( 1, 0, 0 ); }
	pragma( inline ) static @property YAxis()										{ return VectorFloat( 0, 1, 0 ); }
	pragma( inline ) static @property ZAxis()										{ return VectorFloat( 0, 0, 1 ); }
	pragma( inline ) static @property Zero()										{ return VectorFloat( 0 ); }
	pragma( inline ) static @property One()											{ return VectorFloat( 1 ); }
	//------------------------------------------------------------------------

	// Standard mathematical operations
	//------------------------------------------------------------------------

	pragma( inline ) VectorFloat negate() const
	{
		const( VectorFloat ) SIGNMASK = SignMask!( typeof( this ), true, true, true, true )();

		return VectorFloat( __simd( XMM.XORPS, m_data, SIGNMASK.m_data ) );
	}
	//------------------------------------------------------------------------

	pragma( inline ) VectorFloat abs() const
	{
		const( VectorFloat ) SIGNMASK = ~SignMask!( typeof( this ), true, true, true, true )();

		return VectorFloat( __simd( XMM.ANDPS, m_data, SIGNMASK.m_data ) );
	}
	//------------------------------------------------------------------------

	pragma( inline ) VectorFloat sqrt() const
	{
		return VectorFloat( __simd( XMM.SQRTPS, m_data ) );
	}
	//------------------------------------------------------------------------

	pragma( inline ) VectorFloat inverseSqrt() const
	{
		return VectorFloat( 1.0f ) / sqrt();
	}
	//------------------------------------------------------------------------

	pragma( inline ) VectorFloat inverseSqrt_fast()
	{
		// RSQRT only gives you 12 bits of accuracy. Intel suggests using a
		// single Newton-Raphson step to get 23 bits. Quite accurate, and
		// quicker than doing a 1/sqrt(x).

		const VectorFloat vHalf		= VectorFloat( 0.5f );
		const VectorFloat vThree		= VectorFloat( 3.0f );

		float4 vRsqrt				= __simd( XMM.RSQRTPS, m_data );
		float4 vMulWithRsqrt		= __simd( XMM.MULPS, m_data, vRsqrt );
		float4 vMulAgainWithRsqrt	= __simd( XMM.MULPS, vMulWithRsqrt, vRsqrt );
		float4 vHalfRsqrt			= __simd( XMM.MULPS, vRsqrt, vHalf.m_data );

		float4 vThreeMinusMulResult	= __simd( XMM.SUBPS, vThree.m_data, vMulAgainWithRsqrt );
		float4 vFinalResult			= __simd( XMM.MULPS, vHalfRsqrt, vThreeMinusMulResult );

		return VectorFloat( vFinalResult );
	}
	//------------------------------------------------------------------------

	pragma( inline ) VectorFloat reciprocal() const
	{
		return VectorFloat( 1.0f ) / this;
	}
	//------------------------------------------------------------------------

	pragma( inline ) VectorFloat reciprocal_fast() const
	{
		// RCP only gives you 12 bits of accuracy. Intel suggests using a
		// single Newton-Raphson	 step to get 23 bits. This restores *most* of
		// the accuracy (less than 0.0001% of precision is lost).

		float4 vReciprocalLowest	= __simd( XMM.RCPPS, m_data );
		float4 vRecipSq				= __simd( XMM.MULPS, vReciprocalLowest, vReciprocalLowest );
		float4 vRecipPlusRecip		= __simd( XMM.ADDPS, vReciprocalLowest, vReciprocalLowest );

		float4 vMulResult			= __simd( XMM.MULPS, vRecipSq, m_data );
		float4 vFinalResult			= __simd( XMM.SUBPS, vRecipPlusRecip, vMulResult );

		return VectorFloat( vFinalResult );
	}
	//------------------------------------------------------------------------

	// Arithmetic operations
	//------------------------------------------------------------------------

	pragma( inline ) VectorFloat add( const( VectorFloat ) rhs ) const
	{
		return VectorFloat( __simd( XMM.ADDPS, m_data, rhs.m_data ) );
	}
	//------------------------------------------------------------------------

	pragma( inline ) VectorFloat sub( const( VectorFloat ) rhs ) const
	{
		return VectorFloat( __simd( XMM.SUBPS, m_data, rhs.m_data ) );
	}
	//------------------------------------------------------------------------

	pragma( inline ) VectorFloat mul( const( VectorFloat ) rhs ) const
	{
		return VectorFloat( __simd( XMM.MULPS, m_data, rhs.m_data ) );
	}
	//------------------------------------------------------------------------

	pragma( inline ) VectorFloat mul( float rhs ) const
	{
		return VectorFloat( __simd( XMM.MULPS, m_data, VectorFloat( rhs ).m_data ) );
	}
	//------------------------------------------------------------------------

	pragma( inline ) VectorFloat div( const( VectorFloat ) rhs ) const
	{
		return VectorFloat( __simd( XMM.DIVPS, m_data, rhs.m_data ) );
	}
	//------------------------------------------------------------------------

	pragma( inline ) VectorFloat div( float rhs ) const
	{
		return VectorFloat( __simd( XMM.DIVPS, m_data, VectorFloat( rhs ).m_data ) );
	}
	//------------------------------------------------------------------------

	// Logical operations
	//------------------------------------------------------------------------

	pragma( inline ) VectorFloat and( const VectorFloat mask ) const
	{
		return VectorFloat( __simd( XMM.ANDPS, m_data, mask.m_data ) );
	}
	//------------------------------------------------------------------------

	pragma( inline ) VectorFloat or( const VectorFloat mask ) const
	{
		return VectorFloat( __simd( XMM.ORPS, m_data, mask.m_data ) );
	}
	//------------------------------------------------------------------------

	pragma( inline ) VectorFloat xor( const VectorFloat mask ) const
	{
		return VectorFloat( __simd( XMM.XORPS, m_data, mask.m_data ) );
	}
	//------------------------------------------------------------------------

	pragma( inline ) VectorFloat not() const
	{
		const( VectorFloat ) Mask = FullMask!( typeof( this ), true, true, true, true )();

		return VectorFloat( __simd( XMM.XORPS, m_data, Mask.m_data ) );

		return this;
	}
	//------------------------------------------------------------------------

	pragma( inline ) VectorFloat andNot( const VectorFloat mask ) const
	{
		return VectorFloat( __simd( XMM.ANDNPS, m_data, mask.m_data ) );
	}
	//------------------------------------------------------------------------

	// Three-dimensional vector operations
	//------------------------------------------------------------------------

	pragma( inline ) VectorFloat magnitude3() const
	{
		float4 vMagSq3 = __simd( XMM.DPPS, m_data, m_data, 0x7F );
		return VectorFloat( __simd( XMM.SQRTPS, vMagSq3 ) );
	}
	//------------------------------------------------------------------------

	pragma( inline ) VectorFloat magSquared3() const
	{
		return VectorFloat( __simd( XMM.DPPS, m_data, m_data, 0x7F ) );
	}
	//------------------------------------------------------------------------

	pragma( inline ) VectorFloat dot3( const( VectorFloat ) vec ) const
	{
		return VectorFloat( __simd( XMM.DPPS, m_data, vec.m_data, 0x7F ) );
	}
	//------------------------------------------------------------------------

	pragma( inline ) VectorFloat cross3( const( VectorFloat ) vec ) const
	{
		return ( this.yzxw * vec.zxyw ) - ( this.zxyw * vec.yzxw );
	}
	//------------------------------------------------------------------------

	pragma( inline ) VectorFloat normalize3() const
	{
		// TODO: bring in optimised version
		VectorFloat vMag = magnitude3();
		return this / vMag;
	}
	//------------------------------------------------------------------------

	pragma( inline ) VectorFloat length3() const									{ return magnitude3(); }
	pragma( inline ) VectorFloat lengthSquared3() const								{ return magSquared3(); }
	//------------------------------------------------------------------------

	pragma( inline ) VectorFloat distance3( const VectorFloat vec ) const			{ return ( vec - this ).magnitude3(); }
	pragma( inline ) VectorFloat distanceSquared3( const VectorFloat vec ) const	{ return ( vec - this ).magSquared3(); }
	//------------------------------------------------------------------------

	// Four dimensional vector operations
	//------------------------------------------------------------------------

	pragma( inline ) VectorFloat magnitude4() const
	{
		float4 vMagSq4 = __simd( XMM.DPPS, m_data, m_data, 0xFF );
		return VectorFloat( __simd( XMM.SQRTPS, vMagSq4 ) );
	}
	//------------------------------------------------------------------------

	pragma( inline ) VectorFloat magSquared4() const
	{
		return VectorFloat( __simd( XMM.DPPS, m_data, m_data, 0xFF ) );
	}
	//------------------------------------------------------------------------

	pragma( inline ) VectorFloat normalize4() const
	{
		// TODO: bring in optimised version
		VectorFloat vMag = magnitude4();
		return this / vMag;
	}
	//------------------------------------------------------------------------

	// Shuffling. Rather than a "traidtional" shuffle, shuffling is achieved
	// through swizzling here. You are expected to swizzle all four components
	// currently.
	//------------------------------------------------------------------------

	pragma( inline ) VectorFloat opDispatch( string swizzle )() const if( IsValidSwizzle( swizzle ) )
	{
		enum ShuffleMask = GenerateShuffle( swizzle );

		return VectorFloat( __simd( XMM.SHUFPS, m_data, m_data, ShuffleMask ) );
	}
	//------------------------------------------------------------------------

	// Merging. Only use this if you need to merge two vectors together. It
	// does support selecting one vector or the other if you need your code
	// to be generic. But in general usage, just use a swizzle instead.
	//------------------------------------------------------------------------

	pragma( inline ) VectorFloat merge( Merge e1, Merge e2, Merge e3, Merge e4 )( const VectorFloat vec ) const
	{
		// Actually trying to select an entire side.
		static if( ( e1 & Merge.LeftMask ) && ( e2 & Merge.LeftMask ) && ( e3 & Merge.LeftMask ) && ( e4 & Merge.LeftMask ) )
		{
			enum Mask = GenerateShuffle!( e1, e2, e3, e4 )();
			return VectorFloat( __simd( XMM.SHUFPS, m_data, m_data, Mask ) );
		}
		else static if( ( e1 & Merge.RightMask ) && ( e2 & Merge.RightMask ) && ( e3 & Merge.RightMask ) && ( e4 & Merge.RightMask ) )
		{
			enum Mask = GenerateShuffle!( e1, e2, e3, e4 )();
			return VectorFloat( __simd( XMM.SHUFPS, vec.m_data, vec.m_data, Mask ) );
		}

		// Mix one element in
		else static if( ( e1 & Merge.LeftMask ) && ( e2 & Merge.LeftMask ) && ( e3 & Merge.LeftMask ) && ( e4 & Merge.RightMask ) )
		{
			enum IntermediaryMask1	= GenerateShuffle!( e3, e3, e4, e4 )();
			enum IntermediaryMask2	= GenerateShuffle!( Merge.ElemX, Merge.ElemZ, Merge.ElemX, Merge.ElemZ )();
			enum FinalMask			= GenerateShuffle!( e1, e2, Merge.ElemZ, Merge.ElemW )();

			float4 intermediary1	= __simd( XMM.SHUFPS, m_data, vec.m_data, IntermediaryMask1 );
			float4 intermediary2	= __simd( XMM.SHUFPS, intermediary1, intermediary1, IntermediaryMask2 );
			return VectorFloat( __simd( XMM.SHUFPS, m_data, intermediary2, FinalMask ) );
		}
		else static if( ( e1 & Merge.LeftMask ) && ( e2 & Merge.RightMask ) && ( e3 & Merge.RightMask ) && ( e4 & Merge.RightMask ) )
		{
			enum IntermediaryMask1	= GenerateShuffle!( e1, e1, e2, e2 )();
			enum IntermediaryMask2	= GenerateShuffle!( Merge.ElemX, Merge.ElemZ, Merge.ElemX, Merge.ElemZ )();
			enum FinalMask			= GenerateShuffle!( Merge.ElemZ, Merge.ElemW, e3, e4 )();

			float4 intermediary1	= __simd( XMM.SHUFPS, m_data, vec.m_data, IntermediaryMask1 );
			float4 intermediary2	= __simd( XMM.SHUFPS, intermediary1, intermediary1, IntermediaryMask2 );
			return VectorFloat( __simd( XMM.SHUFPS, intermediary2, vec.m_data, FinalMask ) );
		}

		// Even mix
		else static if( ( e1 & Merge.LeftMask ) && ( e2 & Merge.LeftMask ) && ( e3 & Merge.RightMask ) && ( e4 & Merge.RightMask ) )
		{
			enum Mask = GenerateShuffle!( e1, e2, e3, e4 )();
			return VectorFloat( __simd( XMM.SHUFPS, m_data, vec.m_data, Mask ) );
		}
		else static if( ( e1 & Merge.RightMask ) && ( e2 & Merge.RightMask ) && ( e3 & Merge.LeftMask ) && ( e4 & Merge.LeftMask ) )
		{
			enum Mask = GenerateShuffle!( e1, e2, e3, e4 )();
			return VectorFloat( __simd( XMM.SHUFPS, vec.m_data, m_data, Mask ) );
		}

		// Need to get around to finishing the other permutations, it gets a bit messy from here on out...
		else
		{
			static assert( false, "This mixing mode is currently unsupported! ( " ~ e1.stringof ~ ", " ~ e2.stringof ~ ", " ~ e3.stringof ~ ", " ~ e4.stringof ~ " )" );
		}
		//------------------------------------------------------------------------
	}

	final this( string s ) { import std.conv : to; m_data.array = to!( float[ 4 ] )( s ); }
	final string toString() { import std.conv : to; return to!string( m_data.array ); }
	//------------------------------------------------------------------------

package:
	float4 m_data;
}
//----------------------------------------------------------------------------
//----------------------------------------------------------------------------

private:
//----------------------------------------------------------------------------

bool IsValidSwizzle( string swizzle )
{
	bool invalid = false;
	foreach( c; swizzle )
	{
		invalid |= !( c == 'x' || c == 'y' || c == 'z' || c == 'w' );
	}

	return !invalid && swizzle.length == 4;
}
//----------------------------------------------------------------------------

ubyte ComponentToIndex( char c )
{
	switch( c )
	{
		case 'x': return 0;
		case 'y': return 1;
		case 'z': return 2;
		case 'w': return 3;
		default: return 0xFF;
	}
}
//----------------------------------------------------------------------------

ubyte MergeToIndex( Merge m )
{
	switch( m & Merge.ElemMask ) with( Merge )
	{
		case ElemX: return 0;
		case ElemY: return 1;
		case ElemZ: return 2;
		case ElemW: return 3;
		default: return 0xFF;
	}
}
//----------------------------------------------------------------------------

ubyte GenerateShuffle( string swizzle )
{
	ubyte result = 0;

	foreach( iIndex, c; swizzle )
	{
		result |= ( ComponentToIndex( c ) << ( iIndex * 2 ) );
	}

	return result;
}
//----------------------------------------------------------------------------

ubyte GenerateShuffle( eMergeModes... )() if( eMergeModes.length == 4 )
{
	ubyte result = 0;

	foreach( iIndex, eMode; eMergeModes )
	{
		result |= ( MergeToIndex( eMode ) << ( iIndex * 2 ) );
	}

	return result;
}
//----------------------------------------------------------------------------

//============================================================================
