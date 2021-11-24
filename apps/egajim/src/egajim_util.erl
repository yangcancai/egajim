%%%-------------------------------------------------------------------
%%% @author yangcancai

%%% Copyright (c) 2021 by yangcancai(yangcancai0112@gmail.com), All Rights Reserved.
%%%
%%% Licensed under the Apache License, Version 2.0 (the "License");
%%% you may not use this file except in compliance with the License.
%%% You may obtain a copy of the License at
%%%
%%%       https://www.apache.org/licenses/LICENSE-2.0
%%%
%%% Unless required by applicable law or agreed to in writing, software
%%% distributed under the License is distributed on an "AS IS" BASIS,
%%% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%%% See the License for the specific language governing permissions and
%%% limitations under the License.
%%%

%%% @doc
%%%
%%% @end
%%% Created : 2021-09-02T09:14:34+00:00
%%%-------------------------------------------------------------------
-module(egajim_util).

-author("yangcancai").

-export([generate_rand/1]).

generate_rand(Length) ->
    iolist_to_binary([do_rand(0) || _I <- lists:seq(1, Length)]).

do_rand(R) when R > 46, R < 58; R > 64, R < 91; R > 96 ->
    R;
do_rand(_R) ->
    do_rand(47 + rand:uniform(75)).
