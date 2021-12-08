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
%%% Created : 2021-09-02T08:30:58+00:00
%%%-------------------------------------------------------------------
-module(egajim_session).

-author("yangcancai").

-behaviour(gen_server).

%% API
-export([start_link/2]).
%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2,
         code_change/3]).
-export([ping/1, start_connection/1, start_connection/2, auth_sasl_scram_sha1/2, cmd/2,
         call/2, client/1, send_presence_available/2, jid/1, close/1, start/2]).

-include("egajim.hrl").

-record(egajim_session_state, {ejabberd_info = #{}, pong = true}).

%%%===================================================================
%%% API
%%%===================================================================
start(U, P) ->
    supervisor:start_child(egajim_session_sup, [U, P]).

%% @doc Spawns the server and registers the local name (unique)
-spec start_link(UserName :: binary(), Password :: binary()) ->
                    {ok, Pid :: pid()} | ignore | {error, Reason :: term()}.
start_link(UserName, Password) ->
    gen_server:start_link(?MODULE, [UserName, Password], []).

cmd(Pid, Cmd) ->
    gen_server:cast(Pid, Cmd).

client(Pid) ->
    call(Pid, client).

jid(Pid) ->
    call(Pid, jid).

call(Pid, Cmd) ->
    gen_server:call(Pid, Cmd).

close(Pid) ->
    gen_server:call(Pid, close).

ping(Pid) ->
    gen_server:call(Pid,
                    ping).%%%===================================================================
                          %%% gen_server callbacks
                          %%%===================================================================

%% @private
%% @doc Initializes the server
-spec init(Args :: term()) ->
              {ok, State :: #egajim_session_state{}} |
              {ok, State :: #egajim_session_state{}, timeout() | hibernate} |
              {stop, Reason :: term()} |
              ignore.
init([UserName, Password]) ->
    {ok, ConnInfo} = start_connection(UserName, Password),
    timer_ping(),
    {ok, #egajim_session_state{ejabberd_info = ConnInfo}}.

%% @private
%% @doc Handling call messages
-spec handle_call(Request :: term(),
                  From :: {pid(), Tag :: term()},
                  State :: #egajim_session_state{}) ->
                     {reply, Reply :: term(), NewState :: #egajim_session_state{}} |
                     {reply,
                      Reply :: term(),
                      NewState :: #egajim_session_state{},
                      timeout() | hibernate} |
                     {noreply, NewState :: #egajim_session_state{}} |
                     {noreply, NewState :: #egajim_session_state{}, timeout() | hibernate} |
                     {stop,
                      Reason :: term(),
                      Reply :: term(),
                      NewState :: #egajim_session_state{}} |
                     {stop, Reason :: term(), NewState :: #egajim_session_state{}}.
handle_call(ping, _From, State = #egajim_session_state{}) ->
    case handle_info(ping, State) of
        {noreply, S} ->
            {reply, ok, S};
        {Stop, R, S} ->
            {Stop, R, stop, S}
    end;
handle_call(client, _, State = #egajim_session_state{}) ->
    {reply, get_client(State), State};
handle_call(jid, _, State = #egajim_session_state{}) ->
    {reply, get_short_jid(State), State};
handle_call(close, _, State = #egajim_session_state{}) ->
    {stop, normal, ok, State};
handle_call(_Request, _From, State = #egajim_session_state{}) ->
    {reply, ok, State}.

%% @private
%% @doc Handling cast messages
-spec handle_cast(Request :: term(), State :: #egajim_session_state{}) ->
                     {noreply, NewState :: #egajim_session_state{}} |
                     {noreply, NewState :: #egajim_session_state{}, timeout() | hibernate} |
                     {stop, Reason :: term(), NewState :: #egajim_session_state{}}.
handle_cast({add_friend, Who}, State = #egajim_session_state{}) ->
    From = get_user_jid(State),
    ShortJid = get_short_jid(State),
    Server = get_server(State),
    send(get_client(State),
         egajim_xml:add_friend(#{to => <<Who/binary, "@", Server/binary>>,
                                 from => From,
                                 text => <<"Hello, I'am ", ShortJid/binary>>})),
    {noreply, State};
handle_cast({stanza, Stanza}, State = #egajim_session_state{}) ->
    send(get_client(State), Stanza),
    {noreply, State};
handle_cast(_Request, State = #egajim_session_state{}) ->
    {noreply, State}.

%% @private
%% @doc Handling all non call/cast messages
-spec handle_info(Info :: timeout() | term(), State :: #egajim_session_state{}) ->
                     {noreply, NewState :: #egajim_session_state{}} |
                     {noreply, NewState :: #egajim_session_state{}, timeout() | hibernate} |
                     {stop, Reason :: term(), NewState :: #egajim_session_state{}}.
handle_info(ping,
            State =
                #egajim_session_state{ejabberd_info = #{server := _Server, client := _Client},
                                      pong = true}) ->
    timer_ping(),
   %% Xml = egajim_xml:ping(Server),
    %%send(Client, Xml),
    {noreply, State#egajim_session_state{pong = false}};
handle_info(ping, State) ->
    {stop, normal, State};
handle_info({stanza, _Pid, Stanza, _Metadata},
            #egajim_session_state{ejabberd_info = #{user_jid := UserJid}} = State) ->
    case egajim_xml:decode_xml(Stanza, UserJid) of
        pong ->
            {noreply, State#egajim_session_state{pong = true}};
        _ ->
            {noreply, State}
    end;
handle_info(Info, State = #egajim_session_state{}) ->
    error_logger:error_msg("unknown info : info=~p, state=~p", [Info, State]),
    {noreply, State}.

%% @private
%% @doc This function is called by a gen_server when it is about to
%% terminate. It should be the opposite of Module:init/1 and do any
%% necessary cleaning up. When it returns, the gen_server terminates
%% with Reason. The return value is ignored.
-spec terminate(Reason :: normal | shutdown | {shutdown, term()} | term(),
                State :: #egajim_session_state{}) ->
                   term().
terminate(Reason, State = #egajim_session_state{}) ->
    error_logger:error_msg("terminate : reason=~p, state=~p", [Reason, State]),
    escalus_connection:stop(get_client(State)),
    ok.

%% @private
%% @doc Convert process state when code is changed
-spec code_change(OldVsn :: term() | {down, term()},
                  State :: #egajim_session_state{},
                  Extra :: term()) ->
                     {ok, NewState :: #egajim_session_state{}} | {error, Reason :: term()}.
code_change(_OldVsn, State = #egajim_session_state{}, _Extra) ->
    {ok, State}.

%%%===================================================================
%%% Internal functions
%%%===================================================================
start_connection(UserName, PassWord) ->
    ConnSpec =
        [{username, UserName},
         {password, PassWord},
         {auth, {egajim_session, auth_sasl_scram_sha1}},
         %  {type, <<"3">>},
         {server, egajim:server(UserName)},
         {host, egajim:host(UserName)},
         {starttls, true},
         {wait_for_stream_timeout, 5000},
         {port, egajim:port(UserName)},
         {resource, <<>>},
         {connection_steps,
          [start_stream,
           stream_features,
           maybe_use_ssl,
           authenticate,
           maybe_use_compression,
           bind,
           session,
           maybe_stream_management,
           maybe_use_carbons,
           {?MODULE, send_presence_available}]}],
    start_connection(ConnSpec).

start_connection(ConnSpec) ->
    case escalus_connection:start(ConnSpec) of
        {ok, Client, _Props} ->
            UserJid = escalus_client:full_jid(Client),
            ShortJid = escalus_client:short_jid(Client),
            Username = escalus_utils:get_username(UserJid),
            Resource = escalus_utils:get_resource(UserJid),
            {ok,
             #{client => Client,
               user_jid => UserJid,
               short_jid => ShortJid,
               username => Username,
               server => escalus_client:server(Client),
               resource => Resource}};
        Error ->
            Error
    end.

auth_sasl_scram_sha1(Conn, Props) ->
    Username = proplists:get_value(username, Props),
    Type = proplists:get_value(type, Props),
    Type1 =
        case Type of
            undefined ->
                [];
            _ ->
                [{<<"t">>, Type}]
        end,
    Nonce =
        base64:encode(
            crypto:strong_rand_bytes(16)),
    Items = [{<<"n">>, Username}, {<<"r">>, Nonce}],
    ClientFirstMessageBareAuth = csvkv:format(Items ++ Type1, false),
    ClientFirstMessageBare = csvkv:format(Items, false),
    GS2Header = <<"n,,">>,
    Payload = <<GS2Header/binary, ClientFirstMessageBareAuth/binary>>,
    Stanza = escalus_stanza:auth(<<"SCRAM-SHA-1">>, [base64_cdata(Payload)]),

    ok = escalus_connection:send(Conn, Stanza),
    {Response, SaltedPassword, AuthMessage} =
        scram_sha1_response(Conn, GS2Header, ClientFirstMessageBare, Props),
    ResponseStanza = escalus_stanza:auth_response([Response]),

    ok = escalus_connection:send(Conn, ResponseStanza),

    AuthReply = escalus_connection:get_stanza(Conn, auth_reply),
    case AuthReply of
        #xmlel{name = <<"success">>,
               attrs = Attrs,
               children = [#xmlcdata{content = CData}]} ->
            V = proplists:get_value(<<"v">>,
                                    csvkv:parse(
                                        base64:decode(CData))),
            Decoded = base64:decode(V),
            ok = scram_sha1_validate_server(SaltedPassword, AuthMessage, Decoded),
            case lists:keyfind(<<"auto_login_token">>, 1, Attrs) of
                false ->
                    ok;
                {_, <<>>} ->
                    ok;
                {_, ALT} ->
                    NewProps = [{auto_login_token, ALT} | Props],
                    {ok, NewProps}
            end;
        #xmlel{name = <<"failure">>} ->
            throw({auth_failed, Username, AuthReply})
    end.

scram_sha1_response(Conn, GS2Headers, ClientFirstMessageBare, Props) ->
    Challenge = get_challenge(Conn, challenge1),
    ChallengeData = csvkv:parse(Challenge),
    Password = proplists:get_value(password, Props),
    Nonce = proplists:get_value(<<"r">>, ChallengeData),
    Iteration = binary_to_integer(proplists:get_value(<<"i">>, ChallengeData)),
    Salt =
        base64:decode(
            proplists:get_value(<<"s">>, ChallengeData)),
    SaltedPassword = scram:salted_password(Password, Salt, Iteration),
    ClientKey = scram:client_key(SaltedPassword),
    StoredKey = scram:stored_key(ClientKey),
    GS2Headers64 = base64:encode(GS2Headers),
    ClientFinalMessageWithoutProof = <<"c=", GS2Headers64/binary, ",r=", Nonce/binary>>,
    AuthMessage =
        <<ClientFirstMessageBare/binary,
          $,,
          Challenge/binary,
          $,,
          ClientFinalMessageWithoutProof/binary>>,
    ClientSignature = scram:client_signature(StoredKey, AuthMessage),
    ClientProof =
        base64:encode(
            crypto:exor(ClientKey, ClientSignature)),
    ClientFinalMessage = <<ClientFinalMessageWithoutProof/binary, ",p=", ClientProof/binary>>,
    {base64_cdata(ClientFinalMessage), SaltedPassword, AuthMessage}.

scram_sha1_validate_server(SaltedPassword, AuthMessage, ServerSignature) ->
    ServerKey = scram:server_key(SaltedPassword),
    ServerSignatureComputed = scram:server_signature(ServerKey, AuthMessage),
    case ServerSignatureComputed == ServerSignature of
        true ->
            ok;
        _ ->
            false
    end.

base64_cdata(Payload) ->
    #xmlcdata{content = base64:encode(Payload)}.

get_challenge(Conn, Descr) ->
    Challenge = escalus_connection:get_stanza(Conn, Descr),
    case Challenge of
        #xmlel{name = <<"challenge">>, children = [#xmlcdata{content = CData}]} ->
            ChallengeData = base64:decode(CData),
            ChallengeData;
        _ ->
            throw({expected_challenge, got, Challenge})
    end.

timer_ping() ->
    erlang:send_after(300000, self(), ping).

send(Client, Packet) ->
    error_logger:info_msg("send: ~p", [exml:to_binary(Packet)]),
    escalus_client:send(Client, Packet).

get_user_jid(#egajim_session_state{ejabberd_info = #{user_jid := UserJid}}) ->
    UserJid.

get_short_jid(#egajim_session_state{ejabberd_info = #{short_jid := ShortJid}}) ->
    ShortJid.

get_server(#egajim_session_state{ejabberd_info = #{server := Server}}) ->
    Server.

get_client(#egajim_session_state{ejabberd_info = #{client := Client}}) ->
    Client.

send_presence_available(Client, Feature) ->
    escalus_session:send_presence_available(Client),
    {Client, Feature}.
