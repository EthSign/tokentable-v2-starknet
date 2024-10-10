//! SPDX-License-Identifier: Apache 2.0
//!
//! TokenTable Versioning Interface
//!
//! This interface is implemented by all major TokenTable contracts to keep track of their
//! versioning for upgrade compatibility checks.

#[starknet::interface]
pub trait IVersionable<TContractState> {
    fn version(self: @TContractState) -> felt252;
}
