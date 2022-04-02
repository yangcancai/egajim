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
%%% Created : 2021-09-02T08:27:11+00:00
%%%-------------------------------------------------------------------

-module(egajim).

-author("yangcancai").

-export([login/2, run/0, server/1, host/1, port/1, register/0, register/2, send/2, add_friend/2,
         make_all_friends/1, chat_online/3, chat_offline/3, agree_friend/2, subscribe_ack/2,
        interested/2,unblacked/2,uninterested/2,blacked/2, get_rosters/1,
        nicknamed/3, create_group/2, update_group/3, delete_group/2,
        in_group/3, out_group/3, get_group/1]).

-include("egajim.hrl").
-include_lib("exml/include/exml.hrl").

send(Session, Stanza) ->
    egajim_session:cmd(Session, {stanza, Stanza}).

make_all_friends(L) ->
    escalus_story:make_all_clients_friends([egajim_session:client(Pid) || Pid <- L]).

add_friend(Session, To) ->
    send(Session, escalus_stanza:presence_direct(To, <<"subscribe">>)).
agree_friend(Session, To) ->
    send(Session, escalus_stanza:presence_direct(To, <<"subscribed">>)).
subscribe_ack(Session, To) ->
    Stanza = roster_iq(<<"subscribe_ack">>, #{jids => [To]}),
    send(Session, Stanza).
nicknamed(Session, To, NickName) ->
    Stanza = escalus_stanza:roster_add_contact(To, [], NickName),
    send(Session, Stanza).
interested(Session, To) ->
    Stanza = roster_iq(<<"add_concern">>, #{jid => To}),
    send(Session, Stanza).
uninterested(Session, To) ->
    Stanza = roster_iq(<<"cancel_concern">>, #{jid => To}),
    send(Session, Stanza).
blacked(Session, To) ->
    Stanza = roster_iq(<<"add_black">>, #{jid => To}),
    send(Session, Stanza).

unblacked(Session, To) ->
    Stanza = roster_iq(<<"cancel_black">>, #{jid => To}),
    send(Session, Stanza).

get_rosters(Session) ->
    send(Session, escalus_stanza:roster_get(<<"1">>)).

create_group(Session, Name) ->
    send(Session, roster_iq(<<"create_diy_group">>, #{name => Name})).
update_group(Session, RgID, Name) ->
    send(Session, roster_iq(<<"update_diy_group">>, #{name => Name, rgid => RgID})).
delete_group(Session, RgID) ->
    send(Session, roster_iq(<<"delete_diy_group">>, #{rgid => RgID})).
get_group(Session) ->
    send(Session, roster_iq(<<"get">>, <<"get_diy_groups">>, #{})).
in_group(Session, To, RgID) ->
    send(Session, roster_iq(<<"add_to_diy_group">>, #{rgid => RgID, jid => To})).
out_group(Session, To, RgID) ->
    send(Session, roster_iq(<<"cancel_diy_group">>, #{rgid => RgID, jid => To})).


chat_online(FromSession, ToSession, Msg) ->
chat_offline(FromSession, egajim_session:jid(ToSession), Msg).
chat_offline(FromSession, To, Msg) ->
    send(FromSession, escalus_stanza:chat_to(To, Msg)).

run() ->
    {ok, P} = egajim_session:start(<<"aa">>, <<"123456">>),
    {ok, P1} = egajim_session:start(<<"ttt">>, <<"123456">>),
    % add_friend(P, egajim_session:jid(P1)),
    % make_all_friends([P, P1]),
    {P, P1}.

%     egajim_session:cmd(P, {add_friend, <<"username_eeb2b1284c114ca488a71f4ddccce1a3">>}).

login(UserName, PassWord) ->
    egajim_session:start_connection(UserName, PassWord).
register() ->
    ?MODULE:register(<<"aa">>, <<"123456">>),
    ?MODULE:register(<<"ttt">>, <<"123456">>).

register(UserID, Pass) ->
    ClientProps = [{server, server()}, {host, host()}, {port, port()}],
    {ok, Conn, _} =
        escalus_connection:start(ClientProps, [start_stream, stream_features, maybe_use_ssl]),
    Body =
        [#xmlel{name = K, children = [#xmlcdata{content = V}]}
         || {K, V} <- [{<<"username">>, UserID}, {<<"password">>, Pass}]],
    escalus_connection:send(Conn, escalus_stanza:register_account(Body)),
    Result = wait_for_result(Conn),
    escalus_connection:stop(Conn),
    Result.

wait_for_result(Client) ->
    case escalus_connection:get_stanza_safe(Client, 5000) of
        {error, timeout} ->
            {error, timeout, #xmlcdata{content = <<"timeout">>}};
        {Stanza, _} ->
            case response_type(Stanza) of
                result ->
                    {ok, result, Stanza};
                conflict ->
                    {ok, conflict, Stanza};
                error ->
                    {error, failed_to_register, Stanza};
                _ ->
                    {error, bad_response, Stanza}
            end
    end.

response_type(#xmlel{name = <<"iq">>} = IQ) ->
    case exml_query:attr(IQ, <<"type">>) of
        <<"result">> ->
            result;
        <<"error">> ->
            case exml_query:path(IQ, [{element, <<"error">>}, {attr, <<"code">>}]) of
                <<"409">> ->
                    conflict;
                _ ->
                    error
            end;
        _ ->
            other
    end;
response_type(_) ->
    other.

% server(<<"aa">>) ->

% <<"anonymous.localhost">>;
server(_) ->
    server().

host(_) ->
    host().

% port(<<"aa">>) ->
    % 5223;
port(_) ->
    port().

server() ->
    application:get_env(egajim, ejabberd_server, <<"localhost">>).

host() ->
    application:get_env(egajim, ejabberd_host, <<"localhost">>).

port() ->
    % 5223.
    application:get_env(egajim, ejabberd_port, 5222).


roster_iq(QueryType, Data) ->
    roster_iq(<<"set">>, QueryType, Data).
roster_iq(Type, QueryType, Data) ->
    QueryData = [#xmlcdata{content = jsx:encode(Data)}],
    Query = [#xmlel{name = <<"query">>,
                    attrs = [{<<"xmlns">>, <<"bx:roster">>},
                     {<<"query_type">>, QueryType}],
                     children = QueryData}],
    escalus_stanza:iq(Type, Query).
