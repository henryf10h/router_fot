use starknet:: { ContractAddress, ClassHash };
use snforge_std::{ declare, ContractClassTrait, ContractClass, start_prank, stop_prank,
                   spy_events, CheatTarget, SpyOn, EventSpy, EventFetcher, Event, EventAssertions };

use jediswap::tests::utils::utils::{ deployer_addr, user1, user2, TOKEN_MULTIPLIER, TOKEN0_NAME,
                    TOKEN1_NAME, TOKEN2_NAME, SYMBOL };
use debug::PrintTrait;

#[starknet::interface]
trait IERC20<TContractState> {
    // view functions
    fn name(self: @TContractState) -> felt252;
    fn symbol(self: @TContractState) -> felt252;
    fn decimals(self: @TContractState) -> u8;
    fn total_supply(self: @TContractState) -> u256;
    fn balance_of(self: @TContractState, account: ContractAddress) -> u256;
    fn allowance(self: @TContractState, owner: ContractAddress, spender: ContractAddress) -> u256;
    // external functions
    fn approve(ref self: TContractState, spender: ContractAddress, amount: u256) -> bool;
    fn transfer(ref self: TContractState, recipient: ContractAddress, amount: u256) -> bool;
}

#[starknet::interface]
trait IFactoryC1<T> {
    // view functions
    fn get_pair(self: @T, token0: ContractAddress, token1: ContractAddress) -> ContractAddress;
    fn get_all_pairs(self: @T) -> (u32, Array::<ContractAddress>);
    // external functions
    fn create_pair(ref self: T, tokenA: ContractAddress, tokenB: ContractAddress) -> ContractAddress;
}

#[starknet::interface]
trait IPairC1<T> {
    // view functions
    fn get_reserves(self: @T) -> (u256, u256, u64);
}

#[starknet::interface]
trait IRouterC1<TState> {
    // view functions
    fn factory(self: @TState) -> ContractAddress;
    fn sort_tokens(self: @TState, tokenA: ContractAddress, tokenB: ContractAddress) -> (ContractAddress, ContractAddress);
    fn quote(self: @TState, amountA: u256, reserveA: u256, reserveB: u256) -> u256;
    fn get_amount_out(self: @TState, amountIn: u256, reserveIn: u256, reserveOut: u256) -> u256;
    fn get_amount_in(self: @TState, amountOut: u256, reserveIn: u256, reserveOut: u256) -> u256;
    fn get_amounts_out(self: @TState, amountIn: u256, path: Array::<ContractAddress>) -> Array::<u256>;
    fn get_amounts_in(self: @TState, amountOut: u256, path: Array::<ContractAddress>) -> Array::<u256>;
    // external functions
    fn add_liquidity(ref self: TState, tokenA: ContractAddress, tokenB: ContractAddress, amountADesired: u256, amountBDesired: u256, amountAMin: u256, amountBMin: u256, to: ContractAddress, deadline: u64) -> (u256, u256, u256);
    fn remove_liquidity(ref self: TState, tokenA: ContractAddress, tokenB: ContractAddress, liquidity: u256, amountAMin: u256, amountBMin: u256, to: ContractAddress, deadline: u64) -> (u256, u256);
    fn swap_exact_tokens_for_tokens(ref self: TState, amountIn: u256, amountOutMin: u256, path: Array::<ContractAddress>, to: ContractAddress, deadline: u64) -> Array::<u256>;
    fn swap_tokens_for_exact_tokens(ref self: TState, amountOut: u256, amountInMax: u256, path: Array::<ContractAddress>, to: ContractAddress, deadline: u64) -> Array::<u256>;
    fn swap_exact_tokens_for_tokens_supporting_fee_on_transfer_tokens(ref self: TState, amount_in: u256, amount_out_min: u256, path: Array<ContractAddress>, to: ContractAddress, deadline: u64);
    fn replace_implementation_class(ref self: TState, new_implementation_class: ClassHash);
}

