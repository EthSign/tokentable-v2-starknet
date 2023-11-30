use starknet::{ContractAddress};

#[starknet::interface]
trait IFeeCollector<TContractState> {
    fn withdraw_fee(
        ref self: TContractState,
        token: ContractAddress,
        amount: u256
    );

    fn set_default_fee(
        ref self: TContractState,
        bips: u256
    );

    fn set_custom_fee(
        ref self: TContractState,
        unlocker_instance: ContractAddress,
        bips: u256
    );

    fn get_default_fee(
        self: @TContractState
    ) -> u256;

    fn get_fee(
        self: @TContractState,
        unlocker_instance: ContractAddress,
        tokens_transferred: u256
    ) -> u256;
}

mod FeeCollectorEvents {
    #[derive(Drop, starknet::Event)]
    struct DefaultFeeSet {
        #[key]
        bips: u256
    }

    #[derive(Drop, starknet::Event)]
    struct CustomFeeSet {
        #[key]
        unlocker_instance: super::ContractAddress,
        #[key]
        bips: u256
    }
}