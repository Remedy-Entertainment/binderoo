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

// VS2012 is in a weird "Some C++11 support but not the stuff that matters"
// zone, so a pre-C++11 method is required to support FunctionTraits

#define MIXIN_ARGTEMPLATE_ARG( uIndex, argType ) template< > struct arg< uIndex > { typedef typename argType type; }
#define MIXIN_ARGTEMPLATE_RAW( uIndex, argType ) template< > struct rawarg< uIndex > { typedef typename argType type; }

#define MIXIN_ARGTEMPLATE_FUNCTION( uIndex, argType ) MIXIN_ARGTEMPLATE_ARG( uIndex, argType ); MIXIN_ARGTEMPLATE_RAW( uIndex, argType )
#define MIXIN_ARGTEMPLATE_METHOD( uIndex, argType ) MIXIN_ARGTEMPLATE_ARG( uIndex, argType ); MIXIN_ARGTEMPLATE_RAW( ( uIndex + 1 ), argType )

#define MIXIN_ARGTEMPLATE_FUNCTIONDEFINITION template< size_t uIndex > struct arg { typedef void type; static_assert( uIndex >= 0 && uIndex < num_args, "Invalid argument index provided" ); }; template< size_t uIndex > struct rawarg { typedef void type; static_assert( uIndex >= 0 && uIndex < num_raw_args, "Invalid argument index provided" ); }
#define MIXIN_ARGTEMPLATE_METHODDEFINITION( objType ) MIXIN_ARGTEMPLATE_FUNCTIONDEFINITION; template< > struct rawarg< 0 > { typedef typename objType* const type; }
//----------------------------------------------------------------------------

#define MIXIN_ARGTEMPLATE_FUNCTION1( p1 ) MIXIN_ARGTEMPLATE_FUNCTIONDEFINITION; \
MIXIN_ARGTEMPLATE_FUNCTION( 0, p1 )

#define MIXIN_ARGTEMPLATE_FUNCTION2( p1, p2 ) MIXIN_ARGTEMPLATE_FUNCTIONDEFINITION; \
MIXIN_ARGTEMPLATE_FUNCTION( 0, p1 ); \
MIXIN_ARGTEMPLATE_FUNCTION( 1, p2 )

#define MIXIN_ARGTEMPLATE_FUNCTION3( p1, p2, p3 ) MIXIN_ARGTEMPLATE_FUNCTIONDEFINITION; \
MIXIN_ARGTEMPLATE_FUNCTION( 0, p1 ); \
MIXIN_ARGTEMPLATE_FUNCTION( 1, p2 ); \
MIXIN_ARGTEMPLATE_FUNCTION( 2, p3 )

#define MIXIN_ARGTEMPLATE_FUNCTION4( p1, p2, p3, p4 ) MIXIN_ARGTEMPLATE_FUNCTIONDEFINITION; \
MIXIN_ARGTEMPLATE_FUNCTION( 0, p1 ); \
MIXIN_ARGTEMPLATE_FUNCTION( 1, p2 ); \
MIXIN_ARGTEMPLATE_FUNCTION( 2, p3 ); \
MIXIN_ARGTEMPLATE_FUNCTION( 3, p4 )

#define MIXIN_ARGTEMPLATE_FUNCTION5( p1, p2, p3, p4, p5 ) MIXIN_ARGTEMPLATE_FUNCTIONDEFINITION; \
MIXIN_ARGTEMPLATE_FUNCTION( 0, p1 ); \
MIXIN_ARGTEMPLATE_FUNCTION( 1, p2 ); \
MIXIN_ARGTEMPLATE_FUNCTION( 2, p3 ); \
MIXIN_ARGTEMPLATE_FUNCTION( 3, p4 ); \
MIXIN_ARGTEMPLATE_FUNCTION( 4, p5 )

#define MIXIN_ARGTEMPLATE_FUNCTION6( p1, p2, p3, p4, p5, p6 ) MIXIN_ARGTEMPLATE_FUNCTIONDEFINITION; \
MIXIN_ARGTEMPLATE_FUNCTION( 0, p1 ); \
MIXIN_ARGTEMPLATE_FUNCTION( 1, p2 ); \
MIXIN_ARGTEMPLATE_FUNCTION( 2, p3 ); \
MIXIN_ARGTEMPLATE_FUNCTION( 3, p4 ); \
MIXIN_ARGTEMPLATE_FUNCTION( 4, p5 ); \
MIXIN_ARGTEMPLATE_FUNCTION( 5, p6 )