fn deploy_erc20(erc20_amount_per_user: u256) -> (ContractAddress, ContractAddress, ContractAddress) {
    let erc20_class = declare("ERC20").unwrap();
    let initial_supply: u256 = erc20_amount_per_user * 2;
    
    let mut token0_constructor_calldata = Default::default();
    Serde::serialize(@TOKEN0_NAME, ref token0_constructor_calldata);
    Serde::serialize(@SYMBOL, ref token0_constructor_calldata);
    Serde::serialize(@initial_supply, ref token0_constructor_calldata);
    Serde::serialize(@user1(), ref token0_constructor_calldata);
    let (token0_address, _) = erc20_class.deploy(@token0_constructor_calldata).unwrap();
    
    let mut token1_constructor_calldata = Default::default();
    Serde::serialize(@TOKEN1_NAME, ref token1_constructor_calldata);
    Serde::serialize(@SYMBOL, ref token1_constructor_calldata);
    Serde::serialize(@initial_supply, ref token1_constructor_calldata);
    Serde::serialize(@user1(), ref token1_constructor_calldata);
    let (token1_address, _) = erc20_class.deploy(@token1_constructor_calldata).unwrap();
    
    let mut token2_constructor_calldata = Default::default();
    Serde::serialize(@TOKEN2_NAME, ref token2_constructor_calldata);
    Serde::serialize(@SYMBOL, ref token2_constructor_calldata);
    Serde::serialize(@initial_supply, ref token2_constructor_calldata);
    Serde::serialize(@user1(), ref token2_constructor_calldata);
    let (token2_address, _) = erc20_class.deploy(@token2_constructor_calldata).unwrap();
    
    (token0_address, token1_address, token2_address)
}

fn deploy_erc20_and_fee_on_transfer(erc20_amount_per_user: u256) -> (ContractAddress, ContractAddress, ContractAddress) {
    let erc20_class = declare("ERC20").unwrap();
    let reflect_class = declare("REFLECT").unwrap(); // fee-on-transfer token standard
    let initial_supply: u256 = erc20_amount_per_user * 2;
    
    //token0 is the ONLY fee-on-transfer token
    let mut token0_constructor_calldata = Default::default();
    Serde::serialize(@TOKEN0_NAME, ref token0_constructor_calldata);
    Serde::serialize(@SYMBOL, ref token0_constructor_calldata);
    Serde::serialize(@initial_supply, ref token0_constructor_calldata);
    Serde::serialize(@user1(), ref token0_constructor_calldata);
    let (token0_address, _) = reflect_class.deploy(@token0_constructor_calldata).unwrap();
    
    //token1 is regular ERC20
    let mut token1_constructor_calldata = Default::default();
    Serde::serialize(@TOKEN1_NAME, ref token1_constructor_calldata);
    Serde::serialize(@SYMBOL, ref token1_constructor_calldata);
    Serde::serialize(@initial_supply, ref token1_constructor_calldata);
    Serde::serialize(@user1(), ref token1_constructor_calldata);
    let (token1_address, _) = erc20_class.deploy(@token1_constructor_calldata).unwrap();
    
    //token2 is regular ERC20
    let mut token2_constructor_calldata = Default::default();
    Serde::serialize(@TOKEN2_NAME, ref token2_constructor_calldata);
    Serde::serialize(@SYMBOL, ref token2_constructor_calldata);
    Serde::serialize(@initial_supply, ref token2_constructor_calldata);
    Serde::serialize(@user1(), ref token2_constructor_calldata);
    let (token2_address, _) = erc20_class.deploy(@token2_constructor_calldata).unwrap();
    
    (token0_address, token1_address, token2_address)
}

fn deploy_contracts() -> (ContractAddress, ContractAddress) {
    let pair_class = declare("PairC1").unwrap();
    
    let mut factory_constructor_calldata = Default::default();
    Serde::serialize(@pair_class.class_hash, ref factory_constructor_calldata);
    Serde::serialize(@deployer_addr(), ref factory_constructor_calldata);
    let factory_class = declare("FactoryC1").unwrap();
    let (factory_address, _) = factory_class.deploy(@factory_constructor_calldata).unwrap();
    
    let mut router_constructor_calldata = Default::default();
    Serde::serialize(@factory_address, ref router_constructor_calldata);
    let router_class = declare("RouterC1").unwrap();
    let (router_address, _) = router_class.deploy(@router_constructor_calldata).unwrap();
    
    (factory_address, router_address)
}

