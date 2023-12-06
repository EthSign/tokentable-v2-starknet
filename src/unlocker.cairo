#[starknet::contract]
mod TTUnlocker {
    use debug::PrintTrait;
    use core::zeroable::Zeroable;
    use starknet::{
        ContractAddress,
        get_caller_address,
        get_contract_address,
        get_block_timestamp,
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
                ITTUnlocker,
                TTUnlockerErrors,
                TTUnlockerEvents
            },
            versionable::IVersionable,
            futuretoken::{
                ITTFutureTokenDispatcher,
                ITTFutureTokenDispatcherTrait
            },
            hook::{
                ITTHookDispatcher,
                ITTHookDispatcherTrait
            },
            deployer::{
                ITTDeployerDispatcher,
                ITTDeployerDispatcherTrait
            },
            feecollector::{
                ITTFeeCollectorDispatcher,
                ITTFeeCollectorDispatcherTrait
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
        deployer: ITTDeployerDispatcher,
        futuretoken: ITTFutureTokenDispatcher,
        hook: ITTHookDispatcher,
        is_cancelable: bool,
        is_hookable: bool,
        pool: u256,
        presets_linear_start_timestamps_relative: LegacyMap<felt252, Span<u64>>,
        presets_linear_end_timestamp_relative: LegacyMap<felt252, u64>,
        presets_linear_bips: LegacyMap<felt252, Span<u64>>,
        presets_num_of_unlocks_for_each_linear: LegacyMap<felt252, Span<u64>>,
        actuals: LegacyMap<u256, Actual>,
        pending_claimables_from_cancelled_actuals: LegacyMap<u256, u256>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        ReentrancyGuardEvent: ReentrancyGuardComponent::Event,
        PresetCreated: TTUnlockerEvents::PresetCreated,
        ActualCreated: TTUnlockerEvents::ActualCreated,
        TokensDeposited: TTUnlockerEvents::TokensDeposited,
        TokensClaimed: TTUnlockerEvents::TokensClaimed,
        TokensWithdrawn: TTUnlockerEvents::TokensWithdrawn,
        ActualCancelled: TTUnlockerEvents::ActualCancelled,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        project_token: ContractAddress,
        futuretoken: ContractAddress,
        deployer: ContractAddress
    ) {
        self.ownable.initializer(deployer);
        self.project_token.write(IERC20Dispatcher {
            contract_address: project_token
        });
        self.futuretoken.write(ITTFutureTokenDispatcher {
            contract_address: futuretoken
        });
        self.deployer.write(ITTDeployerDispatcher {
            contract_address: deployer
        });
        self.is_cancelable.write(true);
        self.is_hookable.write(true);
    }

    #[abi(embed_v0)]
    impl Versionable of IVersionable<ContractState> {
        fn version(self: @ContractState) -> felt252 {
            '2.0.3'
        }
    }

