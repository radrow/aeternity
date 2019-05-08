-module(txs_oldnew_eqc_tests).
-include_lib("eunit/include/eunit.hrl").

quickcheck_test_() ->
    PropsMod = txs_oldnew_eqc,
    {setup,
     fun setup/0,
     fun cleanup/1,
     lists:map(
       fun(PropName) ->
               aeeqc_eunit:prop_test_repr(PropsMod, PropName, testing_time_ms(PropName))
       end,
       [prop_tx_primops] = aeeqc_props:prop_names(PropsMod))
    }.

testing_time_ms(PropName) when is_atom(PropName) ->
    500.

setup() ->
    eqc:start().

cleanup(_) ->
    eqc:stop().
