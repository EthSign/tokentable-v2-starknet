//! SPDX-License-Identifier: Apache 2.0
//!
//! TokenTable Deployer Structs: TTSuite

use starknet::ContractAddress;

#[derive(PartialEq, Drop, Serde, Copy, starknet::Store)]
/// TTSuite bundles the address of an Unlocker instance and FutureToken instance.
struct TTSuite {
    unlocker_instance: ContractAddress,
    futuretoken_instance: ContractAddress,
}