    #[abi(embed_v0)]
    impl TTUnlockerImpl of ITTUnlocker<ContractState> {
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
                TTUnlockerErrors::PRESET_EXISTS
            );
            preset = Preset {
                linear_start_timestamps_relative,
                linear_end_timestamp_relative,
                linear_bips,
                num_of_unlocks_for_each_linear
            };
            assert(
                _preset_has_valid_format(preset),
                TTUnlockerErrors::INVALID_PRESET_FORMAT
            );
            self._save_preset_to_storage(preset_id, preset);
            self.emit(
                Event::PresetCreated(
                    TTUnlockerEvents::PresetCreated {
                        preset_id
                    }
                )
            );
            self._call_hook_if_defined(
                'create_preset',
                array![preset_id].span()
            );
        }

        fn create_actual(
            ref self: ContractState,
            recipient: ContractAddress,
            preset_id: felt252,
            start_timestamp_absolute: u64,
            amount_skipped: u256,
            total_amount: u256,
            amount_depositing_now: u256,
            batch_id: u64,
        ) -> u256 {
            self.ownable.assert_only_owner();
            let actual_id = self.futuretoken.read().mint(recipient);
            let preset = self._build_preset_from_storage(preset_id);
            assert(
                !_preset_is_empty(preset), 
                TTUnlockerErrors::PRESET_DOES_NOT_EXIST
            );
            assert(
                amount_skipped < total_amount,
                TTUnlockerErrors::INVALID_SKIP_AMOUNT
            );
            if amount_depositing_now > 0 {
                let result = self.project_token.read().transfer_from(
                    get_caller_address(),
                    get_contract_address(),
                    amount_depositing_now
                );
                assert(
                    result,
                    TTUnlockerErrors::GENERIC_ERC20_TRANSFER_ERROR
                );
                let amount_post_deduction = 
                    self._charge_fee(amount_depositing_now);
                self.pool.write(self.pool.read() + amount_depositing_now);
                self.emit(
                    Event::TokensDeposited(
                        TTUnlockerEvents::TokensDeposited {
                            amount: amount_depositing_now,
                            amount_post_deduction,
                        }
                    )
                );
            }
            let new_actual = Actual {
                preset_id,
                start_timestamp_absolute,
                amount_claimed: amount_skipped,
                total_amount: total_amount
            };
            self.actuals.write(actual_id, new_actual);
            self.emit(
                Event::ActualCreated(
                    TTUnlockerEvents::ActualCreated {
                        preset_id,
                        actual_id,
                        batch_id
                    }
                )
            );
            self._call_hook_if_defined(
                'create_actual',
                array![actual_id.try_into().unwrap()].span()
            );
            actual_id
        }

        fn deposit(
            ref self: ContractState,
            amount: u256
        ) {
            self.ownable.assert_only_owner();
            let result = self.project_token.read().transfer_from(
                get_caller_address(),
                get_contract_address(),
                amount
            );
            assert(
                result,
                TTUnlockerErrors::GENERIC_ERC20_TRANSFER_ERROR
            );
            let amount_post_deduction = self._charge_fee(amount);
            self.pool.write(self.pool.read() + amount_post_deduction);
            self.emit(
                Event::TokensDeposited(
                    TTUnlockerEvents::TokensDeposited {
                        amount,
                        amount_post_deduction,
                    }
                )
            );
            self._call_hook_if_defined(
                'deposit',
                array![
                    amount.try_into().unwrap(),
                    amount_post_deduction.try_into().unwrap()
                ].span()
            );
        }

        fn withdraw_deposit(
            ref self: ContractState,
            amount: u256
        ) {
            self.ownable.assert_only_owner();
            self.pool.write(self.pool.read() - amount);
            let result = self.project_token.read().transfer(
                get_caller_address(),
                amount
            );
            assert(
                result,
                TTUnlockerErrors::GENERIC_ERC20_TRANSFER_ERROR
            );
            self.emit(
                Event::TokensWithdrawn(
                    TTUnlockerEvents::TokensWithdrawn {
                        by: get_caller_address(),
                        amount
                    }
                )
            );
            self._call_hook_if_defined(
                'withdraw_deposit',
                array![
                    amount.try_into().unwrap()
                ].span()
            );
        }

        fn claim(
            ref self: ContractState,
            actual_id: u256,
            override_recipient: ContractAddress
        ) {
            // self.reentrancy_guard.start();
            assert(
                IERC721Dispatcher {
                    contract_address: self.futuretoken.read().contract_address
                }.owner_of(actual_id) == get_caller_address(),
                TTUnlockerErrors::UNAUTHORIZED
            );
            let mut amount_claimed: u256 = 0;
            let mut recipient: ContractAddress = Zeroable::zero();
            if override_recipient == Zeroable::zero() {
                recipient = IERC721Dispatcher {
                    contract_address: self.futuretoken.read().contract_address
                }.owner_of(actual_id);
            } else {
                recipient = override_recipient;
            }
            let pending_claimable_from_cancelled_actual = 
                self.pending_claimables_from_cancelled_actuals.read(actual_id);
            if pending_claimable_from_cancelled_actual.is_non_zero() {
                self._send(recipient, pending_claimable_from_cancelled_actual);
                self.pending_claimables_from_cancelled_actuals.write(
                    actual_id, 0
                );
            } else {
                amount_claimed = 
                self._update_actual_and_send(actual_id, recipient);
            }
            self.emit(
                Event::TokensClaimed(
                    TTUnlockerEvents::TokensClaimed {
                        actual_id,
                        caller: get_caller_address(),
                        to: recipient,
                        amount: amount_claimed
                    }
                )
            );
            let override_recipient_felt252: felt252 = override_recipient.into();
            self._call_hook_if_defined(
                'claim',
                array![
                    actual_id.try_into().unwrap(), 
                    override_recipient_felt252
                ].span()
            );
            // self.reentrancy_guard.end();
        }

        fn cancel(
            ref self: ContractState,
            actual_id: u256,
        ) -> u256 {
            assert(
                self.is_cancelable.read(),
                TTUnlockerErrors::UNAUTHORIZED
            );
            self.ownable.assert_only_owner();
            let (pending_amount_claimable, _) = 
                self.calculate_amount_claimable(actual_id);
            let actual = self.actuals.read(actual_id);
            self.emit(
                Event::ActualCancelled(
                    TTUnlockerEvents::ActualCancelled {
                        actual_id,
                        pending_amount_claimable
                    }
                )
            );
            self.actuals.write(actual_id, Actual {
                preset_id: 0, 
                start_timestamp_absolute: 0, 
                amount_claimed: 0, 
                total_amount: 0
            });
            self.pending_claimables_from_cancelled_actuals.write(
                actual_id, 
                pending_amount_claimable
            );
            self._call_hook_if_defined(
                'cancel',
                array![
                    actual_id.try_into().unwrap(),
                ].span()
            );
            pending_amount_claimable
        }

        fn set_hook(
            ref self: ContractState,
            hook: ContractAddress
        ) {
            self.ownable.assert_only_owner();
            assert(
                self.is_hookable.read(),
                TTUnlockerErrors::UNAUTHORIZED
            );
            self.hook.write(ITTHookDispatcher {
                contract_address: hook
            });
            self._call_hook_if_defined(
                'set_hook',
                array![
                    get_caller_address().into()
                ].span()
            );
        }

        fn disable_cancel(
            ref self: ContractState
        ) {
            self.ownable.assert_only_owner();
            self.is_cancelable.write(false);
            self._call_hook_if_defined(
                'disable_cancel',
                array![
                    get_caller_address().into()
                ].span()
            );
        }

        fn disable_hook(
            ref self: ContractState
        ) {
            self.ownable.assert_only_owner();
            self.is_hookable.write(false);
            self.hook.write(ITTHookDispatcher { 
                contract_address: Zeroable::zero() 
            });
            self._call_hook_if_defined(
                'disable_hook',
                array![
                    get_caller_address().into()
                ].span()
            );
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

        fn get_pool(
            self: @ContractState,
        ) -> u256 {
            self.pool.read()
        }

        fn get_pending_amount_claimable(
            self: @ContractState,
            actual_id: u256,
        ) -> u256 {
            self.pending_claimables_from_cancelled_actuals.read(actual_id)
        }

        fn calculate_amount_claimable(
            self: @ContractState,
            actual_id: u256
        ) -> (u256, u256) {
            let actual = self.actuals.read(actual_id);
            if _actual_is_empty(actual) {
                return (0, 0);
            }
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
    impl TTUnlockerInternal of TTUnlockerInternalTrait {
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
            function_name: felt252,
            context: Span<felt252>,
        ) {
            let hook = self.hook.read();
            if hook.contract_address.is_non_zero() {
                hook.did_call(
                    function_name,
                    context,
                    get_caller_address()
                );
            }
        }

        fn _update_actual_and_send(
            ref self: ContractState,
            actual_id: u256,
            recipient: ContractAddress,
        ) -> u256 {
            let (mut delta_amount_claimable, updated_amount_claimed) = 
                self.calculate_amount_claimable(actual_id);
            let mut actual = self.actuals.read(actual_id);
            self._send(recipient, delta_amount_claimable);
            actual.amount_claimed = updated_amount_claimed;
            self.actuals.write(actual_id, actual);
            delta_amount_claimable
        }

        fn _send(
            ref self: ContractState,
            recipient: ContractAddress,
            amount: u256,
        ) {
            let result = self.project_token.read().transfer(
                recipient,
                amount
            );
            assert(
                result, 
                TTUnlockerErrors::GENERIC_ERC20_TRANSFER_ERROR
            );
            self.pool.write(self.pool.read() - amount);
        }

        fn _charge_fee(
            ref self: ContractState,
            amount: u256
        ) -> u256 {
            let mut amount_mut = amount;
            if self.deployer.read().contract_address.is_non_zero() {
                let fee_collector_address = 
                    self.deployer.read().get_fee_collector();
                let fees_collected = ITTFeeCollectorDispatcher {
                    contract_address: fee_collector_address
                }.get_fee(
                    get_contract_address(),
                    amount_mut
                );
                if fees_collected > 0 {
                    amount_mut -= fees_collected;
                    let result = self.project_token.read().transfer(
                        IOwnableDispatcher {
                            contract_address: fee_collector_address
                        }.owner(),
                        fees_collected
                    );
                    assert(
                        result, 
                        TTUnlockerErrors::GENERIC_ERC20_TRANSFER_ERROR
                    );
                }
            }
            amount_mut
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

    fn _actual_is_empty(
        actual: Actual
    ) -> bool {
        actual == Actual {
            preset_id: 0, 
            start_timestamp_absolute: 0, 
            amount_claimed: 0, 
            total_amount: 0
        }
    }

}
