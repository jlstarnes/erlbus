-module(ebus_handler_SUITE).

-include_lib("common_test/include/ct.hrl").

%% Common Test
-export([
  all/0,
  init_per_suite/1,
  end_per_suite/1,
  init_per_testcase/2,
  end_per_testcase/2
]).

%% Tests
-export([t_handler/1]).

-define(TAB, ebus_test).

%%%===================================================================
%%% Common Test
%%%===================================================================

all() -> [t_handler].

init_per_suite(Config) ->
  ebus:start(),
  Config.

end_per_suite(Config) ->
  ebus:stop(),
  Config.

init_per_testcase(_, Config) ->
  TabId = ets:new(?TAB, [duplicate_bag, public, named_table]),
  [{table,TabId} | Config].

end_per_testcase(_, Config) ->
  ets:delete(?TAB),
  Config.

%%%===================================================================
%%% Exported Tests Functions
%%%===================================================================

t_handler(_Config) ->
  % check topics
  [] = ebus:topics(),

  % callback 1
  CB1 = fun(Msg) ->
    ets:insert(?TAB, {ebus_utils:build_name([Msg]), Msg})
  end,

  % callback 2
  CB2 = fun(Ctx, Msg) ->
    ets:insert(?TAB, {ebus_utils:build_name([Ctx, Msg]), Msg})
  end,

  % create some handlers
  {H1, Ref1} = ebus_process:spawn_handler(CB1, nil, [monitor]),
  H2 = ebus_process:spawn_handler(CB2, h2),

  % subscribe local process
  ok = ebus:sub(H1, <<"foo">>),
  ok = ebus:sub(H2, <<"foo">>),
  ok = ebus:sub(H2, <<"bar">>),

  % publish message
  ebus:pub(<<"foo">>, <<"M1">>),
  timer:sleep(500),

  % check received messages
  [{_, M11}] = ets:lookup(?TAB, key([<<"M1">>])),
  <<"M1">> = M11,
  [{_, M12}] = ets:lookup(?TAB, key([h2, <<"M1">>])),
  <<"M1">> = M12,

  % publish message
  ebus:pub(<<"bar">>, <<"M2">>),
  timer:sleep(500),

  % check received messages
  [] = ets:lookup(?TAB, key([<<"M2">>])),
  [{_, M22}] = ets:lookup(?TAB, key([h2, <<"M2">>])),
  <<"M2">> = M22,

  ebus:unsub(H2, <<"bar">>),

  % publish message
  ebus:pub(<<"bar">>, <<"M3">>),
  timer:sleep(500),

  % check received messages
  [] = ets:lookup(?TAB, key([<<"M3">>])),
  [] = ets:lookup(?TAB, key([h2, <<"M3">>])),

  % check subscribers
  2 = length(ebus:subscribers(<<"foo">>)),
  0 = length(ebus:subscribers(<<"bar">>)),

  % kill handlers and check
  exit(H1, kill),
  {'DOWN', Ref1, _, _, _} = ebus_process:wait_for_msg(5000),
  timer:sleep(500),
  1 = length(ebus:subscribers(<<"foo">>)),

  ct:print("\e[1;1m t_handler: \e[0m\e[32m[OK] \e[0m"),
  ok.

%%%===================================================================
%%% Internal functions
%%%===================================================================

key(L) -> ebus_utils:build_name(L).
