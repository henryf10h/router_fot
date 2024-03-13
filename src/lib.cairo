mod contracts{
    mod router;
    mod jediSwapV1Router;
    mod ownable;
    mod PairC1;
    mod FactoryC1;
}

mod interfaces{
    mod router_interface;
    mod ownable_interface;
}

mod utils{
    mod reflect;
    mod erc20;
}

#[cfg(test)]
mod tests{
    mod test_swap;
    mod utils;
}