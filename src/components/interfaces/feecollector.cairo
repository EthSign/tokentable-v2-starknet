//! SPDX-License-Identifier: Apache 2.0
//!
//! TokenTable Fee Collector Interface
//!
//! This interface handles TokenTable service fee calculation.

use starknet::{ContractAddress};

#[starknet::interface]
trait ITTFeeCollector<TContractState> {
    /// Withdraws collected fees.
    ///
    /// # Arguments
    /// * `token`: The type of SNIP-2 token we are trying to withdraw.
    /// * `amount`: The amount of tokens we are trying to withdraw.
    ///
    /// # Panics
    /// * `OwnableComponent::Errors::NOT_OWNER`: If the caller is not the owner.
    fn withdraw_fee(
        ref self: TContractState,
        token: ContractAddress,
        amount: u256
    );

    /// Sets the default fee.
    ///
    /// # Arguments
    /// * `bips`: The proportion of fees to take in basis points.
    ///
    /// # Panics
    /// * `OwnableComponent::Errors::NOT_OWNER`: If the caller is not the owner.
    fn set_default_fee(
        ref self: TContractState,
        bips: u256
    );

    /// Sets a custom fee for a specific Unlocker.
    ///
    /// # Arguments
    /// * `unlocker_instance`: The specific Unlocker we are trying to configure.
    /// * `bips`: The proportion of fees to take in basis points.
    ///
    /// # Panics
    /// * `OwnableComponent::Errors::NOT_OWNER`: If the caller is not the owner.
    fn set_custom_fee(
        ref self: TContractState,
        unlocker_instance: ContractAddress,
        bips: u256
    );

    /// Returns the default fee in basis points.
    fn get_default_fee(
        self: @TContractState
    ) -> u256;

    /// Returns the fees incurred by transacting a certain amount of tokens within a specific Unlocker.
    fn get_fee(
        self: @TContractState,
        unlocker_instance: ContractAddress,
        tokens_transferred: u256
    ) -> u256;
}

mod TTFeeCollectorEvents {
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

mod TTFeeCollectorErrors {
    const FEES_TOO_HIGH: felt252 = 'FEES_TOO_HIGH';
}