mod contracts{
    mod RouterC1V2;
    mod PairC1;
    mod FactoryC1;
}

mod interfaces{
    mod ownable_interface;
}

mod utils{
    mod reflect;
    mod erc20;
    mod ownable;
    mod FlashSwapTest;
}

#[cfg(test)]
mod tests{
    mod test_swap;
    mod utils;
    mod test_add_remove_liquidity;
    mod test_create_pair;
    mod test_deployment;
    mod test_updates;
    mod test_flash_swap;
    mod test_protocol_fees;
}