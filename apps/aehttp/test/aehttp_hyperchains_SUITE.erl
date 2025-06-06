-module(aehttp_hyperchains_SUITE).
-import(aecore_suite_utils, [ http_request/4
                            , external_address/0
                            , rpc/3
                            , rpc/4
                            ]).

-export(
   [
    all/0, groups/0, suite/0,
    init_per_suite/1, end_per_suite/1,
    init_per_group/2, end_per_group/2,
    init_per_testcase/2, end_per_testcase/2
   ]).


%% Test cases
-export([start_two_child_nodes/1,
         initial_validators/1,
         produce_first_epoch/1,
         produce_some_epochs/1,
         respect_schedule/1,
         entropy_impact_schedule/1,
         spend_txs/1,
         simple_withdraw/1,
         empty_parent_block/1,
         sync_third_node/1,
         verify_rewards/1,
         elected_leader_did_not_show_up/1,
         block_difficulty/1,
         epochs_with_slow_parent/1,
         epochs_with_fast_parent/1,
         check_blocktime/1,
         get_pin/1,
         wallet_post_pin_to_pc/1,
         get_contract_pubkeys/1,
         correct_leader_in_micro_block/1,
         first_leader_next_epoch/1,
         check_default_pin/1,
         fast_parent_fail_pin/1,
         check_finalize_info/1,
         sanity_check_vote_tx/1,
         hole_production/1,
         hole_production_eoe/1
        ]).

-include_lib("stdlib/include/assert.hrl").
-include_lib("common_test/include/ct.hrl").
-include_lib("aecontract/include/hard_forks.hrl").
-include("../../aecontract/test/include/aect_sophia_vsn.hrl").

-define(STAKING_VALIDATOR_CONTRACT, "StakingValidator").
-define(MAIN_STAKING_CONTRACT, "MainStaking").
-define(HC_CONTRACT, "HCElection").
-define(CONSENSUS, hc).
-define(CHILD_EPOCH_LENGTH, 10).
-define(CHILD_BLOCK_TIME, 400).
-define(CHILD_BLOCK_PRODUCTION_TIME, 120).
-define(PARENT_EPOCH_LENGTH, 3).
-define(PARENT_FINALITY, 2).
-define(REWARD_DELAY, 2).
-define(BLOCK_REWARD, 100000000000000000000).
-define(FEE_REWARD, 30000 * ?DEFAULT_GAS_PRICE).

-define(NODE1, dev1).
-define(NODE1_NAME, aecore_suite_utils:node_name(?NODE1)).

-define(NODE2, dev2).
-define(NODE2_NAME, aecore_suite_utils:node_name(?NODE2)).

-define(NODE3, dev3).
-define(NODE3_NAME, aecore_suite_utils:node_name(?NODE3)).

%% -define(LAZY_NODE, dev8).
%% -define(LAZY_NODE_NAME, aecore_suite_utils:node_name(?LAZY_NODE)).

-define(OWNER_PUBKEY, <<42:32/unit:8>>).

-define(PARENT_CHAIN_NODE, aecore_suite_utils:parent_chain_node(1)).
-define(PARENT_CHAIN_NODE_NAME, aecore_suite_utils:node_name(?PARENT_CHAIN_NODE)).
-define(PARENT_CHAIN_NETWORK_ID, <<"local_testnet">>).

-define(DEFAULT_GAS_PRICE, aec_test_utils:min_gas_price()).
-define(INITIAL_STAKE, 1_000_000_000_000_000_000_000_000).

-define(ALICE, {
    <<177,181,119,188,211,39,203,57,229,94,108,2,107,214, 167,74,27,
      53,222,108,6,80,196,174,81,239,171,117,158,65,91,102>>,
    <<145,69,14,254,5,22,194,68,118,57,0,134,66,96,8,20,124,253,238,
      207,230,147,95,173,161,192,86,195,165,186,115,251,177,181,119,
      188,211,39,203,57,229,94,108,2,107,214,167,74,27,53,222,108,6,
      80,196,174,81,239,171,117,158,65,91,102>>,
    "Alice"}).
%% ak_2MGLPW2CHTDXJhqFJezqSwYSNwbZokSKkG7wSbGtVmeyjGfHtm

-define(BOB, {
    <<103,28,85,70,70,73,69,117,178,180,148,246,81,104,
      33,113,6,99,216,72,147,205,210,210,54,3,122,84,195,
      62,238,132>>,
    <<59,130,10,50,47,94,36,188,50,163,253,39,81,120,89,219,72,88,68,
      154,183,225,78,92,9,216,215,59,108,82,203,25,103,28,85,70,70,
      73,69,117,178,180,148,246,81,104,33,113,6,99,216,72,147,205,
      210,210,54,3,122,84,195,62,238,132>>,
    "Bob"}).
%% ak_nQpnNuBPQwibGpSJmjAah6r3ktAB7pG9JHuaGWHgLKxaKqEvC

-define(BOB_SIGN, {
    <<211,171,126,224,112,125,255,130,213,51,158,2,198,188,30,
      130,227,205,11,191,122,121,237,227,129,67,65,170,117,35,
      131,190>>,
    <<245,228,166,6,138,54,196,135,180,68,180,161,153,228,97,
      127,100,77,122,20,169,108,224,29,51,209,182,55,106,223,
      24,219,211,171,126,224,112,125,255,130,213,51,158,2,
      198,188,30,130,227,205,11,191,122,121,237,227,129,67,
      65,170,117,35,131,190>>,
    "Bob"}).
%% ak_2cDpmgCXN4nTu2hYsa5KEVTgPJo2cu2SreCDPhjh6VuXH37Z7Y

-define(LISA, {
    <<200,171,93,11,3,93,177,65,197,27,123,127,177,165,
      190,211,20,112,79,108,85,78,88,181,26,207,191,211,
      40,225,138,154>>,
    <<237,12,20,128,115,166,32,106,220,142,111,97,141,104,201,130,56,
      100,64,142,139,163,87,166,185,94,4,159,217,243,160,169,200,171,
      93,11,3,93,177,65,197,27,123,127,177,165,190,211,20,112,79,108,
      85,78,88,181,26,207,191,211,40,225,138,154>>,
    "Lisa"}).
%% ak_2XNq9oKtThxKLNFGWTaxmLBZPgP7ECEGxL3zK7dTSFh6RyRvaG

-define(DWIGHT, {
    <<8,137,159,99,139,175,27,58,77,11,191,52,198,199,7,50,133,195,184,219,
        148,124,4,5,44,247,57,95,188,173,95,35>>,
    <<107,251,189,176,92,221,4,46,56,231,137,117,181,8,124,14,212,150,167,
        53,95,94,50,86,144,230,93,222,61,116,85,96,8,137,159,99,139,175,27,58,
        77,11,191,52,198,199,7,50,133,195,184,219,148,124,4,5,44,247,57,95,
        188,173,95,35>>,
    "Dwight"}). %% Parent chain account
%% ak_4m5iGyT3AiahzGKCE2fCHVsQYU7FBMDiaMJ1YPxradKsyfCc9

-define(EDWIN, {
    <<212,212,169,78,149,148,138,221,156,80,4,156,9,139,144,114,243,122,20,
        103,168,43,42,244,93,118,38,98,71,34,199,94>>,
    <<81,177,15,108,16,183,128,229,4,114,166,227,47,125,145,21,68,196,185,
        115,42,198,168,204,220,206,200,58,12,32,56,98,212,212,169,78,149,148,
        138,221,156,80,4,156,9,139,144,114,243,122,20,103,168,43,42,244,93,
        118,38,98,71,34,199,94>>,
    "Edwin"}).  %% Parent chain account
%% ak_2cjUYDhaKaiyGvuswL6K96ooKZKtFZZEopgxc3hwR2Yqb8SWxd

-define(FORD, {
    <<157,139,168,202,250,128,128,7,45,18,214,147,85,31,12,182,220,213,173,
        237,6,147,239,41,183,214,34,113,100,122,208,14>>,
    <<105,184,53,188,53,158,124,5,171,89,28,64,41,203,59,179,66,53,26,132,
        75,116,139,24,228,4,200,223,25,224,76,127,157,139,168,202,250,128,128,
        7,45,18,214,147,85,31,12,182,220,213,173,237,6,147,239,41,183,214,34,
        113,100,122,208,14>>,
    "Ford"}).
%% ak_2CPHnpGxYw3T7XdUybxKDFGwtFQY7E5o3wJzbexkzSQ2BQ7caJ

-define(GENESIS_BENFICIARY, <<0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0>>).

all() -> [{group, hc}, {group, epochs_slow}, {group, epochs_fast}, {group, hc_hole},
          {group, pinning}, {group, default_pin}, {group, config}
          ].

groups() ->
    [
      {hc, [sequence],
          [ start_two_child_nodes
          , produce_first_epoch
          , verify_rewards
          , spend_txs
          , simple_withdraw
          , correct_leader_in_micro_block
          , sync_third_node
          , produce_some_epochs
          , check_finalize_info
          , respect_schedule
          , entropy_impact_schedule
          , check_blocktime
          , get_contract_pubkeys
          , sanity_check_vote_tx
          ]}
    , {epochs_slow, [sequence],
          [ start_two_child_nodes
          , first_leader_next_epoch
          , epochs_with_slow_parent
          ]}
    , {epochs_fast, [sequence],
          [ start_two_child_nodes
          , produce_first_epoch
          , epochs_with_fast_parent
          ]}
    , {hc_hole, [sequence],
          [ start_two_child_nodes
          , produce_first_epoch
          , hole_production
          , hole_production_eoe
          ]}
    , {pinning, [sequence],
          [ start_two_child_nodes,
            produce_first_epoch,
            get_pin,
            wallet_post_pin_to_pc
          ]}
    , {default_pin, [sequence],
          [ start_two_child_nodes,
            produce_first_epoch,
            check_default_pin,
            fast_parent_fail_pin
          ]}
    , {config, [sequence],
          [ start_two_child_nodes,
            initial_validators
          ]}
    ].

suite() -> [].

init_per_suite(Config0) ->
    case aect_test_utils:require_at_least_protocol(?CERES_PROTOCOL_VSN) of
        {skip, _} = Skip -> Skip;
        ok ->
            {ok, _StartedApps} = application:ensure_all_started(gproc),
            Config = [{symlink_name, "latest.hyperchains"}, {test_module, ?MODULE}] ++ Config0,
            Config1 = aecore_suite_utils:init_per_suite([?NODE1, ?NODE2],
                                                        #{}, %% config is rewritten per suite
                                                        [],
                                                        Config),
            GenesisProtocol = 1,
            {ok, AccountFileName} =
                aecore_suite_utils:hard_fork_filename(?PARENT_CHAIN_NODE, Config1, integer_to_list(GenesisProtocol), "accounts_test.json"),
            GenesisProtocolBin = integer_to_binary(GenesisProtocol),
            ParentCfg =
                #{  <<"chain">> =>
                        #{  <<"persist">> => false,
                            <<"hard_forks">> =>
                                #{  GenesisProtocolBin => #{<<"height">> => 0, <<"accounts_file">> => AccountFileName},
                                    integer_to_binary(?CERES_PROTOCOL_VSN) => #{<<"height">> => 1}
                                },
                            <<"consensus">> =>
                                #{<<"0">> => #{<<"type">> => <<"ct_tests">>}}
                         },
                    <<"fork_management">> =>
                        #{<<"network_id">> => ?PARENT_CHAIN_NETWORK_ID},
                    <<"mempool">> => #{<<"nonce_offset">> => 200},
                    <<"mining">> =>
                        #{<<"micro_block_cycle">> => 1,
                          <<"expected_mine_rate">> => 2000,
                          <<"autostart">> => false,
                          <<"beneficiary_reward_delay">> => ?REWARD_DELAY }
                },
            aecore_suite_utils:make_multi(Config1, [?PARENT_CHAIN_NODE]),
            aecore_suite_utils:create_config(?PARENT_CHAIN_NODE, Config1, ParentCfg, []),
            {_ParentPatronPriv, ParentPatronPub} = aecore_suite_utils:sign_keys(?PARENT_CHAIN_NODE),
            ParentPatronPubEnc = aeser_api_encoder:encode(account_pubkey, ParentPatronPub),
            aecore_suite_utils:create_seed_file(AccountFileName,
                #{  ParentPatronPubEnc => 100000000000000000000000000000000000000000000000000000000000000000000000
                    , encoded_pubkey(?DWIGHT) => 2100000000000000000000000000
                    , encoded_pubkey(?EDWIN) => 3100000000000000000000000000
                }),
            StakingContract = staking_contract_address(),
            ElectionContract = election_contract_address(),
            CtSrcMap = maps:from_list([{C, create_stub(C)}
                                       || C <- [?MAIN_STAKING_CONTRACT, ?STAKING_VALIDATOR_CONTRACT, ?HC_CONTRACT]]),
            [{staking_contract, StakingContract}, {election_contract, ElectionContract}, {contract_src, CtSrcMap} | Config1]
    end.

