//! SPDX-License-Identifier: Apache 2.0
//!
//! TokenTable FutureToken Interface
//!
//! The lightweight interface for TTFutureTokenV2(.5.x), which handles unlocking schedule ownership
//! for TokenTable.

use starknet::{ContractAddress};

#[starknet::interface]
pub trait ITTFutureToken<TContractState> {
    /// Permanently sets the authorized FutureToken minter.
    /// This function can only be called once.
    ///
    /// # Arguments
    /// * `authorized_minter`: The authorized minter, typically an Unlocker contract.
    ///
    /// # Panics
    /// * `NOT_PERMISSIONED`: If this function has already been called before.
    fn set_authorized_minter_single_use(
        ref self: TContractState, authorized_minter: ContractAddress
    );

    /// Mints a new FutureToken.
    ///
    /// # Arguments
    /// * `to`: The owner of the minted FutureToken.
    /// * `unsafe_mint`: Use `mint(...)` instead of `safe_mint(...)`.
    ///
    /// # Panics
    /// * `NOT_PERMISSIONED`: If the caller isn't the authorized minter.
    ///
    /// # Returns
    /// * `u256`: The token ID, aka `actual_id`, of the minted FutureToken.
    fn mint(ref self: TContractState, to: ContractAddress, unsafe_mint: bool,) -> u256;

    /// Sets the base token URI.
    ///
    /// # Arguments
    /// * `uri`: The new URI.
    ///
    /// # Panics
    /// * `NOT_PERMISSIONED`: If the caller isn't the owner of the authorized minter.
    ///
    /// # Events
    /// * `DidSetBaseURI`
    fn set_token_base_uri(ref self: TContractState, uri: ByteArray);

    /// Returns information regarding the unlocking schedule attached to a FutureToken.
    ///
    /// # Arguments
    /// * `token_id`: The FutureToken we are querying. This is also the `actual_id`.
    ///
    /// # Returns
    /// * `u256`: The claimable amount of tokens this time.
    /// * `u256`: The updated total amount of tokens claimed after this claim action.
    /// * `bool`: If the schedule attached to said FutureToken is cancelable.
    fn get_claim_info(self: @TContractState, token_id: u256) -> (u256, u256, bool);
}

pub mod TTFutureTokenErrors {
    pub const NOT_PERMISSIONED: felt252 = 'NOT_PERMISSIONED';
}
