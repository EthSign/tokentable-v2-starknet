//! SPDX-License-Identifier: Apache 2.0
//!
//! TokenTable Unlocker Interface
//!
//! The lightweight interface for TokenTableUnlockerV2(.5.x), which handles token unlocking and distribution for TokenTable.

use starknet::{ContractAddress};
use tokentable_v2::components::structs::{
    preset::Preset, actual::Actual
};

#[starknet::interface]
trait ITTUnlocker<TContractState> {
    /// Creates an unlocking schedule Preset.
    ///
    /// # Arguments
    /// * `preset_id`: Refer to `Preset`.
    /// * `linear_start_timestamps_relative`: Refer to `Preset`.
    /// * `linear_start_timestamps_relative`: Refer to `Preset`.
    /// * `linear_bips`: Refer to `Preset`.
    /// * `num_of_unlocks_for_each_linear`: Refer to `Preset`.
    /// * `stream`: Refer to `Preset`.
    /// * `recipient_id`: Emitted as an event reserved for EthSign frontend use. This parameter has no effect on contract execution.
    ///
    /// # Panics
    /// * `INVALID_PRESET_FORMAT`: If the preset is not formatted correctly (e.g. `linear_bips` fails to add up to `BIPS_PRECISION`)
    /// * `PRESET_EXISTS`: If the input `preset_id` has already been created.
    /// * `OwnableComponent::Errors::NOT_OWNER`: If the caller is not the owner.
    ///
    /// # Events
    /// * `PresetCreated`
    fn create_preset(
        ref self: TContractState,
        preset_id: felt252,
        linear_start_timestamps_relative: Span<u64>,
        linear_end_timestamp_relative: u64,
        linear_bips: Span<u64>,
        num_of_unlocks_for_each_linear: Span<u64>,
        stream: bool,
        recipient_id: u64,
        extraData: felt252,
    );

    /// Creates an unlocking schedule Actual.
    ///
    /// # Arguments
    /// * `recipient`: The initial recipient of the unlocked tokens.
    /// * `preset_id`: The unlocking schedule preset that this `Actual` builds on top of.
    /// * `start_timestamp_absolute`: Refer to `Actual`.
    /// * `amount_skipped`: Refer to `Actual`.
    /// * `total_amount`: Refer to `Actual`.
    /// * `unsafe_mint`: Use `mint(...)` instead of `safe_mint(...)`.
    /// * `recipient_id`: Emitted as an event reserved for EthSign frontend use. This parameter has no effect on contract execution.
    /// * `batch_id`: Emitted as an event reserved for EthSign frontend use. This parameter has no effect on contract execution.
    /// 
    /// # Panics
    /// * `PRESET_DOES_NOT_EXIST`: If `preset_id` does not exist.
    /// * `INVALID_SKIP_AMOUNT`: If the amount of tokens skipped is greater than or equal to the total unlocked amount.
    /// * `OwnableComponent::Errors::NOT_OWNER`: If the caller is not the owner.
    ///
    /// # Events
    /// * `ActualCreated`
    ///
    /// # Returns
    /// * `u256`: The created `actual_id`, aka the unlocking schedule ID.
    fn create_actual(
        ref self: TContractState,
        recipient: ContractAddress,
        preset_id: felt252,
        start_timestamp_absolute: u64,
        amount_skipped: u256,
        total_amount: u256,
        unsafe_mint: bool,
        recipient_id: u64,
        batch_id: u64,
        extraData: felt252,
    ) -> u256;

    /// Withdraws any unclaimed deposit held by the Unlocker.
    ///
    /// # Arguments
    /// * `amount`: The amount of tokens to withdraw.
    ///
    /// # Panics
    /// * `NOT_PERMISSIONED`: If withdrawing has been disabled.
    /// * `GENERIC_ERC20_TRANSFER_ERROR`: If for any reason the token transfer returns `false`.
    /// * `OwnableComponent::Errors::NOT_OWNER`: If the caller is not the owner.
    ///
    /// # Events
    /// * `TokensWithdrawn`
    fn withdraw_deposit(
        ref self: TContractState,
        amount: u256,
        extraData: felt252,
    );

    /// Claims your unlocked tokens as a recipient. 
    /// Any fees charged are not taken from the claimed amount.
    ///
    /// # Arguments
    /// * `actual_id`: The schedule ID assigned to you.
    /// * `claim_to`: The destination address for the claimed tokens. Use Zeroable::zero() to claim to your current address.
    /// * `recipient_id`: Emitted as an event reserved for EthSign frontend use. This parameter has no effect on contract execution.
    ///
    /// # Panics
    /// * `NOT_PERMISSIONED`: If the caller isn't the recipient of said `actual_id`.
    /// * `GENERIC_ERC20_TRANSFER_ERROR`: If for any reason the token transfer returns `false`.
    /// * `ReentrancyGuardComponent::Errors::REENTRANT_CALL`: If a reentrant call is detected.
    ///
    /// # Events
    /// * `TokensClaimed`
    fn claim(
        ref self: TContractState,
        actual_id: u256,
        claim_to: ContractAddress,
        recipient_id: u64,
        extraData: felt252,
    );

