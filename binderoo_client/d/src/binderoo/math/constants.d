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

module binderoo.math.constants;
//----------------------------------------------------------------------------

import binderoo.math.vector;
import binderoo.traits;
//----------------------------------------------------------------------------

enum Pi( T : float ) = 3.141592654f;
enum Pi( T : double ) = 3.141592653589793238;
//----------------------------------------------------------------------------

enum HalfPi( T ) = Pi!T * T( 0.5 );
enum QuarterPi( T ) = Pi!T * T( 0.25 );
//----------------------------------------------------------------------------

enum PercentOfPi( T, T percent ) = Pi!T * percent;
//----------------------------------------------------------------------------

enum Pi( T : VectorFloat ) = SIMDVector( Pi!float );
//----------------------------------------------------------------------------

auto SignMask( InputType, bool e1 = true, bool e2 = true, bool e3 = true, bool e4 = true )()
{
	enum Mask32Bit = 0x80000000;
	enum Mask64Bit = 0x8000000000000000L;

	import binderoo.math.vector;

	static if( is( Unqualified!( InputType ) == VectorFloat ) )
	{
		// This *should* CTFE once all bugs are fixed in the compiler

		alias VectorType = Unqualified!( typeof( InputType.m_data ) );
		alias VectorArrayType = TemplateParametersOf!( VectorType )[ 0 ];
		alias PrimitiveType = ArrayType!( VectorArrayType );
	
		template Mask( bool bTrue )
		{
			auto GenerateMask()
			{
				static if( is( PrimitiveType == double ) )
				{
					long val = bTrue ? Mask64Bit : 0L;
					return *cast(double*)&val;
				}
				else
				{
					int val = bTrue ? Mask32Bit : 0;
					return *cast(int*)&val;
				}
			}
	
			enum Mask = GenerateMask();
		}
	
		auto GenerateConstant()
		{
			static if(	is( PrimitiveType == float )
						|| is( PrimitiveType == int ) )
			{
				enum Mask1 = Mask!e1;
				enum Mask2 = Mask!e2;
				enum Mask3 = Mask!e3;
				enum Mask4 = Mask!e4;
	
				VectorType vec;
				vec.array = [ Mask1, Mask2, Mask3, Mask4 ];
				return InputType( vec );
			}
			else static if( is( PrimitiveType == double ) )
			{
				enum Mask1 = Mask!e1;
				enum Mask2 = Mask!e2;
	
				VectorType vec;
				vec.array = [ Mask1, Mask2 ];
				return InputType( vec );
			}
			else
			{
				static assert( false, "Invalid primitive type " ~ PrimitiveType.stringof ~ " for vector mask!" );
			}
		}
	}
	else static if( __traits( isArithmetic, InputType ) )
	{
		static if( e1 == false )
		{
			auto GenerateConstant() { return cast( InputType ) 0; }
		}
		else static if ( __traits( isUnsigned, InputType ) )
		{
			auto GenerateConstant() { return InputType.init; }
		}
		else static if( __traits( isFloating, InputType ) )
		{
			auto GenerateConstant()
			{
				static if( is( InputType == double ) )
				{
					long val = e1 ? Mask64Bit : 0L;
					return *cast(double*)&val;
				}
				else
				{
					int val = e1 ? Mask32Bit : 0;
					return *cast(float*)&val;
				}
			}
		}
		else
		{
			auto GenerateConstant() { enum ReturnVal = 1 << ( (InputType.sizeof * 8) - 1); return cast(InputType) ReturnVal; }
		}
	}
	else
	{
		static assert( false, "Type " ~ InputType.stringof ~ " cannot generate a mask!" );
	}

	return GenerateConstant();
}
//----------------------------------------------------------------------------

auto FullMask( InputType, bool e1 = true, bool e2 = true, bool e3 = true, bool e4 = true )()
{
	enum Mask32Bit = 0xFFFFFFFF;
	enum Mask64Bit = 0xFFFFFFFFFFFFFFFFL;

	import binderoo.math.vector;

	static if( is( Unqualified!( InputType ) == VectorFloat ) )
	{
		// This *should* CTFE once all bugs are fixed in the compiler

		alias VectorType = Unqualified!( typeof( InputType.m_data ) );
		alias VectorArrayType = TemplateParametersOf!( VectorType )[ 0 ];
		alias PrimitiveType = ArrayType!( VectorArrayType );

		template Mask( bool bTrue )
		{
			auto GenerateMask()
			{
				static if( is( PrimitiveType == double ) )
				{
					long val = bTrue ? Mask64Bit : 0L;
					return *cast(PrimitiveType*)&val;
				}
				else
				{
					int val = bTrue ? Mask32Bit : 0;
					return *cast(PrimitiveType*)&val;
				}
			}

			enum Mask = GenerateMask();
		}

		auto GenerateConstant()
		{
			static if(	is( PrimitiveType == float )
						|| is( PrimitiveType == int ) )
			{
				VectorType vec;
				vec.array = [ Mask!e1, Mask!e2, Mask!e3, Mask!e4 ];
				return InputType( vec );
			}
			else static if( is( PrimitiveType == double ) )
			{
				VectorType vec;
				vec.array = [ Mask!e1, Mask!e2 ];
				return InputType( vec );
			}
			else
			{
				static assert( false, "Invalid primitive type " ~ PrimitiveType.stringof ~ " for vector mask!" );
			}
		}
	}
	else static if( __traits( isArithmetic, InputType ) )
	{
		static if( e1 == false )
		{
			auto GenerateConstant() { return cast( InputType ) 0; }
		}
		else static if( __traits( isFloating, InputType ) )
		{
			auto GenerateConstant()
			{
				static if( is( InputType == double ) )
				{
					long val = e1 ? Mask64Bit : 0L;
					return *cast(double*)&val;
				}
				else
				{
					int val = e1 ? Mask32Bit : 0;
					return *cast(float*)&val;
				}
			}
		}
		else
		{
			auto GenerateConstant() { enum ReturnVal = InputType.min | InputType.max; return cast(InputType) ReturnVal; }
		}
	}
	else
	{
		static assert( false, "Type " ~ InputType.stringof ~ " cannot generate a mask!" );
	}
	return GenerateConstant();
}
//----------------------------------------------------------------------------

//============================================================================