#[test]
fn test_swap_exact_0_to_1_fee_on_transfer(){
    // Setup
    let (factory_address, router_address) = deploy_contracts();
    let factory_dispatcher = IFactoryC1Dispatcher { contract_address: factory_address };
    let router_dispatcher = IRouterC1Dispatcher { contract_address: router_address };

    let erc20_amount_per_user: u256 = 100 * TOKEN_MULTIPLIER;
    let (token0_address, token1_address, _) = deploy_erc20_and_fee_on_transfer(erc20_amount_per_user);
    let (sorted_token0_address, sorted_token1_address) = router_dispatcher.sort_tokens(token0_address, token1_address);
    let pair_address = factory_dispatcher.create_pair(sorted_token0_address, sorted_token1_address);
    let _pair_dispatcher = IPairC1Dispatcher { contract_address: pair_address };

    let (token0_address, token1_address) = (sorted_token0_address, sorted_token1_address);
    let token0_erc20_dispatcher = IERC20Dispatcher { contract_address: token0_address };
    let token1_erc20_dispatcher = IERC20Dispatcher { contract_address: token1_address };

    start_prank(CheatTarget::One(token0_address), user1());
    token0_erc20_dispatcher.transfer(user2(), erc20_amount_per_user);
    stop_prank(CheatTarget::One(token0_address));

    let user_1_token_0_balance_initial: u256 = token0_erc20_dispatcher.balance_of(user1());
    let user_2_token_0_balance_initial: u256 = token0_erc20_dispatcher.balance_of(user2());

    let transfer_fee: u256 = erc20_amount_per_user * 1 / 100; // Calculate the 1% transfer fee
    let user_1_token_0_lower_bound: u256 = erc20_amount_per_user - transfer_fee;
    let user_1_token_0_upper_bound: u256 = erc20_amount_per_user + transfer_fee;
    
    assert(user_1_token_0_balance_initial >= user_1_token_0_lower_bound, 'u1 token0 balance >= range');
    assert(user_1_token_0_balance_initial <= user_1_token_0_upper_bound, 'u1 token0 balance <= range');

    let user_2_token_0_lower_bound = erc20_amount_per_user - transfer_fee;
    let user_2_token_0_upper_bound = erc20_amount_per_user;
    assert(user_2_token_0_balance_initial >= user_2_token_0_lower_bound, 'u2 token0 balance out of range');
    assert(user_2_token_0_balance_initial <= user_2_token_0_upper_bound, 'u2 token0 balance out of range');

    start_prank(CheatTarget::One(token1_address), user1());
    token1_erc20_dispatcher.transfer(user2(), erc20_amount_per_user);
    stop_prank(CheatTarget::One(token1_address));

    let user_1_token_1_balance_initial: u256 = token1_erc20_dispatcher.balance_of(user1());
    let user_2_token_1_balance_initial: u256 = token1_erc20_dispatcher.balance_of(user2());
    assert(user_1_token_1_balance_initial == erc20_amount_per_user, 'user1 token1 eq initial amount');
    assert(user_2_token_1_balance_initial == erc20_amount_per_user, 'user2 token1 eq initial amount');

    let amount_token0_liq: u256 = 20 * TOKEN_MULTIPLIER;
    let amount_token1_liq: u256 = 40 * TOKEN_MULTIPLIER;

    start_prank(CheatTarget::One(token0_address), user1());
    token0_erc20_dispatcher.approve(router_address, amount_token0_liq);
    stop_prank(CheatTarget::One(token0_address));

    start_prank(CheatTarget::One(token1_address), user1());
    token1_erc20_dispatcher.approve(router_address, amount_token1_liq);
    stop_prank(CheatTarget::One(token1_address));

    start_prank(CheatTarget::One(router_address), user1());
    let (_amountA, _amountB, _liquidity) = router_dispatcher.add_liquidity(
        token0_address, token1_address, amount_token0_liq, amount_token1_liq, 1, 1, user1(), 0);
    stop_prank(CheatTarget::One(router_address));

   // Actual test

    let amount_token_0: u256 = 2 * TOKEN_MULTIPLIER;

    start_prank(CheatTarget::One(token0_address), user2());
    token0_erc20_dispatcher.approve(router_address, amount_token_0);
    stop_prank(CheatTarget::One(token0_address));

    let mut path = ArrayTrait::<ContractAddress>::new();
    path.append(token0_address);
    path.append(token1_address);

    start_prank(CheatTarget::One(router_address), user2());
    router_dispatcher.swap_exact_tokens_for_tokens_supporting_fee_on_transfer_tokens(amount_token_0, 0, path, user2(), 0);
    stop_prank(CheatTarget::One(router_address));

    let user_2_token_1_balance_final: u256 = token1_erc20_dispatcher.balance_of(user2());

    let user_2_token_1_balance_difference = user_2_token_1_balance_final - user_2_token_1_balance_initial;

    let token_1_fee = user_2_token_1_balance_difference * 1 / 100; // Calculate the 1% fee
    let token_1_lower_bound = user_2_token_1_balance_difference - token_1_fee;
    let token_1_upper_bound = user_2_token_1_balance_difference;

    assert(user_2_token_1_balance_difference >= token_1_lower_bound, 'should be >= lower bound');
    assert(user_2_token_1_balance_difference <= token_1_upper_bound, 'should be <= upper bound');
}

