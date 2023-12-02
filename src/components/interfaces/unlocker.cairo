use starknet::{ContractAddress};
use tokentable_v2::components::structs::{
    preset::Preset, actual::Actual
};

#[starknet::interface]
trait IUnlocker<TContractState> {
    fn create_preset(
        ref self: TContractState,
        preset_id: felt252,
        linear_start_timestamps_relative: Span<u64>,
        linear_end_timestamp_relative: u64,
        linear_bips: Span<u64>,
        num_of_unlocks_for_each_linear: Span<u64>
    );

    fn create_actual(
        ref self: TContractState,
        recipient: ContractAddress,
        preset_id: felt252,
        start_timestamp_absolute: u64,
        amount_skipped: u256,
        total_amount: u256,
        amount_depositing_now: u256
    ) -> u256;

    fn deposit(
        ref self: TContractState,
        actual_id: u256,
        amount: u256
    );

    fn withdraw_deposit(
        ref self: TContractState,
        actual_id: u256,
        amount: u256
    );

    fn claim(
        ref self: TContractState,
        actual_id: u256,
        override_recipient: ContractAddress
    );

    fn claim_cancelled_actual(
        ref self: TContractState,
        actual_id: u256,
        override_recipient: ContractAddress
    );

    fn cancel(
        ref self: TContractState,
        actual_id: u256,
        refund_founder_address: ContractAddress
    ) -> (u256, u256);

    fn set_hook(
        ref self: TContractState,
        hook: ContractAddress
    );

    fn disable_cancel(
        ref self: TContractState
    );

    fn disable_hook(
        ref self: TContractState
    );

    fn is_cancelable(
        self: @TContractState
    ) -> bool;

    fn is_hookable(
        self: @TContractState
    ) -> bool;

    fn get_hook(
        self: @TContractState
    ) -> ContractAddress;

    fn get_futuretoken(
        self: @TContractState
    ) -> ContractAddress;

    fn get_preset(
        self: @TContractState,
        preset_id: felt252
    ) -> Preset;

    fn get_actual(
        self: @TContractState,
        actual_id: u256
    ) -> Actual;

    fn calculate_amount_claimable(
        self: @TContractState,
        actual_id: u256
    ) -> (u256, u256);

    fn calculate_amount_of_tokens_to_claim_at_timestamp(
        self: @TContractState,
        actual_start_timestamp_absolute: u64,
        preset_linear_end_timestamp_relative: u64,
        preset_linear_start_timestamps_relative: Span<u64>,
        claim_timestamp_absolute: u64,
        preset_linear_bips: Span<u64>,
        preset_num_of_unlocks_for_each_linear: Span<u64>,
        preset_bips_precision: u64,
        actual_total_amount: u256,
    ) -> u256;
}

mod UnlockerEvents {
    #[derive(Drop, starknet::Event)]
    struct PresetCreated {
        #[key]
        preset_id: felt252
    }

    #[derive(Drop, starknet::Event)]
    struct ActualCreated {
        #[key]
        preset_id: felt252,
        #[key]
        actual_id: u256
    }

    #[derive(Drop, starknet::Event)]
    struct TokensDeposited {
        #[key]
        actual_id: u256,
        #[key]
        amount: u256
    }

    #[derive(Drop, starknet::Event)]
    struct TokensClaimed {
        #[key]
        actual_id: u256,
        #[key]
        caller: super::ContractAddress,
        #[key]
        to: super::ContractAddress,
        #[key]
        amount: u256
    }

    #[derive(Drop, starknet::Event)]
    struct TokensWithdrawn {
        #[key]
        actual_id: u256,
        #[key]
        by: super::ContractAddress,
        #[key]
        amount: u256
    }

    #[derive(Drop, starknet::Event)]
    struct ActualCancelled {
        #[key]
        actual_id: u256,
        #[key]
        amount_unlocked_leftover: u256,
        #[key]
        amount_refunded: u256,
        #[key]
        refund_founder_address: super::ContractAddress
    }
}

mod UnlockerErrors {
    const INVALID_PRESET_FORMAT: felt252 = 'INVALID_PRESET_FORMAT';
    const PRESET_EXISTS: felt252 = 'PRESET_EXISTS';
    const PRESET_DOES_NOT_EXIST: felt252 = 'PRESET_DOES_NOT_EXIST';
    const INVALID_SKIP_AMOUNT: felt252 = 'INVALID_SKIP_AMOUNT';
    const INSUFFICIENT_DEPOSIT: felt252 = 'INSUFFICIENT_DEPOSIT';
    const UNAUTHORIZED: felt252 = 'UNAUTHORIZED';
    const GENERIC_ERC20_TRANSFER_ERROR: felt252 = 
        'GENERIC_ERC20_TRANSFER_ERROR';
}