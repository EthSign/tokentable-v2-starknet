//! SPDX-License-Identifier: Apache 2.0
//!
//! TokenTable Unlocker Structs: Preset

use tokentable_v2::components::span_impl::StoreU64Span;

#[derive(PartialEq, Drop, Serde, Copy, starknet::Store)]
/// A `Preset` is an unlocking schedule template that contains information that's shared across all
/// recipients within a single round.
/// In this system, cliff unlocks are considered linear as well. This enables us to mix and match
/// cliffs and linears at will, providing full customizability.
/// Cliff waiting periods have a linear bip of 0 and cliff unlocking moments have a duration of 1
/// second.
/// The data here is fairly complex and should be generated by our frontend instead of by hand.
///
/// # Members
/// * `linear_start_timestamps_relative`: An array of start timestamps for each linear segment.
/// * `linear_end_timestamp_relative`: The timestamp that marks the end of the final linear segment.
/// * `linear_bips`: The basis point that is unlocked for each linear segment. Must add up to 10000.
/// * `num_of_unlocks_for_each_linear`: The number of unlocks within each respective linear segment.
/// * `stream`: If the tokens should unlock as a stream instead of a cliff at the end of a linear
/// segment subdivision.
pub struct Preset {
    pub linear_start_timestamps_relative: Span<u64>,
    pub linear_end_timestamp_relative: u64,
    pub linear_bips: Span<u64>,
    pub num_of_unlocks_for_each_linear: Span<u64>,
    pub stream: bool,
}