#define MIXIN_ARGTEMPLATE_FUNCTION7( p1, p2, p3, p4, p5, p6, p7 ) MIXIN_ARGTEMPLATE_FUNCTIONDEFINITION; \
MIXIN_ARGTEMPLATE_FUNCTION( 0, p1 ); \
MIXIN_ARGTEMPLATE_FUNCTION( 1, p2 ); \
MIXIN_ARGTEMPLATE_FUNCTION( 2, p3 ); \
MIXIN_ARGTEMPLATE_FUNCTION( 3, p4 ); \
MIXIN_ARGTEMPLATE_FUNCTION( 4, p5 ); \
MIXIN_ARGTEMPLATE_FUNCTION( 5, p6 ); \
MIXIN_ARGTEMPLATE_FUNCTION( 6, p7 )

#define MIXIN_ARGTEMPLATE_FUNCTION8( p1, p2, p3, p4, p5, p6, p7, p8 ) MIXIN_ARGTEMPLATE_FUNCTIONDEFINITION; \
MIXIN_ARGTEMPLATE_FUNCTION( 0, p1 ); \
MIXIN_ARGTEMPLATE_FUNCTION( 1, p2 ); \
MIXIN_ARGTEMPLATE_FUNCTION( 2, p3 ); \
MIXIN_ARGTEMPLATE_FUNCTION( 3, p4 ); \
MIXIN_ARGTEMPLATE_FUNCTION( 4, p5 ); \
MIXIN_ARGTEMPLATE_FUNCTION( 5, p6 ); \
MIXIN_ARGTEMPLATE_FUNCTION( 6, p7 ); \
MIXIN_ARGTEMPLATE_FUNCTION( 7, p8 )

#define MIXIN_ARGTEMPLATE_FUNCTION9( p1, p2, p3, p4, p5, p6, p7, p8, p9 ) MIXIN_ARGTEMPLATE_FUNCTIONDEFINITION; \
MIXIN_ARGTEMPLATE_FUNCTION( 0, p1 ); \
MIXIN_ARGTEMPLATE_FUNCTION( 1, p2 ); \
MIXIN_ARGTEMPLATE_FUNCTION( 2, p3 ); \
MIXIN_ARGTEMPLATE_FUNCTION( 3, p4 ); \
MIXIN_ARGTEMPLATE_FUNCTION( 4, p5 ); \
MIXIN_ARGTEMPLATE_FUNCTION( 5, p6 ); \
MIXIN_ARGTEMPLATE_FUNCTION( 6, p7 ); \
MIXIN_ARGTEMPLATE_FUNCTION( 7, p8 ); \
MIXIN_ARGTEMPLATE_FUNCTION( 8, p9 )
//----------------------------------------------------------------------------

#define MIXIN_ARGTEMPLATE_METHOD1( obj, p1 ) MIXIN_ARGTEMPLATE_METHODDEFINITION( obj ); \
MIXIN_ARGTEMPLATE_METHOD( 0, p1 )

#define MIXIN_ARGTEMPLATE_METHOD2( obj, p1, p2 ) MIXIN_ARGTEMPLATE_METHODDEFINITION( obj ); \
MIXIN_ARGTEMPLATE_METHOD( 0, p1 ); \
MIXIN_ARGTEMPLATE_METHOD( 1, p2 )

#define MIXIN_ARGTEMPLATE_METHOD3( obj, p1, p2, p3 ) MIXIN_ARGTEMPLATE_METHODDEFINITION( obj ); \
MIXIN_ARGTEMPLATE_METHOD( 0, p1 ); \
MIXIN_ARGTEMPLATE_METHOD( 1, p2 ); \
MIXIN_ARGTEMPLATE_METHOD( 2, p3 )

#define MIXIN_ARGTEMPLATE_METHOD4( obj, p1, p2, p3, p4 ) MIXIN_ARGTEMPLATE_METHODDEFINITION( obj ); \
MIXIN_ARGTEMPLATE_METHOD( 0, p1 ); \
MIXIN_ARGTEMPLATE_METHOD( 1, p2 ); \
MIXIN_ARGTEMPLATE_METHOD( 2, p3 ); \
MIXIN_ARGTEMPLATE_METHOD( 3, p4 )

