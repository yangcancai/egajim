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
%%% Created : 2021-09-02T09:15:24+00:00
%%%-------------------------------------------------------------------
-module(egajim_xml).

-author("yangcancai").

-define(XML(Name, Attrs, Children),
        #xmlel{name = Name,
               attrs = Attrs,
               children = Children}).
-define(CDATA(Content), #xmlcdata{content = Content}).

-export([ping/1, decode_xml/2, add_friend/1]).

-include("egajim.hrl").

ping(Server) ->
    Attrs =
        [{<<"id">>, egajim_util:generate_rand(10)}, {<<"to">>, Server}, {<<"type">>, <<"get">>}],
    ChildrenAttrs = [{<<"xmlns">>, <<"urn:xmpp:ping">>}],
    Children = [?XML(<<"ping">>, ChildrenAttrs, [])],
    ?XML(<<"iq">>, Attrs, Children).

add_friend(#{to := To,
             from := From,
             text := Text}) ->
    MsgId = egajim_util:generate_rand(10),
    Children =
        % [?XML(<<"subscribe_type">>, [{<<"value">>, <<"1">>}], [?CDATA(<<"null">>)]),
        [?XML(<<"status">>, [], [?CDATA(Text)])],
    Attrs =
        [{<<"to">>, To}, {<<"from">>, From}, {<<"id">>, MsgId}, {<<"type">>, <<"subscribe">>}],
    ?XML(<<"presence">>, Attrs, Children).

decode_xml(Packet, UserJid) ->
    lager:info("recevice: user_jid=~p, packet=~p", [UserJid, exml:to_binary(Packet)]),
    do_decode_xml(Packet, UserJid).

do_decode_xml({xmlstreamend, _} = _Packet, _UserJid) ->
    streamend;
%% ping error
%% <iq from='' to='' type='error' xml:lang='en' id='IVE4m9UahI'>
%% <ping xmlns='urn:xmpp:ping'/>
%% <error code='501' type='cancel'><feature-not-implemented xmlns='urn:ietf:params:xml:ns:xmpp-stanzas'/></error>
%% </iq>
%% pong
%% <iq from='montague.lit' to='capulet.lit' id='s2s1' type='result'/>
do_decode_xml(_Packet, _UserJid) ->
    pong.