end_per_suite(Config) ->
    catch aecore_suite_utils:stop_node(?NODE1, Config),
    catch aecore_suite_utils:stop_node(?NODE2, Config),
    catch aecore_suite_utils:stop_node(?NODE3, Config),
    catch aecore_suite_utils:stop_node(?PARENT_CHAIN_NODE, Config),
    [application:stop(A) ||
        A <- lists:reverse(
               proplists:get_value(started_apps, Config, []))],
    ok.

init_per_group(Group, ConfigPre) ->
    Config0 =
        case Group of
            default_pin -> [ {initial_validators, false}, {default_pinning_behavior, true}, {parent_pin_sync_margin, 3} | ConfigPre ];
            config -> [ {initial_validators, true}, {default_pinning_behavior, false} | ConfigPre ];
            _ -> [ {initial_validators, false}, {default_pinning_behavior, false} | ConfigPre ]
        end,
    VM = fate,
    NetworkId = <<"hc">>,
    GenesisStartTime = aeu_time:now_in_msecs(),
    Config = [{network_id, NetworkId}, {genesis_start_time, GenesisStartTime},
              {consensus, ?CONSENSUS} |
              aect_test_utils:init_per_group(VM, Config0)],

    aecore_suite_utils:start_node(?PARENT_CHAIN_NODE, Config),
    aecore_suite_utils:connect(?PARENT_CHAIN_NODE_NAME, []),
    ParentTopHeight = rpc(?PARENT_CHAIN_NODE, aec_chain, top_height, []),
    StartHeight = max(ParentTopHeight, ?PARENT_EPOCH_LENGTH),
    ct:log("Parent chain top height ~p start at ~p", [ParentTopHeight, StartHeight]),
    %%TODO mine less than necessary parent height and test chain starts when height reached
    {ok, _} = mine_key_blocks(
            ?PARENT_CHAIN_NODE_NAME,
            (StartHeight - ParentTopHeight) + ?PARENT_FINALITY),
    [ {staker_names, [?ALICE, ?BOB, ?LISA]}, {parent_start_height, StartHeight} | Config].

child_node_config(Node, Stakeholders, Pinners, CTConfig) ->
    ReceiveAddress = encoded_pubkey(?FORD),
    NodeConfig = node_config(Node, CTConfig, Stakeholders, Pinners, ReceiveAddress),
    build_json_files(?HC_CONTRACT, NodeConfig, CTConfig),
    aecore_suite_utils:create_config(Node, CTConfig, NodeConfig, [{add_peers, true}]).

end_per_group(_Group, Config) ->
    Config1 = with_saved_keys([nodes], Config),
    [ aecore_suite_utils:stop_node(Node, Config1)
      || {Node, _, _, _} <- proplists:get_value(nodes, Config1, []) ],

    aecore_suite_utils:assert_no_errors_in_logs(Config1, ["{handled_abort,parent_chain_not_synced}"]),

    Config1.

%% Here we decide which nodes are started/running
init_per_testcase(start_two_child_nodes, Config) ->
    Config1 =
        [{nodes, [{?NODE1, ?NODE1_NAME, [?ALICE, ?LISA], [{?ALICE, ?DWIGHT}, {?LISA, ?EDWIN}]},
                  {?NODE2, ?NODE2_NAME, [?BOB_SIGN], [{?BOB_SIGN, ?EDWIN}]}
                 ]}
         | Config],
    aect_test_utils:setup_testcase(Config1),
    Config1;
init_per_testcase(sync_third_node, Config) ->
    Config1 = with_saved_keys([nodes], Config),
    Nodes = ?config(nodes, Config1),
    Config2 = lists:keyreplace(nodes, 1, Config1,
                               {nodes, Nodes ++ [{?NODE3, ?NODE3_NAME, [], []}]}),
    aect_test_utils:setup_testcase(Config2),
    Config2;
init_per_testcase(_Case, Config) ->
    Config1 = with_saved_keys([nodes], Config),
    aect_test_utils:setup_testcase(Config1),
    Config1.

end_per_testcase(_Case, Config) ->
    {save_config, Config}.

with_saved_keys(Keys, Config) ->
    {_TC, SavedConfig} = ?config(saved_config, Config),
    lists:foldl(fun(Key, Conf) ->
                    case proplists:get_value(Key, SavedConfig) of
                        undefined -> Conf;
                        Val -> [{Key, Val} | Conf]
                    end
                end,
                lists:keydelete(saved_config, 1, Config), Keys).

contract_create_spec(Name, Src, Args, Amount, Nonce, Owner) ->
    {ok, Code}   = aect_test_utils:compile_contract(aect_test_utils:sophia_version(), Name),
    Pubkey = aect_contracts:compute_contract_pubkey(Owner, Nonce),
    EncodedPubkey   = aeser_api_encoder:encode(contract_pubkey, Pubkey),
    EncodedOwner    = aeser_api_encoder:encode(account_pubkey, Owner),
    EncodedCode     = aeser_api_encoder:encode(contract_bytearray, Code),
    {ok, CallData} = aect_test_utils:encode_call_data(Src, "init", Args),
    EncodedCallData = aeser_api_encoder:encode(contract_bytearray, CallData),
    VM = aect_test_utils:vm_version(),
    ABI = aect_test_utils:abi_version(),
    Spec = #{ <<"amount">> => Amount
            , <<"vm_version">> => VM
            , <<"abi_version">> => ABI
            , <<"nonce">> => Nonce
            , <<"code">> => EncodedCode
            , <<"call_data">> => EncodedCallData
            , <<"pubkey">> => EncodedPubkey
            , <<"owner_pubkey">> => EncodedOwner },
    Spec.

contract_call_spec(ContractPubkey, Src, Fun, Args, Amount, From, Nonce) ->
    {contract_call_tx, CallTx} =
        aetx:specialize_type(contract_call(ContractPubkey, Src, Fun, Args,
                                           Amount, From, Nonce)),
    %% Don't allow named contracts!?
    {contract, ContractPubKey} =
        aeser_id:specialize(aect_call_tx:contract_id(CallTx)),
    Spec =
        #{  <<"caller">>          => aeser_api_encoder:encode(account_pubkey,
                                                              aect_call_tx:caller_pubkey(CallTx))
          , <<"nonce">>           => aect_call_tx:nonce(CallTx)
          , <<"contract_pubkey">> => aeser_api_encoder:encode(contract_pubkey, ContractPubKey)
          , <<"abi_version">>     => aect_call_tx:abi_version(CallTx)
          , <<"fee">>             => aect_call_tx:fee(CallTx)
          , <<"amount">>          => aect_call_tx:amount(CallTx)
          , <<"gas">>             => aect_call_tx:gas(CallTx)
          , <<"gas_price">>       => aect_call_tx:gas_price(CallTx)
          , <<"call_data">>       => aeser_api_encoder:encode(contract_bytearray,
                                                              aect_call_tx:call_data(CallTx))},
    Spec.

contract_call(ContractPubkey, Src, Fun, Args, Amount, From) ->
    Nonce = next_nonce(?NODE1, From), %% no contract calls support for parent chain
    contract_call(ContractPubkey, Src, Fun, Args, Amount, From, Nonce).

contract_call(ContractPubkey, Src, Fun, Args, Amount, From, Nonce) ->
    {ok, CallData} = aect_test_utils:encode_call_data(Src, Fun, Args),
    ABI = aect_test_utils:abi_version(),
    TxSpec =
        #{  caller_id   => aeser_id:create(account, From)
          , nonce       => Nonce
          , contract_id => aeser_id:create(contract, ContractPubkey)
          , abi_version => ABI
          , fee         => 1000000 * ?DEFAULT_GAS_PRICE
          , amount      => Amount
          , gas         => 1000000
          , gas_price   => ?DEFAULT_GAS_PRICE
          , call_data   => CallData},
    {ok, Tx} = aect_call_tx:new(TxSpec),
    Tx.

wait_same_top(Nodes) ->
    wait_same_top(Nodes, 3).

wait_same_top(_Nodes, Attempts) when Attempts < 1 ->
    %% {error, run_out_of_attempts};
    throw({error, run_out_of_attempts});
wait_same_top(Nodes, Attempts) ->
    KBs = [ rpc(Node, aec_chain, top_block, []) || Node <- Nodes ],
    case lists:usort(KBs) of
        [KB] ->
            {ok, KB};
        Diffs ->
            ct:log("Nodes differ: ~p", [Diffs]),
            timer:sleep(?CHILD_BLOCK_TIME div 2),
            wait_same_top(Nodes, Attempts - 1)
    end.

spend_txs(Config) ->
    produce_cc_blocks(Config, 1),

    %% First, seed ALICE, BOB and LISA, they need tokens in later tests
    {ok, []} = rpc:call(?NODE1_NAME, aec_tx_pool, peek, [infinity]),
    NetworkId = ?config(network_id, Config),
    seed_account(pubkey(?ALICE), 100000001 * ?DEFAULT_GAS_PRICE, NetworkId),
    seed_account(pubkey(?BOB), 100000002 * ?DEFAULT_GAS_PRICE, NetworkId),
    seed_account(pubkey(?LISA), 100000003 * ?DEFAULT_GAS_PRICE, NetworkId),

    produce_cc_blocks(Config, 1),
    {ok, []} = rpc:call(?NODE1_NAME, aec_tx_pool, peek, [infinity]),

    %% Make spends until we've passed an epoch boundary
    spend_txs_(Config).