#define MIXIN_ARGTEMPLATE_METHOD5( obj, p1, p2, p3, p4, p5 ) MIXIN_ARGTEMPLATE_METHODDEFINITION( obj ); \
MIXIN_ARGTEMPLATE_METHOD( 0, p1 ); \
MIXIN_ARGTEMPLATE_METHOD( 1, p2 ); \
MIXIN_ARGTEMPLATE_METHOD( 2, p3 ); \
MIXIN_ARGTEMPLATE_METHOD( 3, p4 ); \
MIXIN_ARGTEMPLATE_METHOD( 4, p5 )

#define MIXIN_ARGTEMPLATE_METHOD6( obj, p1, p2, p3, p4, p5, p6 ) MIXIN_ARGTEMPLATE_METHODDEFINITION( obj ); \
MIXIN_ARGTEMPLATE_METHOD( 0, p1 ); \
MIXIN_ARGTEMPLATE_METHOD( 1, p2 ); \
MIXIN_ARGTEMPLATE_METHOD( 2, p3 ); \
MIXIN_ARGTEMPLATE_METHOD( 3, p4 ); \
MIXIN_ARGTEMPLATE_METHOD( 4, p5 ); \
MIXIN_ARGTEMPLATE_METHOD( 5, p6 )

#define MIXIN_ARGTEMPLATE_METHOD7( obj, p1, p2, p3, p4, p5, p6, p7 ) MIXIN_ARGTEMPLATE_METHODDEFINITION( obj ); \
MIXIN_ARGTEMPLATE_METHOD( 0, p1 ); \
MIXIN_ARGTEMPLATE_METHOD( 1, p2 ); \
MIXIN_ARGTEMPLATE_METHOD( 2, p3 ); \
MIXIN_ARGTEMPLATE_METHOD( 3, p4 ); \
MIXIN_ARGTEMPLATE_METHOD( 4, p5 ); \
MIXIN_ARGTEMPLATE_METHOD( 5, p6 ); \
MIXIN_ARGTEMPLATE_METHOD( 6, p7 )

#define MIXIN_ARGTEMPLATE_METHOD8( obj, p1, p2, p3, p4, p5, p6, p7, p8 ) MIXIN_ARGTEMPLATE_METHODDEFINITION( obj ); \
MIXIN_ARGTEMPLATE_METHOD( 0, p1 ); \
MIXIN_ARGTEMPLATE_METHOD( 1, p2 ); \
MIXIN_ARGTEMPLATE_METHOD( 2, p3 ); \
MIXIN_ARGTEMPLATE_METHOD( 3, p4 ); \
MIXIN_ARGTEMPLATE_METHOD( 4, p5 ); \
MIXIN_ARGTEMPLATE_METHOD( 5, p6 ); \
MIXIN_ARGTEMPLATE_METHOD( 6, p7 ); \
MIXIN_ARGTEMPLATE_METHOD( 7, p8 )

#define MIXIN_ARGTEMPLATE_METHOD9( obj, p1, p2, p3, p4, p5, p6, p7, p8, p9 ) MIXIN_ARGTEMPLATE_METHODDEFINITION( obj ); \
MIXIN_ARGTEMPLATE_METHOD( 0, p1 ); \
MIXIN_ARGTEMPLATE_METHOD( 1, p2 ); \
MIXIN_ARGTEMPLATE_METHOD( 2, p3 ); \
MIXIN_ARGTEMPLATE_METHOD( 3, p4 ); \
MIXIN_ARGTEMPLATE_METHOD( 4, p5 ); \
MIXIN_ARGTEMPLATE_METHOD( 5, p6 ); \
MIXIN_ARGTEMPLATE_METHOD( 6, p7 ); \
MIXIN_ARGTEMPLATE_METHOD( 7, p8 ); \
MIXIN_ARGTEMPLATE_METHOD( 8, p9 )
//----------------------------------------------------------------------------
//----------------------------------------------------------------------------

namespace binderoo
{
namespace functiontraits
{
	template< typename _ty >
	struct Implementation
	{
		Implementation()
		{
			cause_an_error_please;
		}
	};
	//------------------------------------------------------------------------

	// Plain old ordinary function
	template< typename _retType >
	struct Implementation< _retType( * )( ) >
	{
		typedef typename _retType							return_type;
		typedef void										object_type;
		typedef return_type( * signature )( );
		typedef signature									raw_signature;