    /// Claims someone else's unlocked tokens as an authorized claiming delegate.
    ///
    /// # Arguments
    /// * `actual_id`: The schedule ID assigned to you.
    /// * `recipient_id`: Emitted as an event reserved for EthSign frontend use. This parameter has no effect on contract execution.
    ///
    /// # Panics
    /// * `NOT_PERMISSIONED`: If the caller isn't an authorized claiming delegate.
    /// * `GENERIC_ERC20_TRANSFER_ERROR`: If for any reason the token transfer returns `false`.
    /// * `ReentrancyGuardComponent::Errors::REENTRANT_CALL`: If a reentrant call is detected.
    ///
    /// # Events
    /// * `TokensClaimed`
    fn delegate_claim(
        ref self: TContractState,
        actual_id: u256,
        recipient_id: u64,
        extraData: felt252,
    );

    /// Cancels an existing schedule.
    ///
    /// # Arguments
    /// * `actual_id`: The schedule ID to cancel.
    /// * `wipe_claimable_balance`: Normally when canceling a schedule, calculation is performed to ensure the recipient will receive unlocked tokens until the moment of cancellation. This option prevents such calculation.
    /// * `recipient_id`: Emitted as an event reserved for EthSign frontend use. This parameter has no effect on contract execution.
    ///
    /// # Panics
    /// * `NOT_PERMISSIONED`: If cancellation is disabled.
    /// * `OwnableComponent::Errors::NOT_OWNER`: If the caller is not the owner.
    ///
    /// # Events
    /// * `ActualCancelled`
    ///
    /// # Returns
    /// * `u256`: The amount claimable by the recipient from the cancelled schedule.
    fn cancel(
        ref self: TContractState,
        actual_id: u256,
        wipe_claimable_balance: bool,
        recipient_id: u64,
        extraData: felt252,
    ) -> u256;

    /// Sets the external hook contract.
    ///
    /// # Arguments
    /// * `hook`: The address of an external contract that implements ITTHook.
    ///
    /// # Panics
    /// * `NOT_PERMISSIONED`: If hooking is disabled.
    /// * `OwnableComponent::Errors::NOT_OWNER`: If the caller is not the owner.
    fn set_hook(
        ref self: TContractState,
        hook: ContractAddress
    );

    /// Sets the claiming delegate, who can trigger claim on behalf of recipients.
    ///
    /// # Arguments
    /// * `delegate`: The address of the claiming delegate.
    ///
    /// # Panics
    /// * `OwnableComponent::Errors::NOT_OWNER`: If the caller is not the owner.
    fn set_claiming_delegate(
        ref self: TContractState,
        delegate: ContractAddress,
    );

    /// Permanently disables the ability for the owner to cancel schedules.
    ///
    /// # Panics
    /// * `OwnableComponent::Errors::NOT_OWNER`: If the caller is not the owner.
    ///
    /// # Events
    /// * `CancelDisabled`
    fn disable_cancel(
        ref self: TContractState
    );

    /// Permanently disables the ability for the owner to set external hooks. 
    /// Also clears the current hook.
    ///
    /// # Panics
    /// * `OwnableComponent::Errors::NOT_OWNER`: If the caller is not the owner.
    ///
    /// # Events
    /// * `HookDisabled`
    fn disable_hook(
        ref self: TContractState
    );

    /// Permanently disables the ability for the owner to withdraw deposit.
    ///
    /// # Panics
    /// * `OwnableComponent::Errors::NOT_OWNER`: If the caller is not the owner.
    ///
    /// # Events
    /// * `WithdrawDisabled`
    fn disable_withdraw(
        ref self: TContractState
    );

    /// Permanently disables the ability for the owner to create new schedules.
    ///
    /// # Panics
    /// * `OwnableComponent::Errors::NOT_OWNER`: If the caller is not the owner.
    ///
    /// # Events
    /// * `CreateDisabled`
    fn disable_create(
        ref self: TContractState
    );

    /// Returns the address of the TokenTable Deployer.
    fn deployer(
        self: @TContractState
    ) -> ContractAddress;

    /// Returns the address of the FutureToken NFT created alongside this Unlocker instance.
    fn futuretoken(
        self: @TContractState
    ) -> ContractAddress;

    /// Returns the address of the external hook set by the owner.
    fn hook(
        self: @TContractState
    ) -> ContractAddress;

    /// Returns the address of the claiming delegate set by the owner.
    fn claiming_delegate(
        self: @TContractState
    ) -> ContractAddress;

    /// Returns if schedules are cancelable.
    fn is_cancelable(
        self: @TContractState
    ) -> bool;

    /// Returns if external hooks are allowed to be set.
    fn is_hookable(
        self: @TContractState
    ) -> bool;

