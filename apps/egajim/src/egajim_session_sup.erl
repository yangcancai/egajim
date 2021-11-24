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
%%% Created : 2021-11-02T07:10:30+00:00
%%%-------------------------------------------------------------------

-module(egajim_session_sup).

-author("yangcancai").

-behaviour(supervisor).

%% API
-export([start_link/0]).
%% Supervisor callbacks
-export([init/1]).

-define(SERVER, ?MODULE).

%%%===================================================================
%%% API functions
%%%===================================================================

%% @doc Starts the supervisor
-spec start_link() -> {ok, Pid :: pid()} | ignore | {error, Reason :: term()}.
start_link() ->
    supervisor:start_link({local, ?SERVER}, ?MODULE, []).

%%%===================================================================
%%% Supervisor callbacks
%%%===================================================================

%% @private
%% @doc Whenever a supervisor is started using supervisor:start_link/[2,3],
%% this function is called by the new process to find out about
%% restart strategy, maximum restart frequency and child
%% specifications.
-spec init(Args :: term()) ->
              {ok,
               {SupFlags ::
                    {RestartStrategy :: supervisor:strategy(),
                     MaxR :: non_neg_integer(),
                     MaxT :: non_neg_integer()},
                [ChildSpec :: supervisor:child_spec()]}} |
              ignore |
              {error, Reason :: term()}.
init([]) ->
    MaxRestarts = 10,
    MaxSecondsBetweenRestarts = 10,
    SupFlags =
        #{strategy => simple_one_for_one,
          intensity => MaxRestarts,
          period => MaxSecondsBetweenRestarts},

    AChild =
        #{id => egajim_session,
          start => {egajim_session, start_link, []},
          restart => temporary,
          shutdown => 2000,
          type => worker,
          modules => [egajim_session]},

    {ok, {SupFlags, [AChild]}}.

%%%===================================================================
%%% Internal functions
%%%===================================================================