		static const size_t									num_args = 0;
		static const size_t									num_raw_args = 0;
		static const bool									is_member_method = false;
		static const bool									is_const_method = false;
	};
	//------------------------------------------------------------------------

	template< typename _retType, typename p1 >
	struct Implementation< _retType( * )( p1 ) >
	{
		typedef typename _retType							return_type;
		typedef void										object_type;
		typedef return_type( * signature )( p1 );
		typedef signature									raw_signature;

		static const size_t									num_args = 1;
		static const size_t									num_raw_args = 1;
		static const bool									is_member_method = false;
		static const bool									is_const_method = false;

		MIXIN_ARGTEMPLATE_FUNCTION1( p1 );
	};
	//------------------------------------------------------------------------

	template< typename _retType, typename p1, typename p2 >
	struct Implementation< _retType( * )( p1, p2 ) >
	{
		typedef typename _retType							return_type;
		typedef void										object_type;
		typedef return_type( * signature )( p1, p2 );
		typedef signature									raw_signature;

		static const size_t									num_args = 2;
		static const size_t									num_raw_args = 2;
		static const bool									is_member_method = false;
		static const bool									is_const_method = false;

		MIXIN_ARGTEMPLATE_FUNCTION2( p1, p2 );
	};
	//------------------------------------------------------------------------

	template< typename _retType, typename p1, typename p2, typename p3 >
	struct Implementation< _retType( * )( p1, p2, p3 ) >
	{
		typedef typename _retType							return_type;
		typedef void										object_type;
		typedef return_type( * signature )( p1, p2, p3 );
		typedef signature									raw_signature;

		static const size_t									num_args = 3;
		static const size_t									num_raw_args = 3;
		static const bool									is_member_method = false;
		static const bool									is_const_method = false;

		MIXIN_ARGTEMPLATE_FUNCTION3( p1, p2, p3 );
	};
	//------------------------------------------------------------------------

	template< typename _retType, typename p1, typename p2, typename p3, typename p4 >
	struct Implementation< _retType( * )( p1, p2, p3, p4 ) >
	{
		typedef typename _retType							return_type;
		typedef void										object_type;
		typedef return_type( * signature )( p1, p2, p3, p4 );
		typedef signature									raw_signature;

		static const size_t									num_args = 4;
		static const size_t									num_raw_args = 4;
		static const bool									is_member_method = false;
		static const bool									is_const_method = false;

		MIXIN_ARGTEMPLATE_FUNCTION4( p1, p2, p3, p4 );
	};
	//------------------------------------------------------------------------

	template< typename _retType, typename p1, typename p2, typename p3, typename p4, typename p5 >
	struct Implementation< _retType( * )( p1, p2, p3, p4, p5 ) >
	{
		typedef typename _retType							return_type;
		typedef void										object_type;
		typedef return_type( * signature )( p1, p2, p3, p4, p5 );
		typedef signature									raw_signature;

		static const size_t									num_args = 5;
		static const size_t									num_raw_args = 5;
		static const bool									is_member_method = false;
		static const bool									is_const_method = false;

		MIXIN_ARGTEMPLATE_FUNCTION5( p1, p2, p3, p4, p5 );
	};
	//------------------------------------------------------------------------

	template< typename _retType, typename p1, typename p2, typename p3, typename p4, typename p5, typename p6 >
	struct Implementation< _retType( * )( p1, p2, p3, p4, p5, p6 ) >
	{
		typedef typename _retType							return_type;
		typedef void										object_type;
		typedef return_type( * signature )( p1, p2, p3, p4, p5, p6 );
		typedef signature									raw_signature;

		static const size_t									num_args = 6;
		static const size_t									num_raw_args = 6;
		static const bool									is_member_method = false;
		static const bool									is_const_method = false;

		MIXIN_ARGTEMPLATE_FUNCTION6( p1, p2, p3, p4, p5, p6 );
	};
	//------------------------------------------------------------------------

	template< typename _retType, typename p1, typename p2, typename p3, typename p4, typename p5, typename p6, typename p7 >
	struct Implementation< _retType( * )( p1, p2, p3, p4, p5, p6, p7 ) >
	{
		typedef typename _retType							return_type;
		typedef void										object_type;
		typedef return_type( * signature )( p1, p2, p3, p4, p5, p6, p7 );
		typedef signature									raw_signature;

