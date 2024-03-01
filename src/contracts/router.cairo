//**** Specify interface here ****//
#[starknet::contract]
mod Router {

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
    struct Storage {
        factory: ContractAddress
    }

    #[constructor]
    fn constructor(ref self: ContractState, factory: ContractAddress) {
        self.factory.write(factory);
    }

    #[abi(embed_v0)]
    impl RouterImpl of IROUTER<ContractState> {

        fn factory(self: @ContractState) -> ContractAddress {
            self.factory.read()
        }

        fn get_reserves(self: @ContractState, factory: ContractAddress, token_a: ContractAddress, token_b: ContractAddress) -> (u256,u256){
            self._get_reserves(self.factory(), token_a, token_b)
        }

        fn get_amount_out(self: @ContractState, amountIn: u256, reserveIn: u256, reserveOut: u256) -> u256 {
            self._get_amount_out(amountIn, reserveIn, reserveOut)
        }
    
        fn swap_exact_tokens_for_tokens_supporting_fee_on_transfer_tokens(ref self: ContractState, amount_in: u256, amount_out_min: u256, path: Array<ContractAddress>, to: ContractAddress, deadline: u64) {
            self._ensure(deadline);
            let paths = @path; //it also compiles with: let paths = path.span()
            let caller = get_caller_address();
            IERC20Dispatcher{contract_address: *path.at(0)}.transfer_from(caller,IFactoryDispatcher{contract_address: self.factory.read()}.get_pair(*path.at(0), *path.at(1)),amount_in);
            let balance_before = IERC20Dispatcher { contract_address: *paths[paths.len() - 1] }.balance_of(to);
            self._swap_supporting_fee_on_transfer_tokens(0,path, to);

            assert(
                (IERC20Dispatcher { contract_address: *paths[paths.len() - 1] }.balance_of(to) - balance_before) >= amount_out_min, 'INSUFFICIENT_OUTPUT_AMOUNT'
            );
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        
        fn _swap_supporting_fee_on_transfer_tokens(ref self: ContractState, index: u32 , path: Array<ContractAddress>, _to: ContractAddress){
            let factory = self.factory.read();
            if (index == path.len() - 1) {
                return ();
            }
            let (token0, _token1) = self._sort_tokens(*path[index], *path[index + 1]);
            let pair = self._pair_for(factory, *path[index], *path[index + 1]);
            let (reserve_0, reserve_1) = self._get_reserves(factory, *path[index], *path[index + 1]);
            let (reserve_input, reserve_output) = if (*path[index] == token0) {
                (reserve_0, reserve_1)
            } else {
                (reserve_1, reserve_0)
            };
            let amount_input = IERC20Dispatcher{contract_address: *path[index]}.balance_of(pair) - reserve_input;
            let amount_output = self._get_amount_out(amount_input, reserve_input, reserve_output);
            let (amount_0_out, amount_1_out) = if (*path[index] == token0) {
                (0, amount_output)
            } else {
                (amount_output, 0)
            };
            let mut to: ContractAddress = _to;
            if (index < (path.len() - 2)) {
                to = self._pair_for(factory, *path[index + 1], *path[index + 2]);
            }
            let data = ArrayTrait::<felt252>::new();
            let pairDispatcher = IJediSwapPairDispatcher{ contract_address: pair };
            pairDispatcher.swap(amount_0_out, amount_1_out, to, data);
            return InternalImpl::_swap_supporting_fee_on_transfer_tokens(ref self, index + 1, path, _to);
        }

        fn _ensure(self: @ContractState, deadline: u64) {
            let block_timestamp = get_block_timestamp();
            assert(deadline >= block_timestamp, 'Transaction too old');
        }

        fn _sort_tokens(self: @ContractState, token_a: ContractAddress, token_b: ContractAddress) -> (ContractAddress, ContractAddress) {
            assert(token_a != token_b, 'IDENTICAL_ADDRESSES');
            if token_a < token_b {
                let (token_0, token_1) = (token_a, token_b);
                assert(!token_0.is_zero(), 'ZERO_ADDRESS');
                return(token_0, token_1);
            }
            else{
                let (token_0, token_1) = (token_b, token_a);
                assert(!token_0.is_zero(), 'ZERO_ADDRESS');
                return(token_0, token_1);
            }
        }

        fn _pair_for(self: @ContractState, factory: ContractAddress, token_a: ContractAddress, token_b: ContractAddress) -> ContractAddress {
            let (token_0, token_1) = self._sort_tokens(token_a, token_b);
            let pair = IFactoryDispatcher{contract_address: factory}.get_pair(token_0, token_1);
            return(pair);
        }

        fn _get_reserves(self: @ContractState, factory: ContractAddress, token_a: ContractAddress, token_b: ContractAddress) -> (u256,u256) {
            let (token_0, token_1) = self._sort_tokens(token_a, token_b);
            let pair = self._pair_for(factory, token_0, token_1);
            let (reserve_0, reserve_1, _time_stamp) = IJediSwapPairDispatcher{contract_address: pair}.get_reserves();
                if (token_a == token_0) {
                    return(reserve_0, reserve_1);
                } else {
                    return(reserve_1, reserve_0);
                }
        }

        fn _get_amount_out(self: @ContractState, amount_in: u256, reserve_in: u256, reserve_out: u256) -> u256 {
            assert(amount_in > 0, 'INSUFFICIENT_INPUT_AMOUNT');
            assert(reserve_in > 0 && reserve_out > 0, 'INSUFFICIENT_LIQUIDITY');
            let amount_in_with_fee = amount_in * 997;
            let numerator = amount_in_with_fee * reserve_out;
            let denominator = (reserve_in * 1000) + (amount_in_with_fee);
            return(numerator / denominator);
        }
    }
}


