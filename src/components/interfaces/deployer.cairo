//! SPDX-License-Identifier: Apache 2.0
//!
//! TokenTable Deployer Interface
//!
//! This is the deployer for all TokenTable core and proxy contracts. All initial setup and
//! configuration is automatically done here.
//! You should avoid deploying TokenTable contracts individually unless you know what you're doing.

use starknet::{ContractAddress, class_hash::ClassHash};
use tokentable_v2::components::structs::ttsuite::TTSuite;

#[starknet::interface]
pub trait ITTDeployer<TContractState> {
    /// Deploys and configures a new suite of TokenTable contracts.
    ///
    /// # Arguments
    /// * `project_token`: The project SNIP-2 token address.
    /// * `project_id`: A unique projectId.
    /// * `is_transferable`: Allow FutureToken to be transferable.
    /// * `is_cancelable`: Allow unlocking schedules to be cancelled in the Unlocker.
    /// * `is_hookable`: Allow Unlocker to call an external hook.
    /// * `is_withdrawable`: Allow the founder to withdraw deposited project tokens.
    ///
    /// # Panics
    /// * `ALREADY_DEPLOYED`: If `project_id` already exists.
    /// * `EMPTY_CLASSHASH`: If the class hashes for Unlocker and FutureToken have not been set.
    ///
    /// # Events
    /// * `TokenTableSuiteDeployed`
    fn deploy_ttsuite(
        ref self: TContractState,
        project_token: ContractAddress,
        project_id: felt252,
        is_transferable: bool,
        is_cancelable: bool,
        is_hookable: bool,
        is_withdrawable: bool,
    ) -> (ContractAddress, ContractAddress);

    /// Sets the class hash for Unlocker and FutureToken.
    ///
    /// # Arguments
    /// * `unlocker_classhash`: The Unlocker class hash.
    /// * `futuretoken_classhash`: The FutureToken class hash.
    ///
    /// # Panics
    /// * `OwnableComponent::Errors::NOT_OWNER`: If the caller is not the owner.
    ///
    /// # Events
    /// * `ClassHashChanged`
    fn set_class_hash(
        ref self: TContractState, unlocker_classhash: ClassHash, futuretoken_classhash: ClassHash,
    );

    /// Sets the address for a fee collector.
    ///
    /// # Arguments
    /// * `fee_collector`: The address of the fee collector.
    ///
    /// # Panics
    /// * `OwnableComponent::Errors::NOT_OWNER`: If the caller is not the owner.
    fn set_fee_collector(ref self: TContractState, fee_collector: ContractAddress);

    /// Returns the class hashes of Unlocker and FutureToken respectively.
    fn get_class_hash(self: @TContractState) -> (ClassHash, ClassHash);

    /// Returns the address of the fee collector.
    fn get_fee_collector(self: @TContractState) -> ContractAddress;

    /// Returns the addresses of Unlocker and FutureToken given a `project_id`.
    fn get_ttsuite(self: @TContractState, project_id: felt252,) -> TTSuite;
}

pub mod TTDeployerEvents {
    #[derive(Drop, starknet::Event)]
    pub struct TokenTableSuiteDeployed {
        pub by: super::ContractAddress,
        pub project_id: felt252,
        pub project_token: super::ContractAddress,
        pub unlocker_instance: super::ContractAddress,
        pub futuretoken_instance: super::ContractAddress,
    }
    #[derive(Drop, starknet::Event)]
    pub struct ClassHashChanged {
        pub unlocker_classhash: super::ClassHash,
        pub futuretoken_classhash: super::ClassHash,
    }
}

pub mod TTDeployerErrors {
    pub const ALREADY_DEPLOYED: felt252 = 'ALREADY_DEPLOYED';
    pub const EMPTY_CLASSHASH: felt252 = 'EMPTY_CLASSHASH';
}
