//**** Specify interface here ****//
#[starknet::contract]
mod Router {

    // import pair contracts and factory contracts
    use core::traits::TryInto;
use core::traits::IndexView;
use core::clone::Clone;
use zeroable::Zeroable;
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
    
        fn swap_exact_tokens_for_tokens_supporting_fee_on_transfer_tokens(ref self: ContractState, amount_in: u256, amount_out_min: u256, path: Array<ContractAddress>, to: ContractAddress, deadline: u64) {
            self._ensure(deadline);
            let paths = @path; //it also compiles with: let paths = path.span()
            let caller = get_caller_address();
            IERC20Dispatcher{contract_address: *path.at(0)}.transfer_from(caller,IFactoryDispatcher{contract_address: self.factory.read()}.get_pair(*path.at(0), *path.at(1)),amount_in);
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
            let mut i: u32 = 0; 
            let paths = @path;
                while i < (paths.len()-1) {  
                let (token0, token1) = self._sort_tokens(*path.at(i),*path.at(i+1));  
                // next...

                i = i + 1;  // Ensure to increment i to avoid an infinite loop
                }
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