		static const size_t									num_args = 7;
		static const size_t									num_raw_args = 7;
		static const bool									is_member_method = false;
		static const bool									is_const_method = false;

		MIXIN_ARGTEMPLATE_FUNCTION7( p1, p2, p3, p4, p5, p6, p7 );
	};
	//------------------------------------------------------------------------

	template< typename _retType, typename p1, typename p2, typename p3, typename p4, typename p5, typename p6, typename p7, typename p8 >
	struct Implementation< _retType( * )( p1, p2, p3, p4, p5, p6, p7, p8 ) >
	{
		typedef typename _retType							return_type;
		typedef void										object_type;
		typedef return_type( * signature )( p1, p2, p3, p4, p5, p6, p7, p8 );
		typedef signature									raw_signature;

		static const size_t									num_args = 8;
		static const size_t									num_raw_args = 8;
		static const bool									is_member_method = false;
		static const bool									is_const_method = false;

		MIXIN_ARGTEMPLATE_FUNCTION8( p1, p2, p3, p4, p5, p6, p7, p8 );
	};
	//------------------------------------------------------------------------

	template< typename _retType, typename p1, typename p2, typename p3, typename p4, typename p5, typename p6, typename p7, typename p8, typename p9 >
	struct Implementation< _retType( * )( p1, p2, p3, p4, p5, p6, p7, p8, p9 ) >
	{
		typedef typename _retType							return_type;
		typedef void										object_type;
		typedef return_type( * signature )( p1, p2, p3, p4, p5, p6, p7, p8, p9 );
		typedef signature									raw_signature;

		static const size_t									num_args = 9;
		static const size_t									num_raw_args = 9;
		static const bool									is_member_method = false;
		static const bool									is_const_method = false;

		MIXIN_ARGTEMPLATE_FUNCTION9( p1, p2, p3, p4, p5, p6, p7, p8, p9 );
	};
	//------------------------------------------------------------------------
	//------------------------------------------------------------------------

	// Class member functions
	template< typename _retType, typename _objType >
	struct Implementation< _retType( _objType::* )( ) >
	{
		typedef typename _retType							return_type;
		typedef typename _objType							object_type;
		typedef return_type( object_type::* signature )( );
		typedef return_type( * raw_signature )( object_type* const );

		static const size_t									num_args = 0;
		static const size_t									num_raw_args = 1;
		static const bool									is_member_method = true;
		static const bool									is_const_method = false;
	};
	//------------------------------------------------------------------------

	template< typename _retType, typename _objType, typename p1 >
	struct Implementation< _retType( _objType::* )( p1 ) >
	{
		typedef typename _retType							return_type;
		typedef typename _objType							object_type;
		typedef return_type( object_type::* signature )( p1 );
		typedef return_type( * raw_signature )( object_type* const, p1 );

		static const size_t									num_args = 1;
		static const size_t									num_raw_args = 2;
		static const bool									is_member_method = true;
		static const bool									is_const_method = false;

		MIXIN_ARGTEMPLATE_METHOD1( object_type, p1 );
	};
	//------------------------------------------------------------------------

	template< typename _retType, typename _objType, typename p1, typename p2 >
	struct Implementation< _retType( _objType::* )( p1, p2 ) >
	{
		typedef typename _retType							return_type;
		typedef typename _objType							object_type;
		typedef return_type( object_type::* signature )( p1, p2 );
		typedef return_type( * raw_signature )( object_type* const, p1, p2 );

		static const size_t									num_args = 2;
		static const size_t									num_raw_args = 3;
		static const bool									is_member_method = true;
		static const bool									is_const_method = false;

		MIXIN_ARGTEMPLATE_METHOD2( object_type, p1, p2 );
	};
	//------------------------------------------------------------------------

	template< typename _retType, typename _objType, typename p1, typename p2, typename p3 >
	struct Implementation< _retType( _objType::* )( p1, p2, p3 ) >
	{
		typedef typename _retType							return_type;
		typedef typename _objType							object_type;
		typedef return_type( object_type::* signature )( p1, p2, p3 );
		typedef return_type( * raw_signature )( object_type* const, p1, p2, p3 );

		static const size_t									num_args = 3;
		static const size_t									num_raw_args = 4;
		static const bool									is_member_method = true;
		static const bool									is_const_method = false;