#[test]
fn test_swap_exact_0_to_1(){
    // Setup
    let (factory_address, router_address) = deploy_contracts();
    let factory_dispatcher = IFactoryC1Dispatcher { contract_address: factory_address };
    let router_dispatcher = IRouterC1Dispatcher { contract_address: router_address };

    let erc20_amount_per_user: u256 = 100 * TOKEN_MULTIPLIER;
    let (token0_address, token1_address, _) = deploy_erc20(erc20_amount_per_user);
    let (sorted_token0_address, sorted_token1_address) = router_dispatcher.sort_tokens(token0_address, token1_address);
    let pair_address = factory_dispatcher.create_pair(sorted_token0_address, sorted_token1_address);
    let _pair_dispatcher = IPairC1Dispatcher { contract_address: pair_address };

    let (token0_address, token1_address) = (sorted_token0_address, sorted_token1_address);
    let token0_erc20_dispatcher = IERC20Dispatcher { contract_address: token0_address };
    let token1_erc20_dispatcher = IERC20Dispatcher { contract_address: token1_address };

    start_prank(CheatTarget::One(token0_address), user1());
    token0_erc20_dispatcher.transfer(user2(), erc20_amount_per_user);
    stop_prank(CheatTarget::One(token0_address));

    let user_1_token_0_balance_initial: u256 = token0_erc20_dispatcher.balance_of(user1());
    let user_2_token_0_balance_initial: u256 = token0_erc20_dispatcher.balance_of(user2());
    
    assert(user_1_token_0_balance_initial == erc20_amount_per_user, 'user1 token0 eq initial amount');
    assert(user_2_token_0_balance_initial == erc20_amount_per_user, 'user2 token0 eq initial amount');

    start_prank(CheatTarget::One(token1_address), user1());
    token1_erc20_dispatcher.transfer(user2(), erc20_amount_per_user);
    stop_prank(CheatTarget::One(token1_address));

    let user_1_token_1_balance_initial: u256 = token1_erc20_dispatcher.balance_of(user1());
    let user_2_token_1_balance_initial: u256 = token1_erc20_dispatcher.balance_of(user2());
    assert(user_1_token_1_balance_initial == erc20_amount_per_user, 'user1 token1 eq initial amount');
    assert(user_2_token_1_balance_initial == erc20_amount_per_user, 'user2 token1 eq initial amount');

    let amount_token0_liq: u256 = 20 * TOKEN_MULTIPLIER;
    let amount_token1_liq: u256 = 40 * TOKEN_MULTIPLIER;

    start_prank(CheatTarget::One(token0_address), user1());
    token0_erc20_dispatcher.approve(router_address, amount_token0_liq);
    stop_prank(CheatTarget::One(token0_address));

    start_prank(CheatTarget::One(token1_address), user1());
    token1_erc20_dispatcher.approve(router_address, amount_token1_liq);
    stop_prank(CheatTarget::One(token1_address));

    start_prank(CheatTarget::One(router_address), user1());
    let (_amountA, _amountB, _liquidity) = router_dispatcher.add_liquidity(
        token0_address, token1_address, amount_token0_liq, amount_token1_liq, 1, 1, user1(), 0);
    stop_prank(CheatTarget::One(router_address));

    // Actual test

    let amount_token_0: u256 = 2 * TOKEN_MULTIPLIER;

    start_prank(CheatTarget::One(token0_address), user2());
    token0_erc20_dispatcher.approve(router_address, amount_token_0);
    stop_prank(CheatTarget::One(token0_address));

    let mut path = ArrayTrait::<ContractAddress>::new();
    path.append(token0_address);
    path.append(token1_address);

    start_prank(CheatTarget::One(router_address), user2());
    let amounts: Array::<u256> = router_dispatcher.swap_exact_tokens_for_tokens(amount_token_0, 0, path, user2(), 0);
    stop_prank(CheatTarget::One(router_address));

    assert(amounts.len() == 2, 'should be 2');

    let amount0In: u256 = *amounts.at(0);
    let amount1Out: u256 = *amounts.at(1);

    let user_2_token_0_balance_final: u256 = token0_erc20_dispatcher.balance_of(user2());
    let user_2_token_0_balance_difference = user_2_token_0_balance_initial - user_2_token_0_balance_final;
    assert(user_2_token_0_balance_difference == amount0In, 'should be eq to amount0In');

    let user_2_token_1_balance_final: u256 = token1_erc20_dispatcher.balance_of(user2());
    let user_2_token_1_balance_difference = user_2_token_1_balance_final - user_2_token_1_balance_initial;
    assert(user_2_token_1_balance_difference == amount1Out, 'should be eq to amount1Out');
}

