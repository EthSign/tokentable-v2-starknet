//! SPDX-License-Identifier: Apache 2.0
//!
//! TokenTable Unlocker Structs: Actual

#[derive(PartialEq, Drop, Serde, Copy, starknet::Store)]
/// An `Actual` is an unlocking schedule for a single recipient and builds on top of an existing `Preset`. 
/// An actual contains information that is different from one stakeholder to the next.
///
/// # Members
/// * `preset_id`: The ID of the `Preset` that this `Actual` references.
/// * `start_timestamp_absolute`: The timestamp of when this unlocking schedule actually starts.
/// * `amount_claimed`: The amount of tokens that have already been claimed by the recipient.
/// * `total_amount`: The maximum amount of tokens that the recipient can claim throughout the entire schedule.
struct Actual {
    preset_id: felt252,
    start_timestamp_absolute: u64,
    amount_claimed: u256,
    total_amount: u256,
}