		MIXIN_ARGTEMPLATE_METHOD3( object_type, p1, p2, p3 );
	};
	//------------------------------------------------------------------------

	template< typename _retType, typename _objType, typename p1, typename p2, typename p3, typename p4 >
	struct Implementation< _retType( _objType::* )( p1, p2, p3, p4 ) >
	{
		typedef typename _retType							return_type;
		typedef typename _objType							object_type;
		typedef return_type( object_type::* signature )( p1, p2, p3, p4 );
		typedef return_type( * raw_signature )( object_type* const, p1, p2, p3, p4 );

		static const size_t									num_args = 4;
		static const size_t									num_raw_args = 5;
		static const bool									is_member_method = true;
		static const bool									is_const_method = false;

		MIXIN_ARGTEMPLATE_METHOD4( object_type, p1, p2, p3, p4 );
	};
	//------------------------------------------------------------------------

	template< typename _retType, typename _objType, typename p1, typename p2, typename p3, typename p4, typename p5 >
	struct Implementation< _retType( _objType::* )( p1, p2, p3, p4, p5 ) >
	{
		typedef typename _retType							return_type;
		typedef typename _objType							object_type;
		typedef return_type( object_type::* signature )( p1, p2, p3, p4, p5 );
		typedef return_type( * raw_signature )( object_type* const, p1, p2, p3, p4, p5 );

		static const size_t									num_args = 5;
		static const size_t									num_raw_args = 6;
		static const bool									is_member_method = true;
		static const bool									is_const_method = false;

		MIXIN_ARGTEMPLATE_METHOD5( object_type, p1, p2, p3, p4, p5 );
	};
	//------------------------------------------------------------------------

	template< typename _retType, typename _objType, typename p1, typename p2, typename p3, typename p4, typename p5, typename p6 >
	struct Implementation< _retType( _objType::* )( p1, p2, p3, p4, p5, p6 ) >
	{
		typedef typename _retType							return_type;
		typedef typename _objType							object_type;
		typedef return_type( object_type::* signature )( p1, p2, p3, p4, p5, p6 );
		typedef return_type( * raw_signature )( object_type* const, p1, p2, p3, p4, p5, p6 );

		static const size_t									num_args = 6;
		static const size_t									num_raw_args = 7;
		static const bool									is_member_method = true;
		static const bool									is_const_method = false;

		MIXIN_ARGTEMPLATE_METHOD6( object_type, p1, p2, p3, p4, p5, p6 );
	};
	//------------------------------------------------------------------------

	template< typename _retType, typename _objType, typename p1, typename p2, typename p3, typename p4, typename p5, typename p6, typename p7 >
	struct Implementation< _retType( _objType::* )( p1, p2, p3, p4, p5, p6, p7 ) >
	{
		typedef typename _retType							return_type;
		typedef typename _objType							object_type;
		typedef return_type( object_type::* signature )( p1, p2, p3, p4, p5, p6, p7 );
		typedef return_type( * raw_signature )( object_type* const, p1, p2, p3, p4, p5, p6, p7 );

		static const size_t									num_args = 7;
		static const size_t									num_raw_args = 8;
		static const bool									is_member_method = true;
		static const bool									is_const_method = false;

		MIXIN_ARGTEMPLATE_METHOD7( object_type, p1, p2, p3, p4, p5, p6, p7 );
	};
	//------------------------------------------------------------------------

	template< typename _retType, typename _objType, typename p1, typename p2, typename p3, typename p4, typename p5, typename p6, typename p7, typename p8 >
	struct Implementation< _retType( _objType::* )( p1, p2, p3, p4, p5, p6, p7, p8 ) >
	{
		typedef typename _retType							return_type;
		typedef typename _objType							object_type;
		typedef return_type( object_type::* signature )( p1, p2, p3, p4, p5, p6, p7, p8 );
		typedef return_type( * raw_signature )( object_type* const, p1, p2, p3, p4, p5, p6, p7, p8 );

		static const size_t									num_args = 8;
		static const size_t									num_raw_args = 9;
		static const bool									is_member_method = true;
		static const bool									is_const_method = false;

		MIXIN_ARGTEMPLATE_METHOD8( object_type, p1, p2, p3, p4, p5, p6, p7, p8 );
	};
	//------------------------------------------------------------------------

