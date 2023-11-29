use starknet::{ContractAddress};

#[starknet::interface]
trait IFeeCollector<TContractState> {
    fn get_fee(
        self: @TContractState,
        unlocker_instance: ContractAddress,
        tokens_transferred: u256
    ) -> u256;
}

#[derive(Drop, starknet::Event)]
struct DefaultFeeSet {
    #[key]
    bips: u256
}

#[derive(Drop, starknet::Event)]
struct CustomFeeSet {
    #[key]
    unlocker_instance: ContractAddress,
    #[key]
    bips: u256
}