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

module binderoo.descriptorsearch;
//----------------------------------------------------------------------------

public import std.typetuple;
//----------------------------------------------------------------------------

template DescriptorsByUDA( T, alias DescriptorCollector, UDAs... )
{
	alias std.typetuple.TypeTuple Tuple;

	template hasAnyUDA( alias Desc )
	{
		template foreachuda( E... )
		{
			static if( E.length >= 1 )
			{
				static if( Desc.HasUDA!( E[ 0 ] ) )
				{
					enum foreachuda = true;
				}
				else
				{
					alias foreachuda = foreachuda!( E[ 1 .. $ ] );
				}
			}
			else
			{
				enum foreachuda = false;
			}
		}

		enum hasAnyUDA = foreachuda!( UDAs );
	}
	//------------------------------------------------------------------------

	template foreachdesc( E... )
	{
		static if ( E.length >= 1
					&& hasAnyUDA!( E[ 0 ] ) )
		{
			static if ( E.length == 1 )
			{
				alias foreachdesc = Tuple!( E[ 0 ] );
			}
			else
			{
				alias foreachdesc = Tuple!( E[ 0 ], foreachdesc!( E[1 .. $] ) );
			}
		}
		else static if ( E.length > 1 )
		{
			alias foreachdesc = foreachdesc!( E[ 1 .. $ ] );
		}
		else
		{
			alias foreachdesc = Tuple!( );
		}
	}
	//------------------------------------------------------------------------

	alias DescriptorsByUDA = foreachdesc!( DescriptorCollector!( T ) );
}
//----------------------------------------------------------------------------

//============================================================================