	template< typename _retType, typename _objType, typename p1, typename p2, typename p3, typename p4, typename p5, typename p6, typename p7, typename p8, typename p9 >
	struct Implementation< _retType( _objType::* )( p1, p2, p3, p4, p5, p6, p7, p8, p9 ) >
	{
		typedef typename _retType							return_type;
		typedef typename _objType							object_type;
		typedef return_type( object_type::* signature )( p1, p2, p3, p4, p5, p6, p7, p8, p9 );
		typedef return_type( * raw_signature )( object_type* const, p1, p2, p3, p4, p5, p6, p7, p8, p9 );

		static const size_t									num_args = 9;
		static const size_t									num_raw_args = 10;
		static const bool									is_member_method = true;
		static const bool									is_const_method = false;

		MIXIN_ARGTEMPLATE_METHOD9( object_type, p1, p2, p3, p4, p5, p6, p7, p8, p9 );
	};
	//------------------------------------------------------------------------
	//------------------------------------------------------------------------

	// Class const member functions
	template< typename _retType, typename _objType >
	struct Implementation< _retType( _objType::* )( ) const >
	{
		typedef typename _retType							return_type;
		typedef typename _objType							object_type;
		typedef return_type( object_type::* signature )( ) const;
		typedef return_type( * raw_signature )( object_type* const );

		static const size_t									num_args = 0;
		static const size_t									num_raw_args = 1;
		static const bool									is_member_method = true;
		static const bool									is_const_method = true;
	};
	//------------------------------------------------------------------------

	template< typename _retType, typename _objType, typename p1 >
	struct Implementation< _retType( _objType::* )( p1 ) const >
	{
		typedef typename _retType							return_type;
		typedef typename _objType							object_type;
		typedef return_type( object_type::* signature )( p1 ) const;
		typedef return_type( * raw_signature )( object_type* const, p1 );

		static const size_t									num_args = 1;
		static const size_t									num_raw_args = 2;
		static const bool									is_member_method = true;
		static const bool									is_const_method = true;

		MIXIN_ARGTEMPLATE_METHOD1( object_type, p1 );
	};
	//------------------------------------------------------------------------

	template< typename _retType, typename _objType, typename p1, typename p2 >
	struct Implementation< _retType( _objType::* )( p1, p2 ) const >
	{
		typedef typename _retType							return_type;
		typedef typename _objType							object_type;
		typedef return_type( object_type::* signature )( p1, p2 ) const;
		typedef return_type( * raw_signature )( object_type* const, p1, p2 );

		static const size_t									num_args = 2;
		static const size_t									num_raw_args = 3;
		static const bool									is_member_method = true;
		static const bool									is_const_method = true;

		MIXIN_ARGTEMPLATE_METHOD2( object_type, p1, p2 );
	};
	//------------------------------------------------------------------------

	template< typename _retType, typename _objType, typename p1, typename p2, typename p3 >
	struct Implementation< _retType( _objType::* )( p1, p2, p3 ) const >
	{
		typedef typename _retType							return_type;
		typedef typename _objType							object_type;
		typedef return_type( object_type::* signature )( p1, p2, p3 ) const;
		typedef return_type( * raw_signature )( object_type* const, p1, p2, p3 );

		static const size_t									num_args = 3;
		static const size_t									num_raw_args = 4;
		static const bool									is_member_method = true;
		static const bool									is_const_method = true;

		MIXIN_ARGTEMPLATE_METHOD3( object_type, p1, p2, p3 );
	};
	//------------------------------------------------------------------------

	template< typename _retType, typename _objType, typename p1, typename p2, typename p3, typename p4 >
	struct Implementation< _retType( _objType::* )( p1, p2, p3, p4 ) const >
	{
		typedef typename _retType							return_type;
		typedef typename _objType							object_type;
		typedef return_type( object_type::* signature )( p1, p2, p3, p4 ) const;
		typedef return_type( * raw_signature )( object_type* const, p1, p2, p3, p4 );

		static const size_t									num_args = 4;
		static const size_t									num_raw_args = 5;
		static const bool									is_member_method = true;
		static const bool									is_const_method = true;

		MIXIN_ARGTEMPLATE_METHOD4( object_type, p1, p2, p3, p4 );
	};
	//------------------------------------------------------------------------

