//! SPDX-License-Identifier: Apache 2.0
//!
//! TokenTable Hook Interface
//!
//! You must implement this interface to become a valid hook for TokenTable Unlocker.

use starknet::{ContractAddress};

#[starknet::interface]
pub trait ITTHook<TContractState> {
    /// A callback function that's called by the Unlocker.
    ///
    /// # Arguments
    /// * `function_name`: The name of the Unlocker function called.
    /// * `context`: The encoded felt252 array of relevant call data.
    /// * `caller`: The caller of the Unlocker function.
    fn did_call(
        ref self: TContractState,
        function_name: felt252,
        context: Span<felt252>,
        caller: ContractAddress
    );
}