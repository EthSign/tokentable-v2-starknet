use starknet::{
    ContractAddress,
    class_hash::ClassHash
};

#[starknet::interface]
trait IDeployer<TContractState> {
    fn deploy_tt_suite(
        ref self: TContractState,
        project_token: ContractAddress,
        project_id: felt252,
        allow_transferable_ft: bool
    ) -> (ContractAddress, ContractAddress, ContractAddress);

    fn set_class_hash(
        ref self: TContractState,
        unlocker_impl: ClassHash,
        future_token_impl: ClassHash,
        tracker_token_impl: ClassHash
    );

    fn set_fee_collector(
        ref self: TContractState,
        fee_collector: ContractAddress
    );

    fn get_class_hash(
        self: @TContractState
    ) -> (ClassHash, ClassHash, ClassHash);

    fn get_fee_collector(
        self: @TContractState
    ) -> ContractAddress;
}