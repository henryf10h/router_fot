// SPDX-License-Identifier: MIT

use starknet::ContractAddress;
use starknet::ClassHash;

#[starknet::interface]
    trait IERC20<TState> {
        fn name(self: @TState) -> felt252;
        fn symbol(self: @TState) -> felt252;
        fn decimals(self: @TState) -> u8;
        fn total_supply(self: @TState) -> u256;
        fn balance_of(self: @TState, account: ContractAddress) -> u256;
        fn allowance(self: @TState, owner: ContractAddress, spender: ContractAddress) -> u256;
        fn transfer(ref self: TState, recipient: ContractAddress, amount: u256) -> bool;
        fn transfer_from(
            ref self: TState, sender: ContractAddress, recipient: ContractAddress, amount: u256
        ) -> bool;
        fn approve(ref self: TState, spender: ContractAddress, amount: u256) -> bool;
    }

    #[starknet::interface]
    trait IERC20Camel<TState> {
        fn name(self: @TState) -> felt252;
        fn symbol(self: @TState) -> felt252;
        fn decimals(self: @TState) -> u8;
        fn totalSupply(self: @TState) -> u256;
        fn balanceOf(self: @TState, account: ContractAddress) -> u256;
        fn allowance(self: @TState, owner: ContractAddress, spender: ContractAddress) -> u256;
        fn transfer(ref self: TState, recipient: ContractAddress, amount: u256) -> bool;
        fn transferFrom(
            ref self: TState, sender: ContractAddress, recipient: ContractAddress, amount: u256
        ) -> bool;
        fn approve(ref self: TState, spender: ContractAddress, amount: u256) -> bool;
    }

    #[starknet::interface]
    trait IERC20CamelOnly<TState> {
        fn totalSupply(self: @TState) -> u256;
        fn balanceOf(self: @TState, account: ContractAddress) -> u256;
        fn transferFrom(
            ref self: TState, sender: ContractAddress, recipient: ContractAddress, amount: u256
        ) -> bool;
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

    #[starknet::interface]
    trait IFactory<TState> {
        fn get_pair(self: @TState, token0: ContractAddress, token1: ContractAddress) -> ContractAddress;
        fn get_all_pairs(self: @TState) -> (felt252, ContractAddress);
        fn get_num_of_pairs(self: @TState) -> (felt252,);
        fn get_fee_to(self: @TState) -> ContractAddress;
        fn get_fee_to_setter(self: @TState) -> ContractAddress;
        fn get_pair_contract_class_hash(self: @TState) -> felt252;
        fn create_pair(ref self: TState, tokenA: ContractAddress, tokenB: ContractAddress) -> ContractAddress;
        fn set_fee_to(ref self: TState, new_fee_to: ContractAddress);
        fn set_fee_to_setter(ref self: TState, new_fee_to_setter: ContractAddress);
    }

    #[starknet::interface]
    trait IJediSwapPair<TState> {
        fn token0(self: @TState) -> ContractAddress;
        fn token1(self: @TState) -> ContractAddress;
        fn get_reserves(self: @TState) -> (u256, u256, felt252);
        fn price_0_cumulative_last(self: @TState) -> u256;
        fn price_1_cumulative_last(self: @TState) -> u256;
        fn klast(self: @TState) -> u256;
        fn mint(ref self: TState, to: ContractAddress) -> u256;
        fn burn(ref self: TState, to: ContractAddress) -> (u256, u256);
        fn swap(ref self: TState, amount0Out: u256, amount1Out: u256, to: ContractAddress, data: Array::<felt252>);
        fn skim(ref self: TState, to: ContractAddress);
        fn sync(ref self: TState);
    }

    #[starknet::interface]
    trait IREFLECT<TState> {
        fn is_excluded(self: @TState, account: ContractAddress) -> bool;
        fn r_total(self: @TState) -> u256;
        fn total_fees(self: @TState) -> u256;
        fn reflect(ref self: TState, tAmount: u256) -> bool; //return boolean for reflect
        fn reflection_from_token(self: @TState, tAmount: u256, deductTransferFee: bool) -> u256;
        fn token_from_reflection(self: @TState, rAmount: u256) -> u256;
        fn exclude_account(ref self: TState, user: ContractAddress) -> bool;//return boolean for include
        fn include_account(ref self: TState, user: ContractAddress) -> bool;//return boolean for exclude
    }
