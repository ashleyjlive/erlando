%% The contents of this file are subject to the Mozilla Public License
%% Version 1.1 (the "License"); you may not use this file except in
%% compliance with the License. You may obtain a copy of the License
%% at http://www.mozilla.org/MPL/
%%
%% Software distributed under the License is distributed on an "AS IS"
%% basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See
%% the License for the specific language governing rights and
%% limitations under the License.
%%
%% The Original Code is Erlando.
%%
%% The Initial Developer of the Original Code is VMware, Inc.
%% Copyright (c) 2011-2013 VMware, Inc.  All rights reserved.
%%

-module(error_t).
-compile({parse_transform, do}).

-behaviour(monad).
-export([new/1, '>>='/3, return/2, fail/2, run/2, lift/2]).

-record(error_t, {inner_m}).

-ifdef(use_specs).
-type(monad(A) :: fun (() -> 'ok' | {'ok', A} | {'error', any()})).
-include("monad_specs.hrl").
-endif.

new(InnerMonad) ->
    #error_t{inner_m=InnerMonad}.

'>>='(X, Fun, #error_t{inner_m=InnerMonad}) -> fun () ->
                         do([InnerMonad ||
                                R <- X(),
                                case R of
                                    {error, _Err} = Error -> return(Error);
                                    {ok,  Result}         -> (Fun(Result))();
                                    ok                    -> (Fun(ok))()
                                end
                            ])
                 end.

return(ok, #error_t{inner_m=InnerMonad}) ->
    fun () -> InnerMonad:return(ok) end;
return(X,  #error_t{inner_m=InnerMonad}) ->
    fun () -> InnerMonad:return({ok, X}) end.

%% This is the equivalent of
%%     fail msg = ErrorT $ return (Left (strMsg msg))
%% from the instance (Monad m, Error e) => Monad (ErrorT e m)
%%
%% http://hackage.haskell.org/packages/archive/mtl/1.1.0.2/doc/html/src/Control-Monad-Error.html#ErrorT
%%
%% I.e. note that calling fail on the outer monad is not a failure of
%% the inner monad: it is success of the inner monad, but the failure
%% is encapsulated.
fail(X, #error_t{inner_m=InnerMonad}) ->
    fun () -> InnerMonad:return({error, X}) end.

run(Fun, _) -> Fun().

lift(X, #error_t{inner_m=InnerMonad}) ->
    fun () -> do([InnerMonad || A <- X, return({ok, A})]) end.
