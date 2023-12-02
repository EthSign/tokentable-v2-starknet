#[starknet::contract]
mod Unlocker {
    use debug::PrintTrait;
    use core::zeroable::Zeroable;
    use starknet::{
        ContractAddress,
        get_caller_address,
        get_contract_address,
        get_block_timestamp
    };
    use openzeppelin::{
        access::ownable::{
            OwnableComponent,
            interface::{
                IOwnableDispatcher,
                IOwnableDispatcherTrait
            }
        },
        security::ReentrancyGuardComponent,
        token::{
            erc20::{
                interface::{
                    IERC20Dispatcher,
                    IERC20DispatcherTrait
                },
            },
            erc721::{
                interface::{
                    IERC721Dispatcher,
                    IERC721DispatcherTrait
                }
            }
        }
    };
    use tokentable_v2::components::{
        structs::{
            actual::Actual,
            preset::Preset
        },
        interfaces::{
            unlocker::{
                IUnlocker,
                UnlockerErrors,
                UnlockerEvents
            },
            versionable::IVersionable,
            futuretoken::{
                IFutureTokenDispatcher,
                IFutureTokenDispatcherTrait
            },
            hook::{
                ITTHookDispatcher,
                ITTHookDispatcherTrait
            },
            deployer::{
                IDeployerDispatcher,
                IDeployerDispatcherTrait
            },
            feecollector::{
                IFeeCollectorDispatcher,
                IFeeCollectorDispatcherTrait
            },
        },
        span_impl::StoreU64Span,
    };

    component!(
        path: OwnableComponent, 
        storage: ownable, 
        event: OwnableEvent
    );
    component!(
        path: ReentrancyGuardComponent, 
        storage: reentrancy_guard, 
        event: ReentrancyGuardEvent
    );
   
    // Ownable
    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    #[abi(embed_v0)]
    impl OwnableCamelOnlyImpl =
        OwnableComponent::OwnableCamelOnlyImpl<ContractState>;
    impl InternalOwnableImpl = OwnableComponent::InternalImpl<ContractState>;
    // Reentrancy Guard
    impl InternalReentrancyGuardImpl = 
        ReentrancyGuardComponent::InternalImpl<ContractState>;

