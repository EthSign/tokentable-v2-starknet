use starknet::{ContractAddress};
use tokentable_v2::components::structs::{
    preset::Preset, actual::Actual
};

#[starknet::interface]
trait IUnlocker<TContractState> {
    fn initialize(
        ref self: TContractState,
        project_token_: ContractAddress,
        future_token_: ContractAddress,
        deployer_: ContractAddress
    );

    fn create_preset(
        ref self: TContractState,
        preset_id: felt252,
        linear_start_timestamp_relative: Span::<u64>,
        linear_end_timestamp_relative: u64,
        linear_bips: Span::<u64>,
        num_of_unlocks_for_each_linear: Span::<u64>
    );

    fn create_actual(
        ref self: TContractState,
        recipient: ContractAddress,
        preset_id: felt252,
        start_timestamp_absolute: u64,
        amount_skipped: u256,
        total_amount: u256,
        amount_depositing_now: u256
    ) -> u64;

    fn deposit(
        ref self: TContractState,
        actual_id: u64,
        amount: u256
    );

    fn withdraw_deposit(
        ref self: TContractState,
        actual_id: u64,
        amount: u256
    );

    fn claim(
        ref self: TContractState,
        actual_id: u64,
        override_recipient: ContractAddress
    );

    fn claim_cancelled_actual(
        ref self: TContractState,
        actual_id: u64,
        override_recipient: ContractAddress
    );

    fn cancel(
        ref self: TContractState,
        actual_id: u64,
        refund_founder_address: ContractAddress
    ) -> (u256, u256) ;

    fn set_access_control_delegate(
        ref self: TContractState,
        access_control_delegate_: ContractAddress
    );

    fn set_hook(
        ref self: TContractState,
        hook: ContractAddress
    );

    fn disable_cancel(
        ref self: TContractState
    );

    fn disable_access_control_delegate(
        ref self: TContractState
    );

    fn disable_hook(
        ref self: TContractState
    );

    fn is_cancelable(
        self: @TContractState
    ) -> bool;

    fn is_access_controllable(
        self: @TContractState
    ) -> bool;

    fn is_hookable(
        self: @TContractState
    ) -> bool;

    fn get_hook(
        self: @TContractState
    ) -> ContractAddress;

    fn get_preset(
        self: @TContractState
    ) -> Preset;

    fn get_actual(
        self: @TContractState
    ) -> Actual;

    fn calculate_amount_claimable(
        self: @TContractState,
        actual_id: u64
    ) -> (u256, u256);
}