spend_txs_(Config) ->
    {ok, #{first := First}} = rpc(?NODE1, aec_chain_hc, epoch_info, []),
    Top = rpc(?NODE1, aec_chain, top_header, []),

    case aec_headers:height(Top) == First of
        true  -> ok;
        false ->
            NetworkId = ?config(network_id, Config),
            seed_account(pubkey(?EDWIN), 1, NetworkId),
            produce_cc_blocks(Config, 1),
            {ok, []} = rpc:call(?NODE1_NAME, aec_tx_pool, peek, [infinity]),
            spend_txs_(Config)
    end.

check_blocktime(_Config) ->
    {ok, TopBlock} = rpc(?NODE1, aec_chain, top_key_block, []),
    check_blocktime_(TopBlock, []).

check_blocktime_(Block, BTs) ->
    case aec_blocks:height(Block) > 1 of
        true ->
            {ok, PrevBlock} = rpc(?NODE1, aec_chain, get_block, [aec_blocks:prev_key_hash(Block)]),
            Time1 = aec_blocks:time_in_msecs(Block),
            Time2 = aec_blocks:time_in_msecs(PrevBlock),
            BTime = Time1 - Time2,
            IsHole = aec_headers:is_hole(aec_blocks:to_key_header(Block)),
            ct:log("Block ~p: hole=~p - blocktime ~p ms", [aec_blocks:height(Block), IsHole, BTime]),
            check_blocktime_(PrevBlock, [BTime | BTs]);
        false ->
            AvgBTime = lists:sum(BTs) / length(BTs),
            ct:pal("Average blocktime through ~p blocks: ~.2fms (BLOCKTIME = ~p)", [length(BTs), AvgBTime, ?CHILD_BLOCK_TIME]),
            BT = ?CHILD_BLOCK_TIME,
            ?assert(AvgBTime > BT - BT div 20),
            ?assert(AvgBTime < BT + BT div 20),
            ok
    end.

start_two_child_nodes(Config) ->
    [{Node1, NodeName1, Stakers1, Pinners1}, {Node2, NodeName2, Stakers2, Pinners2} | _] = ?config(nodes, Config),
    Env = [ {"AE__FORK_MANAGEMENT__NETWORK_ID", binary_to_list(?config(network_id, Config))} ],
    child_node_config(Node1, Stakers1, Pinners1, Config),
    aecore_suite_utils:start_node(Node1, Config, Env),
    aecore_suite_utils:connect(NodeName1, []),
    child_node_config(Node2, Stakers2, Pinners2, Config),
    aecore_suite_utils:start_node(Node2, Config, Env),
    aecore_suite_utils:connect(NodeName2, []),
    ok.

produce_first_epoch(Config) ->
    produce_n_epochs(Config, 1).

produce_some_epochs(Config) ->
    produce_n_epochs(Config, 5).

produce_n_epochs(Config, N) ->
    [{Node1, _, _, _}|_] = ?config(nodes, Config),
    %% produce blocks
    {ok, Bs} = produce_cc_blocks(Config, N * ?CHILD_EPOCH_LENGTH),
    %% check producers
    Producers = [ aec_blocks:miner(B) || B <- Bs, aec_blocks:is_key_block(B) ],
    ChildTopHeight = rpc(Node1, aec_chain, top_height, []),
    Leaders = leaders_at_height(Node1, ChildTopHeight, Config),
    ct:log("Bs: ~p  Leaders ~p", [Bs, Leaders]),
    %% Check that all producers are valid leaders
    ?assertEqual([], lists:usort(Producers) -- Leaders),
    %% If we have more than 1 leader, then we should see more than one producer
    %% at least for larger EPOCHs
    ?assert(length(Leaders) > 1, length(Producers) > 1),
    ParentTopHeight = rpc(?PARENT_CHAIN_NODE, aec_chain, top_height, []),
    {ok, ParentBlocks} = get_generations(?PARENT_CHAIN_NODE, 0, ParentTopHeight),
    ct:log("Parent chain blocks ~p", [ParentBlocks]),
    {ok, ChildBlocks} = get_generations(Node1, 0, ChildTopHeight),
    ct:log("Child chain blocks ~p", [ChildBlocks]),
    ok.

respect_schedule(Config) ->
    [{Node, _, _, _}|_] = ?config(nodes, Config),
    ChildHeight = rpc(Node, aec_chain, top_height, []),
    %% Validate one epoch at a time
    respect_schedule(Node, 1, 1, ChildHeight).

respect_schedule(_Node, EpochStart, _Epoch, TopHeight) when TopHeight < EpochStart ->
    ok;
respect_schedule(Node, EpochStart, Epoch, TopHeight) ->
    {ok, #{first := StartHeight} = EI} =
        rpc(Node, aec_chain_hc, epoch_info, [EpochStart]),

    #{ seed := EISeed, validators := EIValidators, length := EILength, last := EILast } = EI,

    ct:log("Checking epoch ~p info: ~p at height ~p", [Epoch, EI, EpochStart]),

    {ParentHeight, PHash} = get_entropy(Node, Epoch),
    ct:log("ParentHash at height ~p: ~p", [ParentHeight, PHash]),
    ?assertMatch(Hash when Hash == undefined; Hash == PHash, EISeed),

    %% Check the API functions in aec_chain_hc
    {ok, Schedule} = rpc(Node, aec_chain_hc, validator_schedule, [EpochStart, PHash, EIValidators, EILength]),
    ct:log("Validating schedule ~p for Epoch ~p", [Schedule, Epoch]),

    lists:foreach(fun({Height, ExpectedProducer}) when Height =< TopHeight ->
                              {ok, KeyHeader} = rpc(Node, aec_chain, get_key_header_by_height, [Height]),
                              Producer = aec_headers:miner(KeyHeader),
                              IsHole = aec_headers:is_hole(KeyHeader),
                              ct:log("Check producer of (~p) block ~p: ~p =?= ~p", [IsHole, Height, Producer, ExpectedProducer]),
                              [ ?assertEqual(Producer, ExpectedProducer) || not IsHole ];
                     (_) -> ok
                  end, lists:zip(lists:seq(StartHeight, StartHeight + EILength - 1), Schedule)),

    respect_schedule(Node, EILast + 1, Epoch + 1, TopHeight).

%% For different Epoch's we have different schedules
%% (Provided we past 4 epochs)
entropy_impact_schedule(Config) ->
    Nodes = [ N || {N, _, _, _} <- ?config(nodes, Config)],
    Node = hd(Nodes),
    %% Sync nodes
    ChildHeight = rpc(Node, aec_chain, top_height, []),
    {ok, #{epoch := Epoch0, length := Length0, first := StartHeight}} = rpc(Node, aec_chain_hc, epoch_info, []),
    %% Make sure chain is long enough
    case Epoch0 =< 5 of
      true ->
        %% Chain to short to have meaningful test, e.g. when ran in isolation
        produce_cc_blocks(Config, 5 * Length0 - ChildHeight);
      false ->
        %% Make sure at start of epoch
        produce_cc_blocks(Config, StartHeight - ChildHeight)
    end,
    {ok, #{seed := Seed,
           first := First,
           length := Length,
           validators := Validators,
           epoch := Epoch}} = rpc(Node, aec_chain_hc, epoch_info, []),

    {_, Entropy0} = get_entropy(Node, Epoch - 1),
    {_, Entropy1} = get_entropy(Node, Epoch),

    {ok, Schedule} = rpc(Node, aec_chain_hc, validator_schedule, [First, Seed, Validators, Length]),
    {ok, RightSchedule} = rpc(Node, aec_chain_hc, validator_schedule, [First, Entropy1, Validators, Length]),
    {ok, WrongSchedule} = rpc(Node, aec_chain_hc, validator_schedule, [First, Entropy0, Validators, Length]),
    ct:log("Schedules:\nepoch ~p\nwrong ~p\nright ~p", [Schedule, WrongSchedule, RightSchedule]),
    %% There is a tiny possibility that the two against all odds are the same
    ?assertEqual(RightSchedule, Schedule),
    ?assertNotEqual(WrongSchedule, Schedule).

simple_withdraw(Config) ->
    [{_Node, NodeName, _, _} | _] = ?config(nodes, Config),
    NetworkId = ?config(network_id, Config),

    %% Not at the start of the epoch
    produce_cc_blocks(Config, 2),

    %% grab Alice's and Bob's staking validator contract
    {ok, AliceCtEnc} = inspect_staking_contract(?ALICE, {get_validator_contract, ?ALICE}, Config),
    {ok, AliceCt} = aeser_api_encoder:safe_decode(contract_pubkey, AliceCtEnc),
    {ok, BobCtEnc} = inspect_staking_contract(?ALICE, {get_validator_contract, ?BOB}, Config),
    {ok, BobCt} = aeser_api_encoder:safe_decode(contract_pubkey, BobCtEnc),
    ValidatorStub = src(?STAKING_VALIDATOR_CONTRACT, Config),

    %% Get the initial state
    InitBalance  = account_balance(pubkey(?ALICE)),

    %% Auto-stake is on, so available balance should be 0
    {ok, 0} = inspect_validator(AliceCt, ?ALICE, get_available_balance, Config),

    %% Adjust stake to prepare for a withdrawal...
    WithdrawAmount = 1000,
    Call1 = contract_call(AliceCt, ValidatorStub, "adjust_stake", [integer_to_list(-WithdrawAmount)], 0, pubkey(?ALICE)),
    CallTx1 = sign_and_push(NodeName, Call1, ?ALICE, NetworkId),
    {ok, [_]} = rpc:call(NodeName, aec_tx_pool, peek, [infinity]),
    produce_cc_blocks(Config, 1),
    {ok, CallRes1} = call_info(CallTx1),
    {ok, _Res1} = decode_consensus_result(CallRes1, "adjust_stake", ValidatorStub),

    %% Ok, should still be 0
    produce_cc_blocks(Config, 1),
    {ok, 0} = inspect_validator(AliceCt, ?ALICE, get_available_balance, Config),

    %% Let's advance 5 epochs...
    produce_n_epochs(Config, 5),

    %% Now test the withdrawal
    {ok, WithdrawAmount} = inspect_validator(AliceCt, ?ALICE, get_available_balance, Config),

    {ok, AliceStake} = inspect_validator(AliceCt, ?ALICE, get_total_balance, Config),
    {ok, BobStake} = inspect_validator(BobCt, ?BOB, get_total_balance, Config),

    Call2 = contract_call(AliceCt, ValidatorStub, "withdraw", [integer_to_list(WithdrawAmount)], 0, pubkey(?ALICE)),
    CallTx2 = sign_and_push( NodeName, Call2, ?ALICE, NetworkId),
    {ok, [_]} = rpc:call(NodeName, aec_tx_pool, peek, [infinity]),
    StakeWithdrawDelay = 1,
    produce_cc_blocks(Config, StakeWithdrawDelay),
    EndBalance = account_balance(pubkey(?ALICE)),
    {ok, CallRes2} = call_info(CallTx2),
    {ok, _Res2} = decode_consensus_result(CallRes2, "withdraw", ValidatorStub),
    GasUsed = aect_call:gas_used(CallRes2),
    GasPrice = aect_call:gas_price(CallRes2),
    Fee = aetx:fee(aetx_sign:tx(CallTx2)),
    {Producer, KeyReward} = key_reward_provided(),
    ct:log("Initial balance: ~p, withdrawn: ~p, gas used: ~p, gas price: ~p, fee: ~p, end balance: ~p",
           [InitBalance, WithdrawAmount, GasUsed, GasPrice, Fee, EndBalance]),
    {ok, AliceStake1} = inspect_validator(AliceCt, ?ALICE, get_total_balance, Config),
    {ok, BobStake1} = inspect_validator(BobCt, ?BOB, get_total_balance, Config),
    ?assert(BobStake == BobStake1 orelse
            (Producer == pubkey(?BOB) andalso BobStake + KeyReward == BobStake1)),
    ct:log("Staking power before: ~p and after ~p", [AliceStake, AliceStake1]),
    ?assert(AliceStake - 1000 == AliceStake1 orelse
            (Producer == pubkey(?ALICE) andalso AliceStake + KeyReward - 1000 == AliceStake1)),
    ok.

correct_leader_in_micro_block(Config) ->
    [{_Node, NodeName, _, _} | _] = ?config(nodes, Config),
    %% Call the contract in a transaction, asking for "leader"
    {ok, [_]} = produce_cc_blocks(Config, 1),
    CallTx =
        sign_and_push(
            NodeName,
            contract_call(?config(election_contract, Config), src(?HC_CONTRACT, Config),
                          "leader", [], 0, pubkey(?ALICE)),
            ?ALICE, ?config(network_id, Config)),

    {ok, [KeyBlock, _MicroBlock]} = produce_cc_blocks(Config, 1),
    %% Microblock contains the contract call, find out what it returned on that call
    {ok, Call} = call_info(CallTx),
    {ok, Res} = decode_consensus_result(Call, "leader", src(?HC_CONTRACT, Config)),
    %% The actual leader did produce the keyblock (and micro block)
    Producer = aeser_api_encoder:encode(account_pubkey, aec_blocks:miner(KeyBlock)),
    ?assertEqual(Producer, Res).

side_producer(_Config, _Delay, 0) ->
    ct:log("Side producer exhausted");
side_producer(Config, Delay, MaxProduce) ->
    ct:log("Side producer doing its work"),
    produce_cc_blocks(Config, 1),
    receive
        done ->
            ct:log("Side producer DONE")
    after Delay ->
        side_producer(Config, Delay, MaxProduce - 1)
    end.

set_up_third_node(Config) ->
    %% Get up to speed with block production

    Ns = ?config(nodes, Config),
    Config0 = [{nodes, lists:droplast(Ns)} | Config],

    SideProducer = spawn_link(fun() -> side_producer(Config0, ?CHILD_BLOCK_TIME div 2, 20) end),

    {Node3, NodeName, Stakers, _Pinners} = lists:keyfind(?NODE3, 1, ?config(nodes, Config)),
    Nodes = [ Node || {Node, _, _, _} <- ?config(nodes, Config)],
    aecore_suite_utils:make_multi(Config, [Node3]),
    Env = [ {"AE__FORK_MANAGEMENT__NETWORK_ID", binary_to_list(?config(network_id, Config))} ],
    child_node_config(Node3, Stakers, [], Config), % no pinners here FTM
    aecore_suite_utils:start_node(Node3, Config, Env),
    aecore_suite_utils:connect(NodeName, []),
    timer:sleep(500),
    Node3Peers = rpc(Node3, aec_peers, connected_peers, []),
    ct:log("Connected peers ~p", [Node3Peers]),
    Node3VerifiedPeers = rpc(Node3, aec_peers, available_peers, [verified]),
    ct:log("Verified peers ~p", [Node3VerifiedPeers]),

    SideProducer ! done,
    stay_in_sync(Config0, Nodes, 50),
    %% What on earth are we testing here??
    Inspect =
        fun(Node) ->
            {ok, TopH} = aec_headers:hash_header(rpc(Node, aec_chain, top_header, [])),
            ct:log("     top hash ~p", [TopH]),
            ChainEnds = rpc(Node, aec_db, find_chain_end_hashes, []),
            lists:foreach(
                fun(Hash) ->
                    {value, D} = rpc(Node, aec_db, find_block_difficulty, [Hash]),
                    {value, H} = rpc(Node, aec_db, dirty_find_header, [Hash]),
                    ct:log("     Chain end with ~p has difficulty ~p", [H, D]),
                    ok
                end,
                ChainEnds)
        end,
    ct:log("Node1 point of view:", []),
    Inspect(?NODE1),
    ct:log("Node2 point of view:", []),
    Inspect(?NODE2),
    ct:log("Node3 point of view:", []),
    Inspect(?NODE3),
    ok.

stay_in_sync(_, Nodes, 0) ->
    wait_same_top(Nodes, 1);
stay_in_sync(Config, Nodes, N) ->
    case safe_wait(Nodes, 1) of
        ok -> ok;
        error ->
            ct:log("Not yet ~p more attempts", [N-1]),
            produce_cc_blocks(Config, 1),
            stay_in_sync(Config, Nodes, N - 1)
    end.

safe_wait(Nodes, N) ->
    try
      wait_same_top(Nodes, N),
      ok
    catch _:_ ->
      error
    end.

sync_third_node(Config) ->
    set_up_third_node(Config).

empty_parent_block(_Config) ->
    case aect_test_utils:latest_protocol_version() < ?CERES_PROTOCOL_VSN of
        true ->
            {skip, lazy_leader_sync_broken_on_iris};
        false ->
            %% empty_parent_block_(Config)
            {skip, todo}
    end.

sanity_check_vote_tx(Config) ->
    [{Node1, _, _, _}, {Node2, _, _, _} | _] = ?config(nodes, Config),

    {ok, #{epoch := Epoch}} = rpc(Node1, aec_chain_hc, epoch_info, []),
    %% Push a vote tx onto node1 - then read on node2
    {ok, VoteTx1} = aec_hc_vote_tx:new(#{voter_id => aeser_id:create(account, pubkey(?ALICE)),
                                         epoch    => Epoch,
                                         type     => 4,
                                         data     => #{<<"key1">> => <<"value1">>,
                                                       <<"key2">> => <<"value2">>}}),
    {_, HCVoteTx1} = aetx:specialize_type(VoteTx1),

    NetworkId = rpc(Node1, aec_governance, get_network_id, []),
    SVoteTx1 = sign_tx(VoteTx1, privkey(?ALICE), NetworkId),

    ok = rpc(Node1, aec_hc_vote_pool, push, [SVoteTx1]),
    timer:sleep(10),
    {ok, [HCVoteTx1]} = rpc(Node2, aec_hc_vote_pool, peek, [Epoch]),

    %% Test GC
    mine_to_next_epoch(Node2, Config),

    timer:sleep(10),
    {ok, []} = rpc(Node1, aec_hc_vote_pool, peek, [Epoch]),
    {ok, []} = rpc(Node2, aec_hc_vote_pool, peek, [Epoch]),

    ok.

initial_validators(Config) ->
    {ok, Leaders} = inspect_staking_contract(?ALICE, leaders, Config),
    ?assertEqual(2, length(Leaders)),

    fetch_validator_contract(?ALICE, Config),
    fetch_validator_contract(?LISA, Config),
    ok.

fetch_validator_contract(Who, Config) ->
    {ok, CtEnc} = inspect_staking_contract(Who, {get_validator_contract, Who}, Config),
    {ok, Ct} = aeser_api_encoder:safe_decode(contract_pubkey, CtEnc),
    Ct.

verify_rewards(Config) ->
    [{Node, _NodeName, _, _} | _ ] = ?config(nodes, Config),
    NetworkId = ?config(network_id, Config),
    {_, PatronPub} = aecore_suite_utils:sign_keys(Node),

    Height = rpc(Node, aec_chain, top_height, []),
    {ok, #{first := First0}} = rpc(Node, aec_chain_hc, epoch_info, []),

    %% grab Alice's and Bob's staking validator contract
    AliceCt = fetch_validator_contract(?ALICE, Config),
    BobCt = fetch_validator_contract(?BOB, Config),
    LisaCt = fetch_validator_contract(?LISA, Config),

    %% Assert we are at the beginning of an epoch
    [ mine_to_next_epoch(Node, Config) || Height + 1 /= First0 ],
    {ok, EpochInfo} = rpc(Node, aec_chain_hc, epoch_info, []),

    %% Now fill this generation with known stuff
    {ok, _} = produce_cc_blocks(Config, 2),

    {ok, SignedTx1} = seed_account(PatronPub, 1, NetworkId),
    {ok, _} = produce_cc_blocks(Config, 1),
    ?assertEqual(aetx:fee(aetx_sign:tx(SignedTx1)), ?FEE_REWARD),

    {ok, _SignedTx2} = seed_account(PatronPub, 1, NetworkId),
    {ok, _} = produce_cc_blocks(Config, 1),

    %% Now skip to the next-next epoch where rewards should have been payed
    mine_to_next_epoch(Node, Config),
    mine_to_last_block_in_epoch(Node, Config),

    GetValidatorBalance =
        fun(Who, Ct) ->
            {ok, Bal} = inspect_validator(Ct, Who, get_total_balance, Config),
            Bal
        end,
    Validators = [{?ALICE, AliceCt}, {?BOB, BobCt}, {?LISA, LisaCt}],

    %% Record the state
    PreRewardState = [ {Who, GetValidatorBalance(Who, Ct)} || {Who, Ct} <- Validators ],

    %% Produce final block to distribute rewards.
    {ok, _} = produce_cc_blocks(Config, 1),

    %% Record the new state
    PostRewardState = [ {Who, GetValidatorBalance(Who, Ct)} || {Who, Ct} <- Validators ],

    %% To calculate the rewards we need the producer of First-1 and Last+1...
    #{first := First, last := Last} = EpochInfo,
    {ok, Blocks} = get_generations(Node, First - 1, Last + 1),
    {ok, BlocksInGen} = get_generations(Node, First, Last),
    LeaderMap = maps:from_list([{aec_blocks:height(B),
                                 {aec_blocks:miner(B), aec_headers:is_hole(aec_blocks:to_key_header(B))}}
                                || B <- Blocks, key == aec_blocks:type(B)]),

    Rewards = calc_rewards(BlocksInGen, LeaderMap, Node),

    CheckRewards =
        fun(Who, Rs, PreS, PostS) ->
            case maps:get(pubkey(Who), Rs, undefined) of
                undefined ->
                    ct:log("~p got no rewards", [user(Who)]);
                Reward ->
                    {_, Tot0} = lists:keyfind(Who, 1, PreS),
                    {_, Tot1} = lists:keyfind(Who, 1, PostS),
                    ct:log("~p ~p -> ~p expected reward ~p", [user(Who), Tot0, Tot1, Reward]),
                    ?assertEqual(Tot0 + Reward, Tot1)
            end
        end,

    [ CheckRewards(Who, Rewards, PreRewardState, PostRewardState) || Who <- [?ALICE, ?BOB, ?LISA] ],

    %% Check that MainStaking knows the right epoch.
    {ok, #{epoch := Epoch}} = rpc(Node, aec_chain_hc, epoch_info, []),
    {ok, Epoch} = inspect_staking_contract(?ALICE, get_current_epoch, Config),

    ok.

calc_rewards(Blocks, LeaderMap, Node) ->
    calc_rewards(Blocks, LeaderMap, Node, #{}).

calc_rewards([], _LeaderMap, _Node, Rs) -> Rs;
calc_rewards([B | Bs], LeaderMap, Node, Rs) ->
    case aec_blocks:type(B) of
        micro -> calc_rewards(Bs, LeaderMap, Node, Rs);
        key ->
            Height = aec_blocks:height(B),
            {R0, R1, R2} =
                case aec_blocks:prev_key_hash(B) == aec_blocks:prev_hash(B) of
                    true  -> {0, ?BLOCK_REWARD, 0};
                    false ->
                        [{H, _}] = rpc(Node, aec_db, find_key_headers_and_hash_at_height, [aec_blocks:height(B)]),
                        {value, Fees} = rpc(Node, aec_db, find_block_fees, [H]),
                        {30 * (Fees div 100), ?BLOCK_REWARD + 50 * (Fees div 100), 20 * (Fees div 100)}
                end,
            Rs1 = lists:foldl(fun({Rx, Hx}, RsX) ->
                                  case maps:get(Hx, LeaderMap) of
                                      {_, true}  -> RsX;
                                      {M, false} -> RsX#{M => Rx + maps:get(M, RsX, 0)}
                                  end
                              end, Rs, [{R0, Height - 1}, {R1, Height}, {R2, Height + 1}]),
            calc_rewards(Bs, LeaderMap, Node, Rs1)
    end.


block_difficulty(Config) ->
    lists:foreach(
        fun(_) ->
            {ok, [KB]} = produce_cc_blocks(Config, 1),
            {ok, AddedStakingPower} = inspect_election_contract(?ALICE, current_added_staking_power, Config),
            Target = aec_blocks:target(KB),
            {Target, Target} = {Target, aeminer_pow:integer_to_scientific(AddedStakingPower)}
        end,
        lists:seq(1, 20)), %% test with 20 elections
    ok.

elected_leader_did_not_show_up(Config) ->
    case aect_test_utils:latest_protocol_version() < ?CERES_PROTOCOL_VSN of
        true ->
            {skip, lazy_leader_sync_broken_on_iris};
        false ->
            elected_leader_did_not_show_up_(Config)
    end.

elected_leader_did_not_show_up_(Config) ->
    aecore_suite_utils:stop_node(?NODE1, Config), %% stop the block producer
    TopHeader0 = rpc(?NODE2, aec_chain, top_header, []),
    {TopHeader0, TopHeader0} = {rpc(?NODE3, aec_chain, top_header, []), TopHeader0},
    ct:log("Starting test at (child chain): ~p", [TopHeader0]),
    %% produce a block on the parent chain
    produce_cc_blocks(Config, 1),
    {ok, KB} = wait_same_top([?NODE2, ?NODE3]),
    0 = aec_blocks:difficulty(KB),
    TopHeader1 = rpc(?NODE3, aec_chain, top_header, []),
    ct:log("Lazy header: ~p", [TopHeader1]),
    TopHeader1 = rpc(?NODE2, aec_chain, top_header, []),
    NetworkId = ?config(network_id, Config),
    Env = [ {"AE__FORK_MANAGEMENT__NETWORK_ID", binary_to_list(NetworkId)} ],
    aecore_suite_utils:start_node(?NODE1, Config, Env),
    aecore_suite_utils:connect(?NODE1_NAME, []),
    produce_cc_blocks(Config, 1),
    {ok, _} = wait_same_top([?NODE1, ?NODE3]),
    timer:sleep(2000), %% Give NODE1 a moment to finalize sync and post commitments
    produce_cc_blocks(Config, 1),
    {ok, _KB1} = wait_same_top([ Node || {Node, _, _, _} <- ?config(nodes, Config)]),
    {ok, _} = produce_cc_blocks(Config, 10),
    {ok, _KB2} = wait_same_top([ Node || {Node, _, _, _} <- ?config(nodes, Config)]),
    ok.

first_leader_next_epoch(Config) ->
    [{Node, _, _, _} | _] = ?config(nodes, Config),
    produce_cc_blocks(Config, 1),
    StartHeight = rpc(Node, aec_chain, top_height, []),
    {ok, #{last := Last, epoch := Epoch}} = rpc(Node, aec_chain_hc, epoch_info, [StartHeight]),
    ct:log("Checking leader for first block next epoch ~p (height ~p)", [Epoch+1, Last+1]),
    ?assertMatch({ok, _}, rpc(Node, aec_consensus_hc, leader_for_height, [Last + 1])).

%% Demonstrate that child chain start signalling epoch length adjustment upward
%% When parent blocks are produced too slowly, we need to lengthen child epoch
epochs_with_slow_parent(Config) ->
    [{Node, _, _, _} | _] = ?config(nodes, Config),
    ct:log("Parent start height = ~p", [?config(parent_start_height, Config)]),

    %% Align with wallclock
    produce_cc_blocks(Config, 1),

    %% ensure start at a new epoch boundary
    produce_until_next_epoch(Config),

    %% some block production including parent blocks
    produce_n_epochs(Config, 2),

    ParentHeight = rpc(?PARENT_CHAIN_NODE, aec_chain, top_height, []),
    ct:log("Child continues while parent stuck at: ~p", [ParentHeight]),
    ParentEpoch = (ParentHeight - ?config(parent_start_height, Config) +
                      (?PARENT_EPOCH_LENGTH - 1)) div ?PARENT_EPOCH_LENGTH,
    ChildEpoch = rpc(Node, aec_chain, top_height, []) div ?CHILD_EPOCH_LENGTH,
    ct:log("Child epoch ~p while parent epoch ~p (parent should be in next epoch)", [ChildEpoch, ParentEpoch]),
    ?assertEqual(1, ParentEpoch - ChildEpoch),

    Resilience = 1, %% Child can cope with missing Resilience epochs in parent chain
    %% Produce no parent block in the next Resilience child epochs
    %% the child chain should get to a halt or
    %% at least one should be able to observe signalling that the length should be adjusted upward
    {ok, _} = produce_cc_blocks(Config, ?CHILD_EPOCH_LENGTH*Resilience, #{parent_produce => []}),

    ct:log("Mined almost ~p additional child epochs without parent progress", [Resilience]),
    ParentTopHeight = rpc(?PARENT_CHAIN_NODE, aec_chain, top_height, []),
    ?assertEqual(ParentHeight, ParentTopHeight),
    ChildTopHeight = rpc(Node, aec_chain, top_height, []),
    {ok, #{epoch := EndEpoch, length := EpochLength}} = rpc(Node, aec_chain_hc, epoch_info, [ChildTopHeight]),
    ct:log("Parent at height ~p and child at height ~p in child epoch ~p",
           [ParentTopHeight, ChildTopHeight, EndEpoch]),

    %% Parent hash grabbed in last block child epoch, so here we can start, but not finish next epoch
    {ok, _} = produce_cc_blocks(Config, EpochLength - 1, #{parent_produce => []}),

    %% Here we should get stuck... Short timeout to not get too far behind.
    ProduceOpts = #{timeout => 1000, parent_produce => []},
    ?assertException(error, timeout_waiting_for_block, produce_cc_blocks(Config, 1, ProduceOpts)),

    ?assertEqual([{ok, (N-1) * ?CHILD_EPOCH_LENGTH + 1} || N <- lists:seq(1, EndEpoch)],
                 [rpc(Node, aec_chain_hc, epoch_start_height, [N]) || N <- lists:seq(1, EndEpoch)]),

    %% Quickly produce parent blocks to be in sync again
    ParentBlocksNeeded =
        (EndEpoch - 1) * ?PARENT_EPOCH_LENGTH + ?config(parent_start_height, Config) + ?PARENT_FINALITY - ParentTopHeight,

    {ok, _} = produce_cc_blocks(Config, 1, #{parent_produce => [{ChildTopHeight + EpochLength, ParentBlocksNeeded}]}),

    #{epoch_length := FinalizeEpochLength, epoch := FinalizeEpoch} = rpc(Node, aec_chain_hc, finalize_info, []),
    %% We missed EoE, so no adjustment here...
    ct:log("The agreed epoch length is ~p the current length is ~p for epoch ~p", [FinalizeEpochLength, EpochLength, FinalizeEpoch]),
    ?assert(FinalizeEpoch < EndEpoch),

    %% advance
    produce_cc_blocks(Config, ?CHILD_EPOCH_LENGTH),

    #{epoch_length := FinalizeEpochLength1, epoch := FinalizeEpoch1} = rpc(Node, aec_chain_hc, finalize_info, []),
    ct:log("The agreed epoch length is ~p the current length is ~p for epoch ~p", [FinalizeEpochLength1, EpochLength, FinalizeEpoch1]),
    ?assert(FinalizeEpochLength1 > FinalizeEpochLength),


    ok.

%% Demonstrate that child chain start signalling epoch length adjustment downward
%% When parent blocks are produced too quickly, we need to shorten child epoch
epochs_with_fast_parent(Config) ->
    [{Node, _, _, _} | _] = ?config(nodes, Config),

    %% ensure start at a new epoch boundary
    produce_until_next_epoch(Config),

    {ok, #{length := Len1} = EpochInfo1} = rpc(Node, aec_chain_hc, epoch_info, []),
    ct:log("Info ~p", [EpochInfo1]),

    %% Produce twice as many parent blocks as needed in an epoch
    Height0 = rpc(Node, aec_chain, top_height, []),
    ParentTopHeight0 = rpc(?PARENT_CHAIN_NODE, aec_chain, top_height, []),
    {ok, #{length := Len1}} = rpc(Node, aec_chain_hc, epoch_info, []),
    {ok, _} = produce_cc_blocks(Config, Len1,
                                #{parent_produce => spread(2*?PARENT_EPOCH_LENGTH, Height0,
                                                           [ {CH, 0} || CH <- lists:seq(Height0 + 1, Height0 + Len1)])}),

    ParentTopHeight1 = rpc(?PARENT_CHAIN_NODE, aec_chain, top_height, []),
    Height1 = rpc(Node, aec_chain, top_height, []),
    {ok, #{length := Len2} = EpochInfo2} = rpc(Node, aec_chain_hc, epoch_info, []),
    ct:log("Parent at height ~p and child at height ~p in child epoch ~p",
           [ParentTopHeight1, Height1, EpochInfo2]),
    ?assertEqual(2*?PARENT_EPOCH_LENGTH, ParentTopHeight1 - ParentTopHeight0),

    {ok, _} = produce_cc_blocks(Config, Len2,
                                #{parent_produce => spread(2*?PARENT_EPOCH_LENGTH, Height1,
                                                           [ {CH, 0} || CH <- lists:seq(Height1 + 1, Height1 + Len2)])}),

    {ok, #{length := Len3, epoch := CurrentEpoch}} = rpc(Node, aec_chain_hc, epoch_info, []),
    produce_cc_blocks(Config, Len3),
    #{epoch_length := FinalizeEpochLength, epoch := FinalizeEpoch} = rpc(Node, aec_chain_hc , finalize_info, []),
    %% Here we should be able to observe signalling that epoch should be shorter
    ct:log("The agreed epoch length is ~p three epochs previous length was ~p", [FinalizeEpochLength, Len1]),
    ?assert(CurrentEpoch == FinalizeEpoch),
    lists:foreach(fun(_) -> {ok, #{length := CurrentEpochLen}} = rpc(Node, aec_chain_hc, epoch_info, []),
                             produce_cc_blocks(Config, CurrentEpochLen) end, lists:seq(1, 2)),

    {ok, #{length := AdjEpochLength} = EpochInfo3} = rpc(Node, aec_chain_hc, epoch_info, []),
    ?assertEqual(FinalizeEpochLength, AdjEpochLength),
    ?assert(FinalizeEpochLength < Len1),
    ct:log("Info ~p", [EpochInfo3]),

    ok.

producer_node(Producer, Config) ->
    [Node] = [ Name || {_, Name, Keys, _} <- ?config(nodes, Config),
                       lists:keymember(Producer, 1, Keys) ],
    Node.

blocks_by_node(Node, Validators, Config) ->
    blocks_by_node(Node, Validators, Config, 0).

blocks_by_node(_Node, [], _Config, N) -> N;
blocks_by_node(Node, [V | Vs], Config, N) ->
    case producer_node(V, Config) of
        Node -> blocks_by_node(Node, Vs, Config, N + 1);
        _    -> N
    end.

hole_production(Config) ->
    %% Repeat this 3 times...
    hole_production(Config, 3).

hole_production(Config, N) ->
    [{Node, _, _, _} | _] = ?config(nodes, Config),

    %% Get the schedule
    ChildHeight = rpc(Node, aec_chain, top_height, []),
    {ok, #{validators := Validators, epoch := Epoch, length := Length, first := First}} =
        rpc(Node, aec_chain_hc, epoch_info, []),

    {_, Seed} = get_entropy(Node, Epoch),
    {ok, Schedule0} = rpc(Node, aec_chain_hc, validator_schedule, [ChildHeight, Seed, Validators, Length]),

    %% It seems sometimes we end up not at the first block of the epoch...
    Offset = ChildHeight + 1 - First,
    {_, Schedule} = lists:split(Offset, Schedule0),

    NextProducer = hd(Schedule),
    NextProdNode = producer_node(NextProducer, Config),
    AllNodes = [ Name || {_, Name, _, _} <- ?config(nodes, Config) ],

    ct:log("Next producer is: ~p", [NextProdNode]),

    NHoles = blocks_by_node(NextProdNode, Schedule, Config),

    Skip = NHoles > 3 orelse NHoles == Length - Offset,
    if Skip ->
        ct:log("Skip test, too many holes in a row potential timing issue!");
       true ->
        ct:log("Produce on: ~p", [AllNodes -- [NextProdNode]]),
        {ok, Bs} = produce_cc_blocks(Config, 1, #{prod_nodes => AllNodes -- [NextProdNode]}),
        ct:pal("Expected ~p holes, got ~p", [NHoles, length(Bs) - 1]),
        ?assert(NHoles + 1 == length(Bs))
    end,

    N1 = if Skip -> N; true -> N - 1 end,
    if N1 > 0 ->
        produce_until_next_epoch(Config),
        hole_production(Config, N1);
       true ->
        ok
    end.

hole_production_eoe(Config) ->
    [{Node, _, _, _} | _] = ?config(nodes, Config),

    %% Avoid desync
    produce_cc_blocks(Config, 1),

    mine_to_last_block_in_epoch(Node, Config),

    %% Get the schedule
    ChildHeight = rpc(Node, aec_chain, top_height, []),
    {ok, #{validators := Validators, epoch := Epoch, length := Length, last := Last}} =
        rpc(Node, aec_chain_hc, epoch_info, []),

    ?assertEqual(ChildHeight, Last - 1),

    {_, Seed} = get_entropy(Node, Epoch),
    {ok, Schedule} = rpc(Node, aec_chain_hc, validator_schedule, [ChildHeight, Seed, Validators, Length]),

    EOEProducer = lists:last(Schedule),
    EOEProdNode = producer_node(EOEProducer, Config),
    AllNodes = [ Name || {_, Name, _, _} <- ?config(nodes, Config) ],
    ct:log("Produce on: ~p", [AllNodes -- [EOEProdNode]]),
    {ok, Bs} = produce_cc_blocks(Config, 1, #{prod_nodes => AllNodes -- [EOEProdNode]}),
    Holes = length([ x || B <- Bs, key == aec_blocks:type(B) ]),
    ct:pal("Expected at least 1 hole, got ~p", [Holes]),
    ?assert(Holes > 1),

    %% Make sure chain works moving forward
    produce_n_epochs(Config, 2),

    ok.



%%%=============================================================================
%%% HC Endpoints
%%%=============================================================================

get_contract_pubkeys(Config) ->
    [{Node, _, _, _} | _] = ?config(nodes, Config),
    %% Verify that endpoint is available
    {ok, IsChildChain} = rpc(Node, aeu_env, find_config,
                             [[<<"http">>, <<"endpoints">>, <<"hyperchain">>], [user_config, schema_default]]),
    ?assert(IsChildChain),
    StakingContractPK = rpc(Node, aec_consensus_hc, get_contract_pubkey, [staking]),
    ElectionContractPK = rpc(Node, aec_consensus_hc, get_contract_pubkey, [election]),
    RewardsContractPK = rpc(Node, aec_consensus_hc, get_contract_pubkey, [rewards]),
    ct:log("Calling hyperchain/contracts at ~p", [aecore_suite_utils:external_address()]),
    {ok, 200, Repl1} = aecore_suite_utils:http_request(aecore_suite_utils:external_address(), get, "hyperchain/contracts", []),
    #{<<"staking">> := Staking,
      <<"election">> := Election,
      <<"rewards">> := Rewards
    } = Repl1,
    ?assertEqual({ok, StakingContractPK}, aeser_api_encoder:safe_decode(contract_pubkey, Staking)),
    ?assertEqual({ok, ElectionContractPK}, aeser_api_encoder:safe_decode(contract_pubkey, Election)),
    ?assertEqual({ok, RewardsContractPK}, aeser_api_encoder:safe_decode(contract_pubkey, Rewards)),

    ok.


%%%=============================================================================
%%% Pinning
%%%=============================================================================

get_pin(Config) ->
    [{Node, _, _, _} | _] = ?config(nodes, Config),
    %% Verify that endpoint is available
    {ok, IsChildChain} = rpc(Node, aeu_env, find_config,
                             [[<<"http">>, <<"endpoints">>, <<"hyperchain">>], [user_config, schema_default]]),
    ?assert(IsChildChain),

    %% Mine one block and derive which epoch we are in
    {ok, _} = produce_cc_blocks(Config, 1),
    {ok, #{epoch := Epoch} = EpochInfo1} = rpc(Node, aec_chain_hc, epoch_info, []),

    %% note: the pins are for the last block in previous epoch
    {ok, 200, Repl1} = aecore_suite_utils:http_request(aecore_suite_utils:external_address(), get, "hyperchain/pin-tx", []),
    #{<<"epoch">> := PrevEpoch,
      <<"height">> := Height1,
      <<"block_hash">> := BH1,
      <<"parent_payload">> := Payload} = Repl1,
    {ok, BH1Dec} = aeser_api_encoder:safe_decode(key_block_hash, BH1),
    ?assertEqual({epoch, Epoch - 1}, {epoch, PrevEpoch}),
    ?assertEqual(maps:get(first, EpochInfo1) - 1, Height1),
    {ok, IBH1} = rpc(?NODE1, aec_chain_state, get_key_block_hash_at_height, [Height1]),
    ?assertEqual(BH1Dec, IBH1),

    %% Verify that decoding function works on encoded payload:
    {ok, DecodedPin} = rpc(Node, aeser_hc, decode_parent_pin_payload, [Payload]),
    ?assertEqual(#{epoch => PrevEpoch, height => Height1, block_hash => BH1Dec},
                 DecodedPin),

    %% produce some more child blocks if we stay in same epoch, then pins should be the same
    {ok, _} = produce_cc_blocks(Config, 2),
    {ok, 200, Repl2} = aecore_suite_utils:http_request(aecore_suite_utils:external_address(), get, "hyperchain/pin-tx", []),
    {ok, EpochInfo2} = rpc(?NODE1, aec_chain_hc, epoch_info, []),
    %% Get response from being in next Epoch
    Repl3 =
        if EpochInfo1 == EpochInfo2 ->
             ?assertEqual(Repl1, Repl2),
             {ok, _} = produce_cc_blocks(Config, maps:get(length, EpochInfo2) - 1),
             {ok, 200, Repl} = aecore_suite_utils:http_request(aecore_suite_utils:external_address(), get, "hyperchain/pin-tx", []),
             Repl;
           true -> Repl2
        end,
    %% Verfify for the next epoch as well
    #{<<"epoch">> := NextEpoch, <<"height">> := Height2, <<"block_hash">> := BH2} = Repl3,
    {ok, BH2Dec} = aeser_api_encoder:safe_decode(key_block_hash, BH2),
    %% Now the epoch we started with is the one we take the pin from
    ?assertEqual({epoch, Epoch}, {epoch, NextEpoch}),
    ?assertEqual(maps:get(last, EpochInfo1), Height2),
    {ok, IBH2} = rpc(?NODE1, aec_chain_state, get_key_block_hash_at_height, [Height2]),
    ?assertEqual(BH2Dec, IBH2),
    ok.

%% A wallet posting a pin transaction by only using HTTP API towards Child and Parent
wallet_post_pin_to_pc(Config) ->
    [{Node, _, _, _} | _] = ?config(nodes, Config),

    %% Progress to first block of next epoch
    Height1 = rpc(?NODE1, aec_chain, top_height, []),
    {ok, #{last := Last1, length := Len, epoch := Epoch}} = rpc(Node, aec_chain_hc, epoch_info, []),
    {ok, Bs} = produce_cc_blocks(Config, Last1 - Height1 + 1),
    HashLastInEpoch = aec_blocks:prev_hash(lists:last(Bs)),
    ct:log("Block last epoch: ~p", [aeser_api_encoder:encode(key_block_hash, HashLastInEpoch)]),

    DwightPub = pubkey(?DWIGHT),
    DwightEnc = aeser_api_encoder:encode(account_pubkey, DwightPub),
    %% Get the block hash of the last block of previous epoch wrapped in a specified payload
    {ok, 200, #{<<"parent_payload">> := Payload,
                <<"epoch">> := E, <<"height">> := H,
                <<"block_hash">> := BH,
                <<"last_leader">> := LastLeader}} =
        aecore_suite_utils:http_request(aecore_suite_utils:external_address(), get, "hyperchain/pin-tx", []),
    ?assertEqual(E, Epoch),
    ?assertEqual(H, Last1),
    ?assertEqual(BH, aeser_api_encoder:encode(key_block_hash, HashLastInEpoch)),

    %% The wallet talks to "its own version" of the parent chain
    %% Here typically the only node
    ParentHost = external_address(?PARENT_CHAIN_NODE),
    ct:log("Parent address ~p", [ParentHost]),
    {ok, 200, DwightInfo} = aecore_suite_utils:http_request(ParentHost, get, <<"accounts/", DwightEnc/binary>>, []),
    Nonce = maps:get(<<"nonce">>, DwightInfo) + 1,
    {ok, PinTx} = create_ae_spend_tx(DwightPub, DwightPub, Nonce, Payload),
    ct:log("Unsigned Spend on parent chain ~p", [PinTx]),

    SignedPinTx = sign_tx(PinTx, privkey(?DWIGHT), ?PARENT_CHAIN_NETWORK_ID),
    Transaction = aeser_api_encoder:encode(transaction, aetx_sign:serialize_to_binary(SignedPinTx)),
    {ok, 200, #{<<"tx_hash">> := ProofHash}} = aecore_suite_utils:http_request(ParentHost, post, <<"transactions">>, #{tx => Transaction}),
    {ok, [_]} = rpc(?PARENT_CHAIN_NODE, aec_tx_pool, peek, [infinity]), % one transaction pending now.
    {ok, _} = produce_cc_blocks(Config, Len div 2),
    {ok, []} = rpc(?PARENT_CHAIN_NODE, aec_tx_pool, peek, [infinity]), % all transactions comitted

    %% Don't wait and check for the height of acceptance, because due to parent fork micro forks,
    %% this may change in a while... the last leader will do the work needed on the hashes
    %% it receives

    %% Now just inform the last leader of this epoch about the transaction hash
    %% via a spend on child chain... the leader will have machinery to pick up tx hash
    %% and to find out at which parent height the hash is accepted at
    % ProofHash = list_to_binary("PIN"++TxHash), % the hash comes encoded already
    {_, LeaderPubkey} = aeser_api_encoder:decode(LastLeader),
    NonceAlice = next_nonce(Node, pubkey(?ALICE)),
    Params = #{ sender_id    => aeser_id:create(account, pubkey(?ALICE)),
                recipient_id => aeser_id:create(account, LeaderPubkey),
                amount       => 1,
                fee          => 30000 * ?DEFAULT_GAS_PRICE,
                nonce        => NonceAlice,
                payload      => ProofHash},
    ct:log("Preparing a spend tx for child chain: ~p", [Params]),
    {ok, ProofTx} = aec_spend_tx:new(Params),
    SignedProofTx = sign_tx(ProofTx, privkey(?ALICE), ?config(network_id, Config)),
    ProofTransaction = aeser_api_encoder:encode(transaction, aetx_sign:serialize_to_binary(SignedProofTx)),
    {ok, 200, _} = aecore_suite_utils:http_request(aecore_suite_utils:external_address(), post, <<"transactions">>, #{tx => ProofTransaction}),

    {ok, [_]} = rpc(Node, aec_tx_pool, peek, [infinity]), % transactions in pool
    {ok, _} = produce_cc_blocks(Config, 1),
    {ok, []} = rpc(Node, aec_tx_pool, peek, [infinity]), % transactions in pool

    Height2 = rpc(Node, aec_chain, top_height, []),
    {ok, #{last := CollectHeight}} = rpc(Node, aec_chain_hc, epoch_info, []),
    %% mine to CollectHeight and TODO: see that indeed the proof has been used
    {ok, _} = produce_cc_blocks(Config, CollectHeight - Height2),
    ok.

check_default_pin(Config) ->
    [{Node, NodeName, _, _} | _] = ?config(nodes, Config),

    {ok, _} = produce_cc_blocks(Config, 12),
    {ok, #{last := Last}} = rpc(Node, aec_chain_hc, epoch_info, []),
    {ok, LastLeader} = rpc(Node, aec_consensus_hc, leader_for_height, [Last]),
    ct:log("Last Leader: ~p", [LastLeader]),

    mine_to_last_block_in_epoch(Node, Config),

    aecore_suite_utils:subscribe(NodeName, pin),

    {ok, _} = produce_cc_blocks(Config, 2),
    %% with current test setup, all validators have a pc account, so pins will always happen(?)
    {ok, #{info := {pin_accepted, _}}} = wait_for_ps(pin),

    aecore_suite_utils:unsubscribe(NodeName, pin),

    %% TODO test when not all validators have PC account, but how ensure
    %% that any given validator will be last leader within the run of the test???

    ok.

fast_parent_fail_pin(Config) ->
    [{Node, NodeName, _, _} | _] = ?config(nodes, Config),

    %% ensure start at a new epoch boundary
    produce_until_next_epoch(Config),

    aecore_suite_utils:subscribe(NodeName, pin),

    %% Produce twice as many parent blocks as needed in an epoch
    Height0 = rpc(Node, aec_chain, top_height, []),
    ParentTopHeight0 = rpc(?PARENT_CHAIN_NODE, aec_chain, top_height, []),
    {ok, #{length := Len1}} = rpc(Node, aec_chain_hc, epoch_info, []),
    {ok, _} = produce_cc_blocks(Config, Len1,
                                #{parent_produce => spread(2*?PARENT_EPOCH_LENGTH, Height0,
                                                            [ {CH, 0} || CH <- lists:seq(Height0 + 1, Height0 + Len1)])}),

    {ok, #{info := {pin_accepted, _}}} = wait_for_ps(pin),

    Height1 = rpc(Node, aec_chain, top_height, []),
    ParentTopHeight1 = rpc(?PARENT_CHAIN_NODE, aec_chain, top_height, []),
    {ok, #{length := Len2}} = rpc(Node, aec_chain_hc, epoch_info, []),
    {ok, _} = produce_cc_blocks(Config, Len1,
                                #{parent_produce => spread(2*?PARENT_EPOCH_LENGTH, Height1,
                                                            [ {CH, 0} || CH <- lists:seq(Height1 + 1, Height1 + Len2)])}),

    % we are still within sync margin, even though we are three blocks too fast
    {ok, #{info := {pin_accepted, _}}} = wait_for_ps(pin),

    produce_until_next_epoch(Config),

    % pin validation  fails due to incorrectly synced parent chain (it's too fast, even including margin of one epoch length...)
    {ok, #{info := {incorrect_proof_posted}}} = wait_for_ps(pin),

    aecore_suite_utils:unsubscribe(NodeName, pin),


    ok.


%%%=============================================================================
%%% Elections
%%%=============================================================================

check_finalize_info(Config) ->
    [{Node, _, _, _} | _] = ?config(nodes, Config),
    mine_to_next_epoch(Node, Config),
    {ok, #{epoch  := Epoch,
           last   := Last,
           validators := Validators,
           length := _Length}} = rpc(Node, aec_chain_hc, epoch_info, []),
    {ok, LastLeader} = rpc(Node, aec_consensus_hc, leader_for_height, [Last]),
    mine_to_last_block_in_epoch(Node, Config),
    {ok, _} = produce_cc_blocks(Config, 2),
    {ok, EOEBlock} = rpc(Node, aec_chain, get_key_block_by_height, [Last]),
    ?assertEqual(aec_blocks:target(EOEBlock), Last),
    ?assert(aec_blocks:is_eoe(EOEBlock)),
    #{producer := Producer, epoch := FEpoch, votes := Votes, fork := PrevHash} = rpc(Node, aec_chain_hc, finalize_info, []),
    ?assertEqual(aec_blocks:miner(EOEBlock), Producer),
    ?assertEqual(aec_blocks:prev_key_hash(EOEBlock), PrevHash),
    FVoters = lists:map(fun(#{producer := Voter}) -> Voter end, Votes),
    ct:log("Votes: ~p", [Votes]),
    TotalStake = lists:foldl(fun({_, Stake}, Accum) -> Stake + Accum end, 0, Validators),
    VotersStake = lists:foldl(fun(Voter, Accum) -> proplists:get_value(Voter, Validators) + Accum end, 0, FVoters),
    TotalVotersStake = proplists:get_value(LastLeader, Validators) + VotersStake,
    ?assertEqual(Epoch, FEpoch),
    ?assertEqual(Producer, LastLeader),
    MajorityVotes = (2 * TotalStake + 2) div 3,
    ct:pal("~p >= ~p", [TotalVotersStake, MajorityVotes]),
    ?assert(TotalVotersStake >= MajorityVotes).


%%% --------- pinning helpers

wait_for_ps(Event) ->
    receive
        {gproc_ps_event, Event, Info} -> {ok, Info};
        Other -> error({wrong_signal, Other})
    end.

mine_to_last_block_in_epoch(Node, Config) ->
    {ok, #{epoch  := _Epoch,
           first  := _First,
           last   := Last,
           length := _Length}} = rpc(Node, aec_chain_hc, epoch_info, []),
    CH = rpc(Node, aec_chain, top_height, []),
    DistToBeforeLast = Last - CH - 1,
    {ok, _} = produce_cc_blocks(Config, DistToBeforeLast).

mine_to_next_epoch(Node, Config) ->
    Height1 = rpc(Node, aec_chain, top_height, []),
    {ok, #{last := Last1, length := _Len}} = rpc(Node, aec_chain_hc, epoch_info, []),
    {ok, Bs} = produce_cc_blocks(Config, Last1 - Height1 + 1),
    ct:log("Block last epoch: ~p", [Bs]).

produce_until_next_epoch(Config) ->
    [{Node, _, _, _} | _] = ?config(nodes, Config),

    StartHeight = rpc(Node, aec_chain, top_height, []),
    {ok, #{last := Last}} = rpc(Node, aec_chain_hc, epoch_info, []),
    BlocksLeftToBoundary = Last - StartHeight,
    %% some block production including parent blocks
    {ok, _} = produce_cc_blocks(Config, BlocksLeftToBoundary).

%%% --------- helper functions

pubkey({Pubkey, _, _}) -> Pubkey.

privkey({_, Privkey, _}) -> Privkey.

user({_, _, User}) -> User.

who_by_pubkey(Pubkey) ->
    Alice = pubkey(?ALICE),
    Bob = pubkey(?BOB),
    BobSign = pubkey(?BOB_SIGN),
    Lisa = pubkey(?LISA),
    Dwight = pubkey(?DWIGHT),
    Edwin = pubkey(?EDWIN),
    Genesis = ?GENESIS_BENFICIARY,
    case Pubkey of
        Alice -> ?ALICE;
        Bob -> ?BOB;
        BobSign -> ?BOB_SIGN;
        Lisa -> ?LISA;
        Dwight -> ?DWIGHT;
        Edwin -> ?EDWIN;
        Genesis -> genesis;
        _  -> error(unknown_beneficiary)
    end.

encoded_pubkey(Who) ->
    aeser_api_encoder:encode(account_pubkey, pubkey(Who)).

next_nonce(Node, Pubkey) ->
    case rpc(Node, aec_next_nonce, pick_for_account, [Pubkey, max]) of
        {ok, NextNonce} -> NextNonce;
        {error, account_not_found} -> 1
    end.

sign_and_push(NodeName, Tx, Who, NetworkId) ->
    SignedTx = sign_tx(Tx, privkey(Who), NetworkId),
    ok = rpc:call(NodeName, aec_tx_pool, push, [SignedTx, tx_received]),
    SignedTx.

%% usually we would use aec_test_utils:sign_tx/3. This function is being
%% executed in the context of the CT test and uses the corresponding
%% network_id. Since the network_id of the HC node is different, we must sign
%% the tx using the test-specific network_id
sign_tx(Tx, Privkey, NetworkId) ->
    Bin0 = aetx:serialize_to_binary(Tx),
    Bin = aec_hash:hash(signed_tx, Bin0), %% since we are in CERES context, we sign th hash
    BinForNetwork = <<NetworkId/binary, Bin/binary>>,
    Signatures = [ enacl:sign_detached(BinForNetwork, Privkey)],
    aetx_sign:new(Tx, Signatures).

seed_account(RecpipientPubkey, Amount, NetworkId) ->
    seed_account(?NODE1, RecpipientPubkey, Amount, NetworkId).

seed_account(Node, RecipientPubkey, Amount, NetworkId) ->
    NodeName = aecore_suite_utils:node_name(Node),
    {PatronPriv, PatronPub} = aecore_suite_utils:sign_keys(Node),
    Nonce = next_nonce(Node, PatronPub),
    Params =
        #{sender_id    => aeser_id:create(account, PatronPub),
          recipient_id => aeser_id:create(account, RecipientPubkey),
          amount       => Amount,
          fee          => 30000 * ?DEFAULT_GAS_PRICE,
          nonce        => Nonce,
          payload      => <<>>},
    ct:log("Preparing a spend tx: ~p", [Params]),
    {ok, Tx} = aec_spend_tx:new(Params),
    SignedTx = sign_tx(Tx, PatronPriv, NetworkId),
    ok = rpc:call(NodeName, aec_tx_pool, push, [SignedTx, tx_received]),
    {ok, SignedTx}.

account_balance(Pubkey) ->
    case rpc(?NODE1, aec_chain, get_account, [Pubkey]) of
        {value, Account} -> aec_accounts:balance(Account);
        none -> no_such_account
    end.

inspect_validator(Ct, Origin, What, Config) ->
    TopHash = rpc(?NODE1, aec_chain, top_block_hash, []),
    {Fun, Args} =
        case What of
            get_available_balance -> {"get_available_balance", []};
            get_total_balance     -> {"get_total_balance", []}
        end,
    do_contract_call(Ct, src(?STAKING_VALIDATOR_CONTRACT, Config), Fun, Args, Origin, TopHash).

inspect_staking_contract(OriginWho, WhatToInspect, Config) ->
    TopHash = rpc(?NODE1, aec_chain, top_block_hash, []),
    inspect_staking_contract(OriginWho, WhatToInspect, Config, TopHash).

inspect_staking_contract(OriginWho, WhatToInspect, Config, TopHash) ->
    {Fun, Args} =
        case WhatToInspect of
            {staking_power, Who} ->
                {"staking_power", [binary_to_list(encoded_pubkey(Who))]};
            {get_validator_state, Who} ->
                {"get_validator_state", [binary_to_list(encoded_pubkey(Who))]};
            {get_validator_contract, Who} ->
                {"get_validator_contract", [binary_to_list(encoded_pubkey(Who))]};
            get_current_epoch ->
                {"get_current_epoch", []};
            get_state ->
                {"get_state", []};
            leaders ->
                {"sorted_validators", []}

        end,
    ContractPubkey = ?config(staking_contract, Config),
    do_contract_call(ContractPubkey, src(?MAIN_STAKING_CONTRACT, Config), Fun, Args, OriginWho, TopHash).

inspect_election_contract(OriginWho, WhatToInspect, Config) ->
    TopHash = rpc(?NODE1, aec_chain, top_block_hash, []),
    inspect_election_contract(OriginWho, WhatToInspect, Config, TopHash).

inspect_election_contract(OriginWho, WhatToInspect, Config, TopHash) ->
    {Fun, Args} =
        case WhatToInspect of
            current_added_staking_power -> {"added_stake", []};
            _ -> {WhatToInspect, []}
        end,
    ContractPubkey = ?config(election_contract, Config),
    do_contract_call(ContractPubkey, src(?HC_CONTRACT, Config), Fun, Args, OriginWho, TopHash).

do_contract_call(CtPubkey, CtSrc, Fun, Args, Who, TopHash) ->
    F = fun() -> do_contract_call_(CtPubkey, CtSrc, Fun, Args, Who, TopHash) end,
    {T, Res} = timer:tc(F),
    ct:log("Calling contract took ~.2f ms", [T / 1000]),
    Res.

do_contract_call_(CtPubkey, CtSrc, Fun, Args, Who, TopHash) ->
    Tx = contract_call(CtPubkey, CtSrc, Fun, Args, 0, pubkey(Who)),
    {ok, Call} = dry_run(TopHash, Tx),
    decode_consensus_result(Call, Fun, CtSrc).

dry_run(TopHash, Tx) ->
    case rpc(?NODE1, aec_dry_run, dry_run, [TopHash, [], [{tx, Tx}]]) of
        {error, _} = Err -> Err;
        {ok, {[{contract_call_tx, {ok, Call}}], _Events}} -> {ok, Call}
    end.

call_info(SignedTx) ->
    Hash = aetx_sign:hash(SignedTx),
    case rpc:call(?NODE1_NAME, aec_chain, find_tx_location, [Hash]) of
        not_found ->  {error, unknown_tx};
        none -> {error, gced_tx};
        mempool -> {error, tx_in_pool};
        MBHash when is_binary(MBHash) ->
            case rpc:call(?NODE1_NAME, aehttp_helpers, get_info_object_signed_tx,
                          [MBHash, SignedTx]) of
                {ok, Call} -> {ok, Call};
                {error, Reason} -> {error, Reason}
            end
    end.

create_ae_spend_tx(SenderId, RecipientId, Nonce, Payload) ->
    Params = #{sender_id => aeser_id:create(account, SenderId),
               recipient_id => aeser_id:create(account, RecipientId),
               amount => 1,
               nonce => Nonce,
               fee => 40000 * ?DEFAULT_GAS_PRICE,
               payload => Payload},
    ct:log("Preparing a spend tx: ~p", [Params]),
    aec_spend_tx:new(Params).

external_address(Node) ->
    {ok, Port} = rpc(Node, aeu_env, user_config_or_env,
                     [[<<"http">>, <<"external">>, <<"port">>], aehttp, [external, port]]),
   "http://127.0.0.1:" ++ integer_to_list(Port).


decode_consensus_result(Call, Fun, Src) ->
    ReturnType = aect_call:return_type(Call),
    ReturnValue = aect_call:return_value(Call),
    Res = aect_test_utils:decode_call_result(Src, Fun, ReturnType, ReturnValue),
    {ReturnType, Res}.

src(ContractName, Config) ->
    Srcs = ?config(contract_src, Config),
    maps:get(ContractName, Srcs).

build_json_files(ElectionContract, NodeConfig, CTConfig) ->
    Pubkey = ?OWNER_PUBKEY,
    {_PatronPriv, PatronPub} = aecore_suite_utils:sign_keys(?NODE1),
    ct:log("Patron is ~p", [aeser_api_encoder:encode(account_pubkey, PatronPub)]),

    %% create staking contract
    MinStakeAmt = integer_to_list(trunc(math:pow(10,18) * 1)), %% 1 AE
    MSSrc = src(?MAIN_STAKING_CONTRACT, CTConfig),
    #{ <<"pubkey">> := StakingContractPubkey
     , <<"owner_pubkey">> := ContractOwner } = SC
        = contract_create_spec(?MAIN_STAKING_CONTRACT, MSSrc, [MinStakeAmt], 0, 1, Pubkey),
    {ok, StakingAddress} = aeser_api_encoder:safe_decode(contract_pubkey,
                                                         StakingContractPubkey),
    %% assert assumption
    StakingAddress = staking_contract_address(),

    %% create election contract
    #{ <<"pubkey">> := ElectionContractPubkey
     , <<"owner_pubkey">> := ContractOwner } = EC
        = contract_create_spec(ElectionContract, src(ElectionContract, CTConfig),
                               [binary_to_list(StakingContractPubkey)], 0, 2, Pubkey),
    {ok, ElectionAddress} = aeser_api_encoder:safe_decode(contract_pubkey,
                                                          ElectionContractPubkey),
    %% assert assumption
    ElectionAddress = election_contract_address(),
    {ok, SCId} = aeser_api_encoder:safe_decode(contract_pubkey, StakingContractPubkey),

    APub = binary_to_list(aeser_api_encoder:encode(account_pubkey, pubkey(?ALICE))),
    Call1 =
        contract_call_spec(SCId, MSSrc, "new_validator", [APub, APub, "true"],
                           ?INITIAL_STAKE, pubkey(?ALICE), 1),

    BPub = binary_to_list(aeser_api_encoder:encode(account_pubkey, pubkey(?BOB))),
    BPubSign = binary_to_list(aeser_api_encoder:encode(account_pubkey, pubkey(?BOB_SIGN))),
    Call2 =
        contract_call_spec(SCId, MSSrc, "new_validator", [BPub, BPubSign, "true"],
                           ?INITIAL_STAKE, pubkey(?BOB), 1),

    LPub = binary_to_list(aeser_api_encoder:encode(account_pubkey, pubkey(?LISA))),
    Call3 =
        contract_call_spec(SCId, MSSrc, "new_validator", [LPub, LPub, "true"],
                           ?INITIAL_STAKE, pubkey(?LISA), 1),

    AllCalls = case ?config(initial_validators, CTConfig) of
        % Initial validators are already configured in the node config
        true -> [];
        false -> [Call1, Call2, Call3]
    end,

    ProtocolBin = integer_to_binary(aect_test_utils:latest_protocol_version()),
    #{<<"chain">> := #{<<"hard_forks">> := #{ProtocolBin := #{<<"contracts_file">> := ContractsFileName,
                                                              <<"accounts_file">> := AccountsFileName}}}} = NodeConfig,
    aecore_suite_utils:create_seed_file(ContractsFileName,
        #{<<"contracts">> => [SC, EC], <<"calls">> => AllCalls}),
    aecore_suite_utils:create_seed_file(AccountsFileName,
        #{  <<"ak_2evAxTKozswMyw9kXkvjJt3MbomCR1nLrf91BduXKdJLrvaaZt">> => 1000000000000000000000000000000000000000000000000,
            encoded_pubkey(?ALICE) => 2100000000000000000000000000,
            encoded_pubkey(?BOB) => 3100000000000000000000000000,
            encoded_pubkey(?BOB_SIGN) => 3100000000000000000000000000,
            encoded_pubkey(?LISA) => 4100000000000000000000000000
         }),
    ok.

node_config(Node, CTConfig, PotentialStakers, PotentialPinners, ReceiveAddress) ->
    NetworkId = ?config(network_id, CTConfig),
    GenesisStartTime = ?config(genesis_start_time, CTConfig),
    Stakers = lists:map(
                    fun(HCWho) ->
                        HCPriv = list_to_binary(aeu_hex:bin_to_hex( privkey(HCWho))), %% TODO: discuss key management
                        #{ <<"hyper_chain_account">> => #{<<"pub">> => encoded_pubkey(HCWho), <<"priv">> => HCPriv} }
                    end,
                    PotentialStakers),
    Pinners = lists:map(
                    fun({Owner, Pinner}) ->
                        HCPriv = list_to_binary(aeu_hex:bin_to_hex( privkey(Pinner))), %% TODO: discuss key management
                        #{ <<"parent_chain_account">> => #{<<"pub">> => encoded_pubkey(Pinner), <<"priv">> => HCPriv, <<"owner">> => encoded_pubkey(Owner)} }
                    end,
                    PotentialPinners),
    Validators = case ?config(initial_validators, CTConfig) of
        true ->
            lists:map(
                fun(HCWho) ->
                    #{<<"owner">> => encoded_pubkey(HCWho),
                      <<"sign_key">> => encoded_pubkey(HCWho),
                      <<"caller">> => encoded_pubkey(HCWho),
                      <<"stake">> => ?INITIAL_STAKE,
                      <<"restake">> => true}
                end,
                PotentialStakers);
        _ -> []
    end,
    ct:log("Stakers: ~p", [Stakers]),
    ct:log("Pinners: ~p", [Pinners]),
    ct:log("Validators: ~p", [Validators]),
    ConsensusType = <<"hyperchain">>,
    Port = aecore_suite_utils:external_api_port(?PARENT_CHAIN_NODE),
    SpecificConfig =
                #{  <<"parent_chain">> =>
                    #{  <<"start_height">> => ?config(parent_start_height, CTConfig),
                        <<"finality">> => ?PARENT_FINALITY,
                        <<"parent_epoch_length">> => ?PARENT_EPOCH_LENGTH,
                        <<"consensus">> =>
                            #{  <<"type">> => <<"AE2AE">>,
                                <<"network_id">> => ?PARENT_CHAIN_NETWORK_ID,
                                <<"spend_address">> => ReceiveAddress,
                                <<"fee">> => 100000000000000,
                                <<"amount">> => 9700
                            },
                        <<"polling">> =>
                            #{  <<"fetch_interval">> => 100,
                                <<"cache_size">> => 50,
                                <<"nodes">> => [ iolist_to_binary(io_lib:format("http://test:Pass@127.0.0.1:~p", [Port])) ]
                            }
                        },
                    <<"genesis_start_time">> => GenesisStartTime,
                    <<"child_epoch_length">> => ?CHILD_EPOCH_LENGTH,
                    <<"child_block_time">> => ?CHILD_BLOCK_TIME,
                    <<"child_block_production_time">> => ?CHILD_BLOCK_PRODUCTION_TIME
                 },
    Protocol = aect_test_utils:latest_protocol_version(),
    {ok, ContractFileName} = aecore_suite_utils:hard_fork_filename(Node, CTConfig, integer_to_list(Protocol), binary_to_list(NetworkId) ++ "_contracts.json"),
    {ok, AccountFileName} = aecore_suite_utils:hard_fork_filename(Node, CTConfig, integer_to_list(Protocol), binary_to_list(NetworkId) ++ "_accounts.json"),
    #{<<"chain">> =>
            #{  <<"persist">> => false,
                <<"hard_forks">> => #{integer_to_binary(Protocol) => #{<<"height">> => 0,
                                                                       <<"contracts_file">> => ContractFileName,
                                                                       <<"accounts_file">> => AccountFileName}},
                <<"consensus">> =>
                    #{<<"0">> => #{<<"type">> => ConsensusType,
                                <<"config">> =>
                                maps:merge(
                                    #{  <<"election_contract">> => aeser_api_encoder:encode(contract_pubkey, election_contract_address()),
                                        <<"rewards_contract">> => aeser_api_encoder:encode(contract_pubkey, staking_contract_address()),
                                        <<"staking_contract">> => aeser_api_encoder:encode(contract_pubkey, staking_contract_address()),
                                        <<"contract_owner">> => aeser_api_encoder:encode(account_pubkey,?OWNER_PUBKEY),
                                        <<"expected_key_block_rate">> => 2000,
                                        <<"stakers">> => Stakers,
                                        <<"pinners">> => Pinners,
                                        <<"initial_validators">> => Validators,
                                        <<"pinning_reward_value">> => 4711,
                                        <<"fixed_coinbase">> => ?BLOCK_REWARD,
                                        <<"fee_distribution">> => [30, 50, 20],
                                        <<"default_pinning_behavior">> => ?config(default_pinning_behavior, CTConfig),
                                        <<"parent_pin_sync_margin">> => ?config(parent_pin_sync_margin, CTConfig)},
                                    SpecificConfig)
                                    }}},
        <<"fork_management">> =>
            #{<<"network_id">> => <<"this_will_be_overwritten_runtime">>},
        <<"logging">> => #{<<"level">> => <<"debug">>},
        <<"sync">> => #{<<"ping_interval">> => 5000},
        <<"http">> => #{<<"endpoints">> => #{<<"hyperchain">> => true}},
        <<"mining">> =>
            #{<<"micro_block_cycle">> => 1,
            <<"autostart">> => false,
            %%<<"autostart">> => ProducingCommitments,
            <<"beneficiary_reward_delay">> => ?REWARD_DELAY
        }}.  %% this relies on certain nonce numbers

staking_contract_address() ->
    aect_contracts:compute_contract_pubkey(?OWNER_PUBKEY, 1).

election_contract_address() ->
    aect_contracts:compute_contract_pubkey(?OWNER_PUBKEY, 2).

%% Increase the child chain with a number of key blocks
%% Automatically add key blocks on parent chain and
%% if there are Txs, put them in a micro block
produce_cc_blocks(Config, BlocksCnt) ->
    produce_cc_blocks(Config, BlocksCnt, #{}).

produce_cc_blocks(Config, BlocksCnt, ProdCfg) ->
    [{Node, _, _, _} | _] = ?config(nodes, Config),
    TopHeight = rpc(Node, aec_chain, top_height, []),
    {ok, #{epoch := Epoch, first := First, last := Last, length := L} = Info} =
        rpc(Node, aec_chain_hc, epoch_info, [TopHeight]),
    ct:log("EpochInfo ~p", [Info]),
    %% At end of BlocksCnt child epoch approaches approx:
    CBAfterEpoch = BlocksCnt - (Last - TopHeight),
    ScheduleUpto = Epoch + 1 + (CBAfterEpoch div L),
    ParentTopHeight = rpc(?PARENT_CHAIN_NODE, aec_chain, top_height, []),
    ct:log("P@~p C@~p for next ~p child blocks", [ParentTopHeight, TopHeight,  BlocksCnt]),
    ParentProduce =
        case maps:get(parent_produce, ProdCfg, undefined) of
            undefined ->
                %% By default: Spread parent blocks over BlocksCnt
                lists:append([ spread(?PARENT_EPOCH_LENGTH, TopHeight,
                                      [ {CH, 0} || CH <- lists:seq(First + E * L, Last + E * L)]) ||
                               E <- lists:seq(0, ScheduleUpto - Epoch) ]);
            PP ->
                PP
        end,
    PNodes =
        case maps:get(prod_nodes, ProdCfg, undefined) of
            undefined ->
                [ Name || {_, Name, _, _} <- ?config(nodes, Config) ];
            PNs ->
                PNs
        end,

    Timeout = maps:get(timeout, ProdCfg, 3000),
    TopHeight = rpc(Node, aec_chain, top_height, []),

    %% assert that the parent chain is not mining
    ?assertEqual(stopped, rpc:call(?PARENT_CHAIN_NODE_NAME, aec_conductor, get_mining_state, [])),
    ct:log("parent produce ~p", [ParentProduce]),
    NewTopHeight = produce_to_cc_height(Config, TopHeight, TopHeight + BlocksCnt, ParentProduce, PNodes, Timeout),
    wait_same_top([ N || {N, _, _, _} <- ?config(nodes, Config)]),
    get_generations(Node, TopHeight + 1, NewTopHeight).

%% If it is time according to schedule, produce on parent chain
produce_pc_block([{CH, PBs} | PPs], TopHeight) when CH =< TopHeight ->
    mine_key_blocks(?PARENT_CHAIN_NODE_NAME, PBs),
    produce_pc_block(PPs, TopHeight);
produce_pc_block(PPs, _TopHeight) ->
    PPs.

%% It seems we automatically produce child chain blocks in the background
produce_to_cc_height(Config, TopHeight, GoalHeight, ParentProduce, PNodes, Timeout) ->
    NodeNames = [ Name || {_, Name, _, _} <- ?config(nodes, Config) ],
    BlocksNeeded = GoalHeight - TopHeight,
    case BlocksNeeded > 0 of
        false ->
            %% Unfortunate Hole-placement may lead to missed Parent-blocks otherwise
            produce_pc_block(ParentProduce, TopHeight),
            TopHeight;
        true ->
            NewParentProduce = produce_pc_block(ParentProduce, TopHeight + 1),

            %% TODO: add some assertions when we expect an MB (and not)!
            {ok, _Txs} = rpc:call(hd(NodeNames), aec_tx_pool, peek, [infinity]),

            %% This will mine 1 key-block (and 0 or 1 micro-blocks)
            {ok, Blocks} = mine_cc_blocks(PNodes, 1, Timeout),

            {Node, KeyBlock} = lists:last(Blocks),
            %% TODO: Should we have a way to require a keyblock?
            lists:foreach(fun({N, B}) ->
                              case aec_blocks:type(B) of
                                  key ->
                                      ct:log("CC ~p produced HOLE: ~p", [N, B]);
                                  micro ->
                                      ct:log("CC ~p produced micro-block: ~p", [N, B])
                              end
                          end, lists:droplast(Blocks)),

            ?assertEqual(key, aec_blocks:type(KeyBlock)),
            ct:log("CC ~p produced key-block: ~p", [Node, KeyBlock]),

            NHoles = length([ x || {_, B} <- Blocks,
                                   aec_blocks:type(B) == key
                                     andalso aec_headers:is_hole(aec_blocks:to_key_header(B)) ]),

            Producer = get_block_producer_name(?config(staker_names, Config), KeyBlock),
            ct:log("~p produced CC block at height ~p", [Producer, aec_blocks:height(KeyBlock)]),
            produce_to_cc_height(Config, TopHeight + NHoles + 1, GoalHeight + NHoles, NewParentProduce, PNodes, Timeout)
      end.

mine_cc_blocks(NodeNames, N, Timeout) ->
    aecore_suite_utils:hc_mine_blocks(NodeNames, N, Timeout, #{}).

get_generations(Node, FromHeight, ToHeight) ->
    ReversedBlocks =
        lists:foldl(
            fun(Height, Accum) ->
                case rpc(Node, aec_chain, get_generation_by_height, [Height, backward]) of
                    {ok, #{key_block := KB, micro_blocks := MBs}} ->
                        ReversedGeneration = lists:reverse(MBs) ++ [KB],
                        ReversedGeneration ++ Accum;
                    error -> error({failed_to_fetch_generation, Height})
                end
            end,
            [],
            lists:seq(FromHeight, ToHeight)),
    {ok, lists:reverse(ReversedBlocks)}.

mine_key_blocks(ParentNodeName, NumParentBlocks) ->
    {ok, _} = aecore_suite_utils:mine_micro_block_emptying_mempool_or_fail(ParentNodeName),
    {ok, KBs} = aecore_suite_utils:mine_key_blocks(ParentNodeName, NumParentBlocks),
    ct:log("Parent block mined ~p ~p number: ~p", [KBs, ParentNodeName, NumParentBlocks]),
    {ok, KBs}.

%get_block_producer_name(Parties, Node, Height) ->
%    Producer = get_block_producer(Node, Height),
%    case lists:keyfind(Producer, 1, Parties) of
%        false -> Producer;
%        {_, _, Name} -> Name
%    end.

get_block_producer_name(Parties, Block) ->
    Producer = aec_blocks:miner(Block),
    case lists:keyfind(Producer, 1, Parties) of
        false -> Producer;
        {_, _, Name} -> Name
    end.

get_block_producer(Node, Height) ->
    {ok, KeyHeader} = rpc(Node, aec_chain, get_key_header_by_height, [Height]),
    aec_headers:miner(KeyHeader).

leaders_at_height(Node, Height, Config) ->
    {ok, Hash} = rpc(Node, aec_chain_state, get_key_block_hash_at_height, [Height]),
    {ok, Return} = inspect_staking_contract(?ALICE, leaders, Config, Hash),
    [ begin
        {account_pubkey, K} = aeser_api_encoder:decode(LeaderKey), K
      end || [ LeaderKey, _LeaderStake] <- Return ].

key_reward_provided() ->
    TopHeight = rpc(?NODE1, aec_chain, top_height, []),
    RewardHeight = TopHeight - ?REWARD_DELAY,
    key_reward_provided(RewardHeight).

key_reward_provided(RewardHeight) ->
  {get_block_producer(?NODE1, RewardHeight),
   rpc(?NODE1, aec_governance, block_mine_reward, [RewardHeight])}.

create_stub(Contract) ->
    create_stub(Contract, []).

create_stub(Contract, Opts0) ->
    File = aect_test_utils:contract_filename(Contract),
    Opts = Opts0 ++ [{no_code, true}] ++ aect_test_utils:copts({file, File}),
    {ok, SrcBin} = aect_test_utils:read_contract(Contract),
    {ok, Enc}  = aeso_aci:contract_interface(json, binary_to_list(SrcBin), Opts),
    {ok, Stub} = aeso_aci:render_aci_json(Enc),
    binary_to_list(Stub).

spread(_, _, []) ->
    [];
spread(0, TopHeight, Spread) ->
    [ {CH, N} || {CH, N} <- Spread, N /= 0, CH > TopHeight ];
%spread(N, TopHeight, [{CH, K} | Spread]) when length(Spread) < N ->
%    %% Take speed first (not realistic), then fill rest
%    spread(0, TopHeight, [{CH, K + N - length(Spread)} | [ {CH2, X+1} || {CH2, X} <- Spread]]);
spread(N, TopHeight, Spread) when N rem 2 == 0 ->
    {Left, Right} = lists:split(length(Spread) div 2, Spread),
    spread(N div 2, TopHeight, Left) ++ spread(N div 2, TopHeight, Right);
spread(N, TopHeight, Spread) when N rem 2 == 1 ->
    {Left, [{Middle, K} | Right]} = lists:split(length(Spread) div 2, Spread),
    spread(N div 2, TopHeight, Left) ++ [{Middle, K+1} || Middle > TopHeight] ++ spread(N div 2, TopHeight, Right).

get_entropy(Node, Epoch) ->
    ParentHeight = rpc(Node, aec_consensus_hc, entropy_height, [Epoch]),
    {ok, WPHdr}  = rpc(?PARENT_CHAIN_NODE, aec_chain, get_key_header_by_height, [ParentHeight]),
    {ok, WPHash0} = aec_headers:hash_header(WPHdr),
    {ParentHeight, aeser_api_encoder:encode(key_block_hash, WPHash0)}.