	template< typename _retType, typename _objType, typename p1, typename p2, typename p3, typename p4, typename p5 >
	struct Implementation< _retType( _objType::* )( p1, p2, p3, p4, p5 ) const >
	{
		typedef typename _retType							return_type;
		typedef typename _objType							object_type;
		typedef return_type( object_type::* signature )( p1, p2, p3, p4, p5 ) const;
		typedef return_type( * raw_signature )( object_type* const, p1, p2, p3, p4, p5 );

		static const size_t									num_args = 5;
		static const size_t									num_raw_args = 6;
		static const bool									is_member_method = true;
		static const bool									is_const_method = true;

		MIXIN_ARGTEMPLATE_METHOD5( object_type, p1, p2, p3, p4, p5 );
	};
	//------------------------------------------------------------------------

	template< typename _retType, typename _objType, typename p1, typename p2, typename p3, typename p4, typename p5, typename p6 >
	struct Implementation< _retType( _objType::* )( p1, p2, p3, p4, p5, p6 ) const >
	{
		typedef typename _retType							return_type;
		typedef typename _objType							object_type;
		typedef return_type( object_type::* signature )( p1, p2, p3, p4, p5, p6 ) const;
		typedef return_type( * raw_signature )( object_type* const, p1, p2, p3, p4, p5, p6 );

		static const size_t									num_args = 6;
		static const size_t									num_raw_args = 7;
		static const bool									is_member_method = true;
		static const bool									is_const_method = true;

		MIXIN_ARGTEMPLATE_METHOD6( object_type, p1, p2, p3, p4, p5, p6 );
	};
	//------------------------------------------------------------------------

	template< typename _retType, typename _objType, typename p1, typename p2, typename p3, typename p4, typename p5, typename p6, typename p7 >
	struct Implementation< _retType( _objType::* )( p1, p2, p3, p4, p5, p6, p7 ) const >
	{
		typedef typename _retType							return_type;
		typedef typename _objType							object_type;
		typedef return_type( object_type::* signature )( p1, p2, p3, p4, p5, p6, p7 ) const;
		typedef return_type( * raw_signature )( object_type* const, p1, p2, p3, p4, p5, p6, p7 );

		static const size_t									num_args = 7;
		static const size_t									num_raw_args = 8;
		static const bool									is_member_method = true;
		static const bool									is_const_method = true;

		MIXIN_ARGTEMPLATE_METHOD7( object_type, p1, p2, p3, p4, p5, p6, p7 );
	};
	//------------------------------------------------------------------------

	template< typename _retType, typename _objType, typename p1, typename p2, typename p3, typename p4, typename p5, typename p6, typename p7, typename p8 >
	struct Implementation< _retType( _objType::* )( p1, p2, p3, p4, p5, p6, p7, p8 ) const >
	{
		typedef typename _retType							return_type;
		typedef typename _objType							object_type;
		typedef return_type( object_type::* signature )( p1, p2, p3, p4, p5, p6, p7, p8 ) const;
		typedef return_type( * raw_signature )( object_type* const, p1, p2, p3, p4, p5, p6, p7, p8 );

		static const size_t									num_args = 8;
		static const size_t									num_raw_args = 9;
		static const bool									is_member_method = true;
		static const bool									is_const_method = true;

		MIXIN_ARGTEMPLATE_METHOD8( object_type, p1, p2, p3, p4, p5, p6, p7, p8 );
	};
	//------------------------------------------------------------------------

	template< typename _retType, typename _objType, typename p1, typename p2, typename p3, typename p4, typename p5, typename p6, typename p7, typename p8, typename p9 >
	struct Implementation< _retType( _objType::* )( p1, p2, p3, p4, p5, p6, p7, p8, p9 ) const >
	{
		typedef typename _retType							return_type;
		typedef typename _objType							object_type;
		typedef return_type( object_type::* signature )( p1, p2, p3, p4, p5, p6, p7, p8, p9 ) const;
		typedef return_type( * raw_signature )( object_type* const, p1, p2, p3, p4, p5, p6, p7, p8, p9 );

		static const size_t									num_args = 9;
		static const size_t									num_raw_args = 10;
		static const bool									is_member_method = true;
		static const bool									is_const_method = true;

		MIXIN_ARGTEMPLATE_METHOD9( object_type, p1, p2, p3, p4, p5, p6, p7, p8, p9 );
	};
	//------------------------------------------------------------------------
}
//----------------------------------------------------------------------------

}
//----------------------------------------------------------------------------

//============================================================================
