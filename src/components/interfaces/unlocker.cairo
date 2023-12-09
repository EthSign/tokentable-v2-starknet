use starknet::{ContractAddress};
use tokentable_v2::components::structs::{
    preset::Preset, actual::Actual
};

#[starknet::interface]
trait ITTUnlocker<TContractState> {
    fn create_preset(
        ref self: TContractState,
        preset_id: felt252,
        linear_start_timestamps_relative: Span<u64>,
        linear_end_timestamp_relative: u64,
        linear_bips: Span<u64>,
        num_of_unlocks_for_each_linear: Span<u64>,
        stream: bool,
        batch_id: u64,
    );

    fn create_actual(
        ref self: TContractState,
        recipient: ContractAddress,
        preset_id: felt252,
        start_timestamp_absolute: u64,
        amount_skipped: u256,
        total_amount: u256,
        batch_id: u64,
    ) -> u256;

    fn withdraw_deposit(
        ref self: TContractState,
        amount: u256
    );

    fn claim(
        ref self: TContractState,
        actual_id: u256,
        claim_to: ContractAddress,
        batch_id: u64,
    );

    fn delegate_claim(
        ref self: TContractState,
        actual_id: u256,
        batch_id: u64,
    );

    fn cancel(
        ref self: TContractState,
        actual_id: u256,
        wipe_claimable_balance: bool,
        batch_id: u64,
    ) -> u256;

    fn set_hook(
        ref self: TContractState,
        hook: ContractAddress
    );

    fn set_claiming_delegate(
        ref self: TContractState,
        delegate: ContractAddress,
    );

    fn disable_cancel(
        ref self: TContractState
    );

    fn disable_hook(
        ref self: TContractState
    );

    fn disable_withdraw(
        ref self: TContractState
    );

    fn deployer(
        self: @TContractState
    ) -> ContractAddress;

    fn futuretoken(
        self: @TContractState
    ) -> ContractAddress;

    fn hook(
        self: @TContractState
    ) -> ContractAddress;

    fn claiming_delegate(
        self: @TContractState
    ) -> ContractAddress;

    fn is_cancelable(
        self: @TContractState
    ) -> bool;

    fn is_hookable(
        self: @TContractState
    ) -> bool;

    fn is_withdrawable(
        self: @TContractState
    ) -> bool;

    fn get_preset(
        self: @TContractState,
        preset_id: felt252
    ) -> Preset;

    fn get_actual(
        self: @TContractState,
        actual_id: u256
    ) -> Actual;

    fn get_pending_amount_claimable(
        self: @TContractState,
        actual_id: u256,
    ) -> u256;

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
        preset_stream: bool,
        preset_bips_precision: u64,
        actual_total_amount: u256,
    ) -> u256;
}

mod TTUnlockerEvents {
    #[derive(Drop, starknet::Event)]
    struct PresetCreated {
        #[key]
        preset_id: felt252,
        #[key]
        batch_id: u64,
    }

    #[derive(Drop, starknet::Event)]
    struct ActualCreated {
        #[key]
        preset_id: felt252,
        #[key]
        actual_id: u256,
        #[key]
        batch_id: u64,
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
        amount: u256,
        #[key]
        fees_charged: u256,
        #[key]
        batch_id: u64,
    }

    #[derive(Drop, starknet::Event)]
    struct TokensWithdrawn {
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
        pending_amount_claimable: u256,
        #[key]
        did_wipe_claimable_balance: bool,
        #[key]
        batch_id: u64,
    }

    #[derive(Drop, starknet::Event)]
    struct CancelDisabled {}

    #[derive(Drop, starknet::Event)]
    struct HookDisabled {}

    #[derive(Drop, starknet::Event)]
    struct WithdrawDisabled {}
}

mod TTUnlockerErrors {
    const INVALID_PRESET_FORMAT: felt252 = 'INVALID_PRESET_FORMAT';
    const PRESET_EXISTS: felt252 = 'PRESET_EXISTS';
    const PRESET_DOES_NOT_EXIST: felt252 = 'PRESET_DOES_NOT_EXIST';
    const INVALID_SKIP_AMOUNT: felt252 = 'INVALID_SKIP_AMOUNT';
    const INSUFFICIENT_DEPOSIT: felt252 = 'INSUFFICIENT_DEPOSIT';
    const NOT_PERMISSIONED: felt252 = 'NOT_PERMISSIONED';
    const GENERIC_ERC20_TRANSFER_ERROR: felt252 = 
        'GENERIC_ERC20_TRANSFER_ERROR';
}