#[test]
fn test_swap_exact_1_to_0_fee_on_transfer(){
    // Setup
    let (factory_address, router_address) = deploy_contracts();
    let factory_dispatcher = IFactoryC1Dispatcher { contract_address: factory_address };
    let router_dispatcher = IRouterC1Dispatcher { contract_address: router_address };

    let erc20_amount_per_user: u256 = 100 * TOKEN_MULTIPLIER;
    let (token0_address, token1_address, _) = deploy_erc20_and_fee_on_transfer(erc20_amount_per_user);
    let (sorted_token0_address, sorted_token1_address) = router_dispatcher.sort_tokens(token0_address, token1_address);
    let pair_address = factory_dispatcher.create_pair(sorted_token0_address, sorted_token1_address);
    let _pair_dispatcher = IPairC1Dispatcher { contract_address: pair_address };

    let (token0_address, token1_address) = (sorted_token0_address, sorted_token1_address);
    let token0_erc20_dispatcher = IERC20Dispatcher { contract_address: token0_address };
    let token1_erc20_dispatcher = IERC20Dispatcher { contract_address: token1_address };

    start_prank(CheatTarget::One(token0_address), user1());
    token0_erc20_dispatcher.transfer(user2(), erc20_amount_per_user);
    stop_prank(CheatTarget::One(token0_address));

    let user_1_token_0_balance_initial: u256 = token0_erc20_dispatcher.balance_of(user1());
    let user_2_token_0_balance_initial: u256 = token0_erc20_dispatcher.balance_of(user2());

    let transfer_fee: u256 = erc20_amount_per_user * 1 / 100; // Calculate the 1% transfer fee
    let user_1_token_0_lower_bound: u256 = erc20_amount_per_user - transfer_fee;
    let user_1_token_0_upper_bound: u256 = erc20_amount_per_user + transfer_fee;
    
    assert(user_1_token_0_balance_initial >= user_1_token_0_lower_bound, 'u1 token0 balance >= range');
    assert(user_1_token_0_balance_initial <= user_1_token_0_upper_bound, 'u1 token0 balance <= range');

    let user_2_token_0_lower_bound = erc20_amount_per_user - transfer_fee;
    let user_2_token_0_upper_bound = erc20_amount_per_user;
    assert(user_2_token_0_balance_initial >= user_2_token_0_lower_bound, 'u2 token0 balance out of range');
    assert(user_2_token_0_balance_initial <= user_2_token_0_upper_bound, 'u2 token0 balance out of range');

    start_prank(CheatTarget::One(token1_address), user1());
    token1_erc20_dispatcher.transfer(user2(), erc20_amount_per_user);
    stop_prank(CheatTarget::One(token1_address));

    let user_1_token_1_balance_initial: u256 = token1_erc20_dispatcher.balance_of(user1());
    let user_2_token_1_balance_initial: u256 = token1_erc20_dispatcher.balance_of(user2());
    assert(user_1_token_1_balance_initial == erc20_amount_per_user, 'user1 token1 eq initial amount');
    assert(user_2_token_1_balance_initial == erc20_amount_per_user, 'user2 token1 eq initial amount');

    let amount_token0_liq: u256 = 20 * TOKEN_MULTIPLIER;
    let amount_token1_liq: u256 = 40 * TOKEN_MULTIPLIER;

    start_prank(CheatTarget::One(token0_address), user1());
    token0_erc20_dispatcher.approve(router_address, amount_token0_liq);
    stop_prank(CheatTarget::One(token0_address));

    start_prank(CheatTarget::One(token1_address), user1());
    token1_erc20_dispatcher.approve(router_address, amount_token1_liq);
    stop_prank(CheatTarget::One(token1_address));

    start_prank(CheatTarget::One(router_address), user1());
    let (_amountA, _amountB, _liquidity) = router_dispatcher.add_liquidity(
        token0_address, token1_address, amount_token0_liq, amount_token1_liq, 1, 1, user1(), 0);
    stop_prank(CheatTarget::One(router_address));
    // Actual test

    let amount_token_1: u256 = 2 * TOKEN_MULTIPLIER;

    start_prank(CheatTarget::One(token1_address), user2());
    token1_erc20_dispatcher.approve(router_address, amount_token_1);
    stop_prank(CheatTarget::One(token1_address));

    let mut path = ArrayTrait::<ContractAddress>::new();
    path.append(token1_address);
    path.append(token0_address);
    
    start_prank(CheatTarget::One(router_address), user2());
    let amounts: Array::<u256> = router_dispatcher.swap_exact_tokens_for_tokens(amount_token_1, 0, path, user2(), 0);
    stop_prank(CheatTarget::One(router_address));

    assert(amounts.len() == 2, 'should be 2');

    let amount1In: u256 = *amounts.at(0);
    let amount0Out: u256 = *amounts.at(1);

    let user_2_token_0_balance_final: u256 = token0_erc20_dispatcher.balance_of(user2());
    let user_2_token_0_balance_difference = user_2_token_0_balance_final - user_2_token_0_balance_initial;
    assert(user_2_token_0_balance_difference >= amount0Out, 'should be eq to amount0Out');

    let user_2_token_1_balance_final: u256 = token1_erc20_dispatcher.balance_of(user2());
    let user_2_token_1_balance_difference = user_2_token_1_balance_initial - user_2_token_1_balance_final;
    assert(user_2_token_1_balance_difference == amount1In, 'should be eq to amount1In');
}

