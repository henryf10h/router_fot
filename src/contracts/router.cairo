//**** Specify interface here ****//
#[starknet::contract]
mod Router {

    // import pair contracts and factory contracts
    use router::interfaces::router_interface::IROUTER;
    use router::interfaces::router_interface::IERC20DispatcherTrait;
    use router::interfaces::router_interface::IERC20Dispatcher;
    use router::interfaces::router_interface::IERC20CamelOnly;
    use starknet::ContractAddress;
    use starknet::get_caller_address;

    #[storage]
    struct Storage {}

    #[abi(embed_v0)]
    impl RouterImpl of IROUTER<ContractState> {
    }
}