    /// Returns if the owner can withdraw deposited tokens.
    fn is_withdrawable(
        self: @TContractState
    ) -> bool;

    /// Returns if the owner can create new schedules.
    fn is_createable(
        self: @TContractState
    ) -> bool;
    
    /// Returns the requested `Preset` struct.
    fn get_preset(
        self: @TContractState,
        preset_id: felt252
    ) -> Preset;

    /// Returns the requested `Actual` struct.
    fn get_actual(
        self: @TContractState,
        actual_id: u256
    ) -> Actual;

    /// Returns the amount of claimable tokens for a cancelled schedule.
    ///
    /// # Arguments
    /// * `actual_id`: The cancenlled schedule ID that we are querying.
    fn get_cancelled_amount_claimable(
        self: @TContractState,
        actual_id: u256,
    ) -> u256;

    /// Calculates the amount of claimable tokens for an ongoing schedule.
    /// Internally calls simulate_amount_claimable().
    ///
    /// # Arguments
    /// * `actual_id`: The ongoing schedule ID that we are querying.
    ///
    /// # Returns
    /// * `u256`: The claimable amount of tokens this time.
    /// * `u256`: The updated total amount of tokens claimed after this claim action.
    fn calculate_amount_claimable(
        self: @TContractState,
        actual_id: u256
    ) -> (u256, u256);

    /// Simulates the amount of claimable tokens for an ongoing schedule.
    /// This function exposes more parameters to make testing the calculation logic easier.
    ///
    /// # Arguments
    /// * `actual_start_timestamp_absolute`: Refer to `Actual.start_timestamp_absolute`.
    /// * `preset_linear_end_timestamp_relative`: Refer to `Preset.linear_end_timestamp_relative`.
    /// * `preset_linear_start_timestamps_relative`: Refer to `Preset.linear_start_timestamps_relative`.
    /// * `claim_timestamp_absolute`: The timestamp of when claim() is called. Must be in the future.
    /// * `preset_linear_bips`: Refer to `Preset.linear_bips`.
    /// * `preset_num_of_unlocks_for_each_linear`: Refer to `Preset.num_of_unlocks_for_each_linear`.
    /// * `preset_stream`: Refer to `Preset.stream`.
    /// * `preset_bips_precision`: The decimal precision of calculation. Hardcoded to 10000.
    /// * `actual_total_amount`: Refer to `Actual.total_amount`.
    ///
    /// # Returns
    /// * `u256`: The claimable amount of tokens this time.
    fn simulate_amount_claimable(
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
    struct Initialized {
        project_id: felt252,
    }

    #[derive(Drop, starknet::Event)]
    struct PresetCreated {
        from: super::ContractAddress,
        preset_id: felt252,
        recipient_id: u64,
    }

    #[derive(Drop, starknet::Event)]
    struct ActualCreated {
        from: super::ContractAddress,
        preset_id: felt252,
        actual_id: u256,
        recipient: super::ContractAddress,
        start_timestamp_absolute: u64,
        amount_skipped: u256,
        total_amount: u256,
        recipient_id: u64,
        batch_id: u64,
    }

    #[derive(Drop, starknet::Event)]
    struct TokensClaimed {
        actual_id: u256,
        caller: super::ContractAddress,
        to: super::ContractAddress,
        amount: u256,
        fees_charged: u256,
        recipient_id: u64,
    }

    #[derive(Drop, starknet::Event)]
    struct TokensWithdrawn {
        by: super::ContractAddress,
        amount: u256
    }

    #[derive(Drop, starknet::Event)]
    struct ActualCancelled {
        from: super::ContractAddress,
        actual_id: u256,
        pending_amount_claimable: u256,
        did_wipe_claimable_balance: bool,
        recipient_id: u64,
    }

    #[derive(Drop, starknet::Event)]
    struct CancelDisabled {
        from: super::ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct HookDisabled {
        from: super::ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct WithdrawDisabled {
        from: super::ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct CreateDisabled {
        from: super::ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct ClaimingDelegateSet {
        from: super::ContractAddress,
        delegate: super::ContractAddress,
    }
}

mod TTUnlockerErrors {
    const INVALID_PRESET_FORMAT: felt252 = 'INVALID_PRESET_FORMAT';
    const PRESET_EXISTS: felt252 = 'PRESET_EXISTS';
    const PRESET_DOES_NOT_EXIST: felt252 = 'PRESET_DOES_NOT_EXIST';
    const INVALID_SKIP_AMOUNT: felt252 = 'INVALID_SKIP_AMOUNT';
    const NOT_PERMISSIONED: felt252 = 'NOT_PERMISSIONED';
    const GENERIC_ERC20_TRANSFER_ERROR: felt252 = 
        'GENERIC_ERC20_TRANSFER_ERROR';
    const ACTUAL_DOES_NOT_EXIST: felt252 = 'ACTUAL_DOES_NOT_EXIST';
}