    const BIPS_PRECISION: u64 = 10000;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        reentrancy_guard: ReentrancyGuardComponent::Storage,
        project_token: IERC20Dispatcher,
        deployer: IDeployerDispatcher,
        futuretoken: IFutureTokenDispatcher,
        hook: ITTHookDispatcher,
        is_cancelable: bool,
        is_hookable: bool,
        // Presets (we cannot place them into a struct)
        presets_linear_start_timestamps_relative: LegacyMap<felt252, Span<u64>>,
        presets_linear_end_timestamp_relative: LegacyMap<felt252, u64>,
        presets_linear_bips: LegacyMap<felt252, Span<u64>>,
        presets_num_of_unlocks_for_each_linear: LegacyMap<felt252, Span<u64>>,
        actuals: LegacyMap<u256, Actual>,
        amount_unlocked_leftover_for_actuals: LegacyMap<u256, u256>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        ReentrancyGuardEvent: ReentrancyGuardComponent::Event,
        PresetCreated: UnlockerEvents::PresetCreated,
        ActualCreated: UnlockerEvents::ActualCreated,
        TokensDeposited: UnlockerEvents::TokensDeposited,
        TokensClaimed: UnlockerEvents::TokensClaimed,
        TokensWithdrawn: UnlockerEvents::TokensWithdrawn,
        ActualCancelled: UnlockerEvents::ActualCancelled,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        project_token: ContractAddress,
        futuretoken: ContractAddress,
        deployer: ContractAddress
    ) {
        self.ownable.initializer(get_caller_address());
        self.project_token.write(IERC20Dispatcher {
            contract_address: project_token
        });
        self.futuretoken.write(IFutureTokenDispatcher {
            contract_address: futuretoken
        });
        self.deployer.write(IDeployerDispatcher {
            contract_address: deployer
        });
    }

    #[abi(embed_v0)]
    impl Versionable of IVersionable<ContractState> {
        fn version(self: @ContractState) -> felt252 {
            '2.0.3'
        }
    }

    #[abi(embed_v0)]
    impl UnlockerImpl of IUnlocker<ContractState> {
        fn create_preset(
            ref self: ContractState,
            preset_id: felt252,
            linear_start_timestamps_relative: Span<u64>,
            linear_end_timestamp_relative: u64,
            linear_bips: Span<u64>,
            num_of_unlocks_for_each_linear: Span<u64>
        ) {
            self.ownable.assert_only_owner();
            let mut preset = self._build_preset_from_storage(preset_id);
            assert(
                _preset_is_empty(preset), 
                UnlockerErrors::PRESET_EXISTS
            );
            preset = Preset {
                linear_start_timestamps_relative,
                linear_end_timestamp_relative,
                linear_bips,
                num_of_unlocks_for_each_linear
            };
            assert(
                _preset_has_valid_format(preset),
                UnlockerErrors::INVALID_PRESET_FORMAT
            );
            self._save_preset_to_storage(preset_id, preset);
            self.emit(
                Event::PresetCreated(
                    UnlockerEvents::PresetCreated {
                        preset_id
                    }
                )
            );
        }

        fn create_actual(
            ref self: ContractState,
            recipient: ContractAddress,
            preset_id: felt252,
            start_timestamp_absolute: u64,
            amount_skipped: u256,
            total_amount: u256,
            amount_depositing_now: u256
        ) -> u256 {
            self.ownable.assert_only_owner();
            let actual_id = self.futuretoken.read().mint(recipient);
            let preset = self._build_preset_from_storage(preset_id);
            assert(
                !_preset_is_empty(preset), 
                UnlockerErrors::PRESET_DOES_NOT_EXIST
            );
            assert(
                amount_skipped < total_amount,
                UnlockerErrors::INVALID_SKIP_AMOUNT
            );
            if amount_depositing_now > 0 {
                let result = self.project_token.read().transfer_from(
                    get_caller_address(),
                    get_contract_address(),
                    amount_depositing_now
                );
                assert(
                    result,
                    UnlockerErrors::GENERIC_ERC20_TRANSFER_ERROR
                );
                self.emit(
                    Event::TokensDeposited(
                        UnlockerEvents::TokensDeposited {
                            actual_id,
                            amount: amount_depositing_now
                        }
                    )
                );
            }
            let new_actual = Actual {
                preset_id,
                start_timestamp_absolute,
                amount_claimed: amount_skipped,
                amount_deposited: amount_depositing_now,
                total_amount: total_amount
            };
            self.actuals.write(actual_id, new_actual);
            self.emit(
                Event::ActualCreated(
                    UnlockerEvents::ActualCreated {
                        preset_id,
                        actual_id
                    }
                )
            );
            actual_id
        }

        fn deposit(
            ref self: ContractState,
            actual_id: u256,
            amount: u256
        ) {
            self.ownable.assert_only_owner();
            let mut actual = self.actuals.read(actual_id);
            let result = self.project_token.read().transfer_from(
                get_caller_address(),
                get_contract_address(),
                amount
            );
            assert(
                result,
                UnlockerErrors::GENERIC_ERC20_TRANSFER_ERROR
            );
            self.emit(
                Event::TokensDeposited(
                    UnlockerEvents::TokensDeposited {
                        actual_id,
                        amount
                    }
                )
            );
            actual.amount_deposited += amount;
            self.actuals.write(actual_id, actual);
        }

        fn withdraw_deposit(
            ref self: ContractState,
            actual_id: u256,
            amount: u256
        ) {
            self.ownable.assert_only_owner();
            let mut actual = self.actuals.read(actual_id);
            actual.amount_deposited -= amount;
            let result = self.project_token.read().transfer(
                get_caller_address(),
                amount
            );
            assert(
                result,
                UnlockerErrors::GENERIC_ERC20_TRANSFER_ERROR
            );
            self.emit(
                Event::TokensWithdrawn(
                    UnlockerEvents::TokensWithdrawn {
                        actual_id,
                        by: get_caller_address(),
                        amount
                    }
                )
            );
            self.actuals.write(actual_id, actual);
        }

        fn claim(
            ref self: ContractState,
            actual_id: u256,
            override_recipient: ContractAddress
        ) {
            self.reentrancy_guard.start();
            let (delta_amount_claimable, recipient) = 
                self._update_actual_and_send(actual_id, override_recipient);
            self.emit(
                Event::TokensClaimed(
                    UnlockerEvents::TokensClaimed {
                        actual_id,
                        caller: get_caller_address(),
                        to: recipient,
                        amount: delta_amount_claimable
                    }
                )
            );
            self.reentrancy_guard.end();
        }

        fn claim_cancelled_actual(
            ref self: ContractState,
            actual_id: u256,
            override_recipient: ContractAddress
        ) {
            self.reentrancy_guard.start();
            let mut recipient: ContractAddress = Zeroable::zero();
            if override_recipient == Zeroable::zero() {
                recipient = IERC721Dispatcher {
                    contract_address: self.futuretoken.read().contract_address
                }.owner_of(actual_id);
            } else {
                recipient = override_recipient;
            }
            let amount_claimable = 
                self.amount_unlocked_leftover_for_actuals.read(actual_id);
            self.amount_unlocked_leftover_for_actuals.write(actual_id, 0);
            let result = self.project_token.read().transfer(
                recipient,
                amount_claimable
            );
            assert(
                result,
                UnlockerErrors::GENERIC_ERC20_TRANSFER_ERROR
            );
            self.emit(
                Event::TokensClaimed(
                    UnlockerEvents::TokensClaimed {
                        actual_id,
                        caller: get_caller_address(),
                        to: recipient,
                        amount: amount_claimable
                    }
                )
            );
            self.reentrancy_guard.end();
        }

        fn cancel(
            ref self: ContractState,
            actual_id: u256,
            refund_founder_address: ContractAddress
        ) -> (u256, u256) {
            assert(
                self.is_cancelable.read(),
                UnlockerErrors::UNAUTHORIZED
            );
            self.ownable.assert_only_owner();
            let (amount_unlocked_leftover, _) = 
                self.calculate_amount_claimable(actual_id);
            self.amount_unlocked_leftover_for_actuals.write(
                actual_id,
                self.amount_unlocked_leftover_for_actuals.read(actual_id) + 
                amount_unlocked_leftover
            );
            let mut actual = self.actuals.read(actual_id);
            assert(
                actual.amount_deposited >= amount_unlocked_leftover,
                UnlockerErrors::INSUFFICIENT_DEPOSIT
            );
            actual.amount_deposited -= amount_unlocked_leftover;
            let amount_refunded = actual.amount_deposited;
            let result = self.project_token.read().transfer(
                refund_founder_address,
                amount_refunded
            );
            assert(
                result,
                UnlockerErrors::GENERIC_ERC20_TRANSFER_ERROR
            );
            self.emit(
                Event::ActualCancelled(
                    UnlockerEvents::ActualCancelled {
                        actual_id,
                        amount_unlocked_leftover,
                        amount_refunded,
                        refund_founder_address
                    }
                )
            );
            self.actuals.write(actual_id, Actual {
                preset_id: 0, 
                start_timestamp_absolute: 0, 
                amount_claimed: 0, 
                amount_deposited: 0, 
                total_amount: 0
            });
            (amount_unlocked_leftover, amount_refunded)
        }

        fn set_hook(
            ref self: ContractState,
            hook: ContractAddress
        ) {
            self.hook.write(ITTHookDispatcher {
                contract_address: hook
            });
        }

        fn disable_cancel(
            ref self: ContractState
        ) {
            self.is_cancelable.write(false);
        }

        fn disable_hook(
            ref self: ContractState
        ) {
            self.is_hookable.write(false);
        }

        fn is_cancelable(
            self: @ContractState
        ) -> bool {
            self.is_cancelable.read()
        }

        fn is_hookable(
            self: @ContractState
        ) -> bool {
            self.is_hookable.read()
        }

        fn get_hook(
            self: @ContractState
        ) -> ContractAddress {
            self.hook.read().contract_address
        }

        fn get_futuretoken(
            self: @ContractState
        ) -> ContractAddress {
            self.futuretoken.read().contract_address
        }

        fn get_preset(
            self: @ContractState,
            preset_id: felt252
        ) -> Preset {
            self._build_preset_from_storage(preset_id)
        }

        fn get_actual(
            self: @ContractState,
            actual_id: u256
        ) -> Actual {
            self.actuals.read(actual_id)
        }

        fn calculate_amount_claimable(
            self: @ContractState,
            actual_id: u256
        ) -> (u256, u256) {
            let actual = self.actuals.read(actual_id);
            let preset = self._build_preset_from_storage(actual.preset_id);
            let updated_amount_claimed = 
                self.calculate_amount_of_tokens_to_claim_at_timestamp(
                    actual.start_timestamp_absolute,
                    preset.linear_end_timestamp_relative,
                    preset.linear_start_timestamps_relative,
                    get_block_timestamp(),
                    preset.linear_bips,
                    preset.num_of_unlocks_for_each_linear,
                    BIPS_PRECISION,
                    actual.total_amount
                );
            let mut delta_amount_claimable: u256 = 0;
            if actual.amount_claimed > updated_amount_claimed {
                delta_amount_claimable = 0;
            } else {
                delta_amount_claimable = 
                    updated_amount_claimed - actual.amount_claimed;
            }
            (delta_amount_claimable, updated_amount_claimed)
        }

        fn calculate_amount_of_tokens_to_claim_at_timestamp(
            self: @ContractState,
            actual_start_timestamp_absolute: u64,
            preset_linear_end_timestamp_relative: u64,
            preset_linear_start_timestamps_relative: Span<u64>,
            claim_timestamp_absolute: u64,
            preset_linear_bips: Span<u64>,
            preset_num_of_unlocks_for_each_linear: Span<u64>,
            preset_bips_precision: u64,
            actual_total_amount: u256,
        ) -> u256 {
            let mut updated_amount_claimed: u256 = 0;
            let precision_decimals = 100000;
            let mut i = 0;
            let mut latest_incomplete_linear_index = 0;
            let block_timestamp = claim_timestamp_absolute;
            if block_timestamp < actual_start_timestamp_absolute {
                return 0;
            }
            let claim_timestamp_relative = 
                block_timestamp - actual_start_timestamp_absolute;
            loop {
                if i == preset_linear_start_timestamps_relative.len() {
                    break;
                }
                if *preset_linear_start_timestamps_relative.at(i) <= 
                    claim_timestamp_relative {
                    latest_incomplete_linear_index = i;
                } else {
                    break;
                }
                i += 1;
            };
            // 1. calculate completed linear index claimables in bips
            i = 0;
            loop {
                if i == latest_incomplete_linear_index {
                    break;
                }
                updated_amount_claimed += 
                    (*preset_linear_bips.at(i)).into() * precision_decimals;
                i += 1;
            };
            // 2. calculate incomplete linear index claimable in bips
            let mut latest_incomplete_linear_duration = 0;
            if latest_incomplete_linear_index == 
                preset_linear_start_timestamps_relative.len() - 1 {
                latest_incomplete_linear_duration = 
                    preset_linear_end_timestamp_relative - 
                        *preset_linear_start_timestamps_relative.at(
                            preset_linear_start_timestamps_relative.len() - 1
                        );
            } else {
                latest_incomplete_linear_duration = 
                    *preset_linear_start_timestamps_relative.at(
                        latest_incomplete_linear_index + 1
                    ) - 
                    *preset_linear_start_timestamps_relative.at(
                        latest_incomplete_linear_index
                    );
            }
            if latest_incomplete_linear_duration == 0 {
                latest_incomplete_linear_duration = 1;
            }
            let latest_incomplete_linear_interval_for_each_unlock =
                latest_incomplete_linear_duration /
                    *preset_num_of_unlocks_for_each_linear.at(
                        latest_incomplete_linear_index
                    );
            let latest_incomplete_linear_claimable_timestamp_relative = 
                claim_timestamp_relative - 
                    *preset_linear_start_timestamps_relative.at(
                        latest_incomplete_linear_index
                    );
            let num_of_claimable_unlocks_in_incomplete_linear =
                latest_incomplete_linear_claimable_timestamp_relative /
                    latest_incomplete_linear_interval_for_each_unlock;
            updated_amount_claimed +=
                (*preset_linear_bips.at(latest_incomplete_linear_index)).into()
                    *
                    precision_decimals *
                    num_of_claimable_unlocks_in_incomplete_linear.into() /
                (*preset_num_of_unlocks_for_each_linear.at(
                    latest_incomplete_linear_index
                )).into();
            updated_amount_claimed = 
                updated_amount_claimed * actual_total_amount /
                BIPS_PRECISION.into() / precision_decimals;
            if updated_amount_claimed > actual_total_amount {
                updated_amount_claimed = actual_total_amount;
            }
            updated_amount_claimed
        }
    }

    #[generate_trait]
    impl UnlockerInternal of UnlockerInternalTrait {
        fn _build_preset_from_storage(
            self: @ContractState,
            preset_id: felt252,
        ) -> Preset {
            Preset {
                linear_start_timestamps_relative: 
                    self.presets_linear_start_timestamps_relative.read(preset_id),
                linear_end_timestamp_relative: 
                    self.presets_linear_end_timestamp_relative.read(preset_id),
                linear_bips: 
                    self.presets_linear_bips.read(preset_id),
                num_of_unlocks_for_each_linear: 
                    self.presets_num_of_unlocks_for_each_linear.read(preset_id)
            }
        }

        fn _save_preset_to_storage(
            ref self: ContractState,
            preset_id: felt252,
            preset: Preset
        ) {
            self.presets_linear_start_timestamps_relative.write(
                preset_id, preset.linear_start_timestamps_relative
            );
            self.presets_linear_end_timestamp_relative.write(
                preset_id, preset.linear_end_timestamp_relative
            );
            self.presets_linear_bips.write(preset_id, preset.linear_bips);
            self.presets_num_of_unlocks_for_each_linear.write(
                preset_id, preset.num_of_unlocks_for_each_linear
            );
        }

        fn _call_hook_if_defined(
            ref self: ContractState, 
            selector: felt252,
            context: Span<felt252>,
        ) {
            let hook = self.hook.read();
            if hook.contract_address.is_non_zero() {
                hook.did_call(
                    selector,
                    context,
                    get_caller_address()
                );
            }
        }

        fn _update_actual_and_send(
            ref self: ContractState,
            actual_id: u256,
            override_recipient: ContractAddress,
        ) -> (u256, ContractAddress) {
            let mut recipient: ContractAddress = Zeroable::zero();
            let (mut delta_amount_claimable, updated_amount_claimed) = 
                self.calculate_amount_claimable(actual_id);
            let mut actual = self.actuals.read(actual_id);
            actual.amount_claimed = updated_amount_claimed;
            assert(
                actual.amount_deposited >= delta_amount_claimable,
                UnlockerErrors::INSUFFICIENT_DEPOSIT
            );
            actual.amount_deposited -= delta_amount_claimable;
            if override_recipient == Zeroable::zero() {
                recipient = IERC721Dispatcher {
                    contract_address: self.futuretoken.read().contract_address
                }.owner_of(actual_id);
            } else {
                recipient = override_recipient;
            }
            if self.deployer.read().contract_address.is_non_zero() {
                let fee_collector_address = 
                    self.deployer.read().get_fee_collector();
                let fees_collected = IFeeCollectorDispatcher {
                    contract_address: fee_collector_address
                }.get_fee(
                    get_contract_address(),
                    delta_amount_claimable
                );
                if fees_collected > 0 {
                    delta_amount_claimable -= fees_collected;
                    let result = self.project_token.read().transfer(
                        IOwnableDispatcher {
                            contract_address: fee_collector_address
                        }.owner(),
                        fees_collected
                    );
                    assert(
                        result, 
                        UnlockerErrors::GENERIC_ERC20_TRANSFER_ERROR
                    );
                }
            }
            self.actuals.write(actual_id, actual);
            let result = self.project_token.read().transfer(
                recipient,
                delta_amount_claimable
            );
            assert(
                result, 
                UnlockerErrors::GENERIC_ERC20_TRANSFER_ERROR
            );
            (delta_amount_claimable, recipient)
        }
    }

    fn _preset_is_empty(
        preset: Preset
    ) -> bool {
        preset.linear_bips.len() *
        preset.linear_start_timestamps_relative.len() *
        preset.num_of_unlocks_for_each_linear.len() == 0
        ||
        preset.linear_end_timestamp_relative == 0
    }

    fn _preset_has_valid_format(
        preset: Preset
    ) -> bool {
        let mut i = 0;
        let mut total = 0;
        let linear_start_timestamps_relative_len = 
            preset.linear_start_timestamps_relative.len();
        loop {
            if i == preset.linear_bips.len() {
                break;
            }
            total += *preset.linear_bips.at(i);
            i += 1;
        };
        total.into() == BIPS_PRECISION &&
        preset.linear_bips.len() == 
            linear_start_timestamps_relative_len &&
        *preset.linear_start_timestamps_relative.at(
            linear_start_timestamps_relative_len - 1
        ) < preset.linear_end_timestamp_relative &&
        preset.num_of_unlocks_for_each_linear.len() ==
            linear_start_timestamps_relative_len
    }

}
