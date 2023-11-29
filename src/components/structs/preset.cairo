use tokentable_v2::components::span_impl::StoreU64Span;

#[derive(PartialEq, Drop, Serde, Copy, starknet::Store)]
struct Preset {
    linear_start_timestamps_relative: Span::<u64>,
    linear_end_timestamp_relative: u64,
    linear_bips: Span::<u64>,
    num_of_unlocks_for_each_linear: Span::<u64>
}