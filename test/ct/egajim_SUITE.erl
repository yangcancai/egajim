-module(egajim_SUITE).

-include("egajim_ct.hrl").

-compile(export_all).

all() ->
    [handle].

init_per_suite(Config) ->
    {ok, _} = application:ensure_all_started(egajim),
    new_meck(),
    Config.

end_per_suite(Config) ->
    del_meck(),
    application:stop(egajim),
    Config.

init_per_testcase(_Case, Config) ->
    Config.

end_per_testcase(_Case, _Config) ->
    ok.

new_meck() ->
    ok = meck:new(egajim, [non_strict, no_link]),
    ok.

expect() ->
    ok = meck:expect(egajim, test, fun() -> {ok, 1} end).
del_meck() ->
    meck:unload().

handle(_Config) ->
    expect(),
    ?assertEqual({ok,1}, egajim:test()),
    ok.