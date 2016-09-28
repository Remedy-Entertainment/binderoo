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

#pragma once

#if !defined( _BINDEROO_FUNCTIONTRAITS_H_ )
#define _BINDEROO_FUNCTIONTRAITS_H_
//----------------------------------------------------------------------------

// FunctionTraits will take any given function and wrap it up in a nice, 
// statically-queryable struct. Using it requires passing a function
// signature in, either by using the decltype keyword or creating a signature
// manually. Since that is a pain, there are four wrapper macros to help you:
//
// * BIND_FUNCTION_TRATS( function )
// * BIND_FUNCTION_TRAITS_OVERLOAD( function, return type [, parameter types ] )
// * BIND_METHOD_TRAITS( object, function )
// * BIND_METHOD_TRAITS_OVERLOAD( object, function, return type [, parameter types ] )
//
// A function is just a plain old ordinary fully-scoped function. A method requires
// a fully-scoped class or struct for the object parameter, while a function is
// simply the unqualified name of the method you want information about.
//
// Overloaded functions cannot be automatically surmised from a function name
// in C++. As such, you'll need to specify the return type and all parameter
// types with the _OVERLOAD variants of the macro to get the function traits
// you want.
//
// A number of members are statically accessible:
//
// * return_type        - Return type of the function. Can be void.
// * object_type        - If it is a member function of a class or struct,
//                        this will be the type. Can be void.
// * signature          - A typedef of the function’s type. No more writing
//                        messy syntax for you.
// * num_args           - The number of parameters the function can accept.
// * is_member_method   - True if object_type != void.
// * is_const_method    - True if is_member_method is true and the function
//                        is declared as const.
// * arg< N >::type     - Given an index N, retrieve the type of the function
//                        parameter. Valid values for N are 0 <= N < num_args.
//
// Crucially, there is also the following members for internal jiggery-pokery
// (yes, that's the technical term):
//
// * raw_signature      - Just like the function, except with a this parameter
//                        at the front if it's a member method.
// * num_raw_args       - Same as num_args, but with the this parameter.
// * rawarg< N >::type  - And again.
//
//----------------------------------------------------------------------------

#include "binderoo/defs.h"
#include "binderoo/functionTraits_vs2012.inl"
//----------------------------------------------------------------------------

#define BIND_FUNCTION_TRAITS_OF( func ) binderoo::FunctionTraits< decltype( &func ) >
#define BIND_FUNCTION_TRAITS( func, retType, ... ) binderoo::FunctionTraits< decltype( ( retType ( * ) ( __VA_ARGS__ ) )&func ) >

#define BIND_METHOD_TRAITS_OF( object, func ) binderoo::FunctionTraits< decltype( BIND_CONCAT( &, BIND_CONCAT( object , BIND_CONCAT( ::, func ) ) ) ) >
#define BIND_METHOD_TRAITS( object, func, retType, ... ) binderoo::FunctionTraits< decltype( ( retType ( BIND_CONCAT( object, ::* ) ) ( __VA_ARGS__ ) )BIND_CONCAT( &, BIND_CONCAT( object , BIND_CONCAT( ::, func ) ) ) ) >
//----------------------------------------------------------------------------

namespace binderoo
{
	template< typename _ty >
	struct FunctionTraits : public functiontraits::Implementation< _ty >
	{
	};
	//------------------------------------------------------------------------
}
//----------------------------------------------------------------------------

#endif // !defined( _BINDEROO_FUNCTIONTRAITS_H_ )

//============================================================================
