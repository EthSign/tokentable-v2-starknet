use starknet::{
    ContractAddress,
    class_hash::ClassHash
};
use tokentable_v2::components::structs::ttsuite::TTSuite;

#[starknet::interface]
trait IDeployer<TContractState> {
    fn deploy_ttsuite(
        ref self: TContractState,
        project_token: ContractAddress,
        project_id: felt252,
        allow_transferable_ft: bool
    ) -> (ContractAddress, ContractAddress);

    fn set_class_hash(
        ref self: TContractState,
        unlocker_classhash: ClassHash,
        futuretoken_classhash: ClassHash,
    );

    fn set_fee_collector(
        ref self: TContractState,
        fee_collector: ContractAddress
    );

    fn get_class_hash(
        self: @TContractState
    ) -> (ClassHash, ClassHash);

    fn get_fee_collector(
        self: @TContractState
    ) -> ContractAddress;

    fn get_ttsuite(
        self: @TContractState,
        project_id: felt252,
    ) -> TTSuite;
}

mod DeployerEvents {
    #[derive(Drop, starknet::Event)]
    struct TokenTableSuiteDeployed {
        #[key]
        by: super::ContractAddress,
        #[key]
        project_id: felt252,
        #[key]
        project_token: super::ContractAddress,
        #[key]
        unlocker_instance: super::ContractAddress,
        #[key]
        futuretoken_instance: super::ContractAddress,
    }
    #[derive(Drop, starknet::Event)]
    struct ClassHashChanged {
        #[key]
        unlocker_classhash: super::ClassHash,
        #[key]
        futuretoken_classhash: super::ClassHash,
    }
}

mod DeployerErrors {
    const ALREADY_DEPLOYED: felt252 = 'ALREADY_DEPLOYED';
    const EMPTY_CLASSHASH: felt252 = 'EMPTY_CLASSHASH';
}