#[test]
fn test_swap_exact_1_to_0(){
    // Setup
    let (factory_address, router_address) = deploy_contracts();
    let factory_dispatcher = IFactoryC1Dispatcher { contract_address: factory_address };
    let router_dispatcher = IRouterC1Dispatcher { contract_address: router_address };

    let erc20_amount_per_user: u256 = 100 * TOKEN_MULTIPLIER;
    let (token0_address, token1_address, _) = deploy_erc20(erc20_amount_per_user);
    let (sorted_token0_address, sorted_token1_address) = router_dispatcher.sort_tokens(token0_address, token1_address);
    let pair_address = factory_dispatcher.create_pair(sorted_token0_address, sorted_token1_address);
    let _pair_dispatcher = IPairC1Dispatcher { contract_address: pair_address };

    let (token0_address, token1_address) = (sorted_token0_address, sorted_token1_address);
    let token0_erc20_dispatcher = IERC20Dispatcher { contract_address: token0_address };
    let token1_erc20_dispatcher = IERC20Dispatcher { contract_address: token1_address };

    start_prank(CheatTarget::One(token0_address), user1());
    token0_erc20_dispatcher.transfer(user2(), erc20_amount_per_user);
    stop_prank(CheatTarget::One(token0_address));

    let user_1_token_0_balance_initial: u256 = token0_erc20_dispatcher.balance_of(user1());
    let user_2_token_0_balance_initial: u256 = token0_erc20_dispatcher.balance_of(user2());
    
    assert(user_1_token_0_balance_initial == erc20_amount_per_user, 'user1 token0 eq initial amount');
    assert(user_2_token_0_balance_initial == erc20_amount_per_user, 'user2 token0 eq initial amount');

    start_prank(CheatTarget::One(token1_address), user1());
    token1_erc20_dispatcher.transfer(user2(), erc20_amount_per_user);
    stop_prank(CheatTarget::One(token1_address));

    let user_1_token_1_balance_initial: u256 = token1_erc20_dispatcher.balance_of(user1());
    let user_2_token_1_balance_initial: u256 = token1_erc20_dispatcher.balance_of(user2());
    assert(user_1_token_1_balance_initial == erc20_amount_per_user, 'user1 token1 eq initial amount');
    assert(user_2_token_1_balance_initial == erc20_amount_per_user, 'user2 token1 eq initial amount');

    let amount_token0_liq: u256 = 20 * TOKEN_MULTIPLIER;
    let amount_token1_liq: u256 = 40 * TOKEN_MULTIPLIER;

    start_prank(CheatTarget::One(token0_address), user1());
    token0_erc20_dispatcher.approve(router_address, amount_token0_liq);
    stop_prank(CheatTarget::One(token0_address));

    start_prank(CheatTarget::One(token1_address), user1());
    token1_erc20_dispatcher.approve(router_address, amount_token1_liq);
    stop_prank(CheatTarget::One(token1_address));

    start_prank(CheatTarget::One(router_address), user1());
    let (_amountA, _amountB, _liquidity) = router_dispatcher.add_liquidity(
        token0_address, token1_address, amount_token0_liq, amount_token1_liq, 1, 1, user1(), 0);
    stop_prank(CheatTarget::One(router_address));

    // Actual test

    let amount_token_1: u256 = 2 * TOKEN_MULTIPLIER;

    start_prank(CheatTarget::One(token1_address), user2());
    token1_erc20_dispatcher.approve(router_address, amount_token_1);
    stop_prank(CheatTarget::One(token1_address));

    let mut path = ArrayTrait::<ContractAddress>::new();
    path.append(token1_address);
    path.append(token0_address);
    
    start_prank(CheatTarget::One(router_address), user2());
    let amounts: Array::<u256> = router_dispatcher.swap_exact_tokens_for_tokens(amount_token_1, 0, path, user2(), 0);
    stop_prank(CheatTarget::One(router_address));

    assert(amounts.len() == 2, 'should be 2');

    let amount1In: u256 = *amounts.at(0);
    let amount0Out: u256 = *amounts.at(1);

    let user_2_token_0_balance_final: u256 = token0_erc20_dispatcher.balance_of(user2());
    let user_2_token_0_balance_difference = user_2_token_0_balance_final - user_2_token_0_balance_initial;
    assert(user_2_token_0_balance_difference == amount0Out, 'should be eq to amount0Out');

    let user_2_token_1_balance_final: u256 = token1_erc20_dispatcher.balance_of(user2());
    let user_2_token_1_balance_difference = user_2_token_1_balance_initial - user_2_token_1_balance_final;
    assert(user_2_token_1_balance_difference == amount1In, 'should be eq to amount1In');
}

