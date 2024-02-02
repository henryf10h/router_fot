//**** Specify interface here ****//
#[starknet::contract]
mod Router {

    // import pair contracts and factory contracts
    use core::array::SpanTrait;
    use core::array::ArrayTrait;
    use router::interfaces::router_interface::IROUTER;
    use router::interfaces::router_interface::IERC20DispatcherTrait;
    use router::interfaces::router_interface::IERC20Dispatcher;
    use router::interfaces::router_interface::IFactoryDispatcherTrait;
    use router::interfaces::router_interface::IFactoryDispatcher;
    use router::interfaces::router_interface::IJediSwapPairDispatcherTrait;
    use router::interfaces::router_interface::IJediSwapPairDispatcher;
    use router::interfaces::router_interface::IERC20CamelOnly;
    use starknet::{ContractAddress, get_contract_address, get_caller_address, get_block_timestamp};

    #[storage]
    struct Storage {}

    #[abi(embed_v0)]
    impl RouterImpl of IROUTER<ContractState> {
    
        fn swap_exact_tokens_for_tokens_supporting_fee_on_transfer_tokens(ref self: ContractState, amount_in: u256, amount_out_min: u256, path: Array<ContractAddress>, to: ContractAddress, deadline: u64) {
            self._ensure(deadline);
            IERC20Dispatcher{contract_address: *path.at(0)};//.transferFrom
            let paths = path.span();
            let balance_before = IERC20Dispatcher { contract_address: *paths[paths.len() - 1] }.balance_of(to);
            self._swap_supporting_fee_on_transfer_tokens(path, to);

            assert(
                (IERC20Dispatcher { contract_address: *paths[paths.len() - 1] }.balance_of(to) - balance_before) >= amount_out_min, 'INSUFFICIENT_OUTPUT_AMOUNT'
            );
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        
        fn _swap_supporting_fee_on_transfer_tokens(ref self: ContractState, path: Array<ContractAddress>, to: ContractAddress){
            // let mut i: u32 = 0;
            // while i < (path.len() - 1) {
                // let (input, output) = (path[i], path[i + 1]);
                // let (token0, token1) = sortTokens(input, output);
                // let pair = IUniswapV2Pair(UniswapV2Library.pairFor(factory, input, output));
                // uint amountInput;
                // uint amountOutput;
                // { // scope to avoid stack too deep errors
                // (uint reserve0, uint reserve1,) = pair.getReserves();
                // (uint reserveInput, uint reserveOutput) = input == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
                // amountInput = IERC20(input).balanceOf(address(pair)).sub(reserveInput);
                // amountOutput = UniswapV2Library.getAmountOut(amountInput, reserveInput, reserveOutput);
                // }
                // (uint amount0Out, uint amount1Out) = input == token0 ? (uint(0), amountOutput) : (amountOutput, uint(0));
                // address to = i < path.length - 2 ? UniswapV2Library.pairFor(factory, output, path[i + 2]) : _to;
                // pair.swap(amount0Out, amount1Out, to, new bytes(0));
                // i = i + 1;
            // }
        }

        fn _ensure(self: @ContractState, deadline: u64) {
            let block_timestamp = get_block_timestamp();
            assert(deadline >= block_timestamp, 'Transaction too old');
        }
    }
}
