#[derive(PartialEq, Drop, Serde, Copy, starknet::Store)]
struct Actual {
    preset_id: felt252,
    start_timestamp_absolute: u64,
    amount_claimed: u256,
    amount_deposited: u256,
    total_amount: u256
}