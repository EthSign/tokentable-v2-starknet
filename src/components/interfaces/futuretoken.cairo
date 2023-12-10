//! SPDX-License-Identifier: Apache 2.0
//!
//! TokenTable FutureToken Interface
//!
//! The lightweight interface for TTFutureTokenV2(.5.x), which handles unlocking schedule ownership for TokenTable.

use starknet::{ContractAddress};

#[starknet::interface]
trait ITTFutureToken<TContractState> {
    /// Permanently sets the authorized FutureToken minter.
    /// This function can only be called once.
    ///
    /// # Arguments
    /// * `authorized_minter`: The authorized minter, typically an Unlocker contract.
    ///
    /// # Panics
    /// * `NOT_PERMISSIONED`: If this function has already been called before.
    fn set_authorized_minter_single_use(
        ref self: TContractState,
        authorized_minter: ContractAddress
    );

    /// Mints a new FutureToken.
    ///
    /// # Arguments
    /// * `to`: The owner of the minted FutureToken.
    ///
    /// # Panics
    /// * `NOT_PERMISSIONED`: If the caller isn't the authorized minter.
    ///
    /// # Returns
    /// * `u256`: The token ID, aka `actual_id`, of the minted FutureToken.
    fn mint(
        ref self: TContractState,
        to: ContractAddress
    ) -> u256;

    /// Sets the base token URI.
    ///
    /// # Arguments
    /// * `uri`: The new URI.
    ///
    /// # Panics
    /// * `NOT_PERMISSIONED`: If the caller isn't the authorized minter.
    ///
    /// # Events
    /// * `DidSetBaseURI`
    fn set_uri(
        ref self: TContractState,
        uri: felt252
    );

    /// Returns information regarding the unlocking schedule attached to a FutureToken.
    ///
    /// # Arguments
    /// * `token_id`: The FutureToken we are querying. This is also the `actual_id`.
    ///
    /// # Returns
    /// * `u256`: The claimable amount of tokens this time.
    /// * `u256`: The updated total amount of tokens claimed after this claim action.
    /// * `bool`: If the schedule attached to said FutureToken is cancelable.
    fn get_claim_info(
        self: @TContractState,
        token_id: u256
    ) -> (u256, u256, bool);

    /// Returns the base URI.
    fn get_base_uri(
        self: @TContractState
    ) -> felt252;
}

mod TTFutureTokenEvents {
    #[derive(Drop, starknet::Event)]
    struct DidSetBaseURI {
        #[key]
        new_uri: felt252
    }
}

mod TTFutureTokenErrors {
    const NOT_PERMISSIONED: felt252 = 'NOT_PERMISSIONED';
}