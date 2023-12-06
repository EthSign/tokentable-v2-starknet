use core::traits::TryInto;
use core::result::ResultTrait;
use debug::PrintTrait;
use snforge_std::{
    declare, 
    ContractClassTrait,
    test_address,
    start_prank,
    stop_prank,
    CheatTarget,
    start_warp,
    stop_warp,
};
use zeroable::Zeroable;
use starknet::{
    ContractAddress, 
    get_block_timestamp,
};
use tokentable_v2::{
    components::{
        interfaces::{
            unlocker::{
                ITTUnlockerSafeDispatcher,
                ITTUnlockerSafeDispatcherTrait,
                TTUnlockerErrors,
            },
            futuretoken::{
                ITTFutureTokenSafeDispatcher,
                ITTFutureTokenSafeDispatcherTrait,
            },
            deployer::{
                ITTDeployerSafeDispatcher,
                ITTDeployerSafeDispatcherTrait,
                TTDeployerErrors,
            },
            feecollector::{
                ITTFeeCollectorSafeDispatcher,
                ITTFeeCollectorSafeDispatcherTrait,
            },
            versionable::{
                IVersionableDispatcher,
                IVersionableDispatcherTrait,
            },
            mockerc20::{
                IMockERC20Dispatcher,
                IMockERC20DispatcherTrait,
            }
        },
        structs::{
            actual::Actual,
            preset::Preset,
            ttsuite::TTSuite,
        },
    },
};
use openzeppelin::{
    access::ownable::{
        OwnableComponent::Errors,
        interface::{
            IOwnableDispatcher,
            IOwnableDispatcherTrait,
        }
    },
    token::erc20::interface::{
        IERC20Dispatcher,
        IERC20DispatcherTrait
    },
};

fn deploy_deployer() -> ITTDeployerSafeDispatcher {
    let deployer_class = declare('TTDeployer');
    let test_address_felt252: felt252 = test_address().into();
    let deployer_contract_address = 
        deployer_class.deploy(@array![test_address_felt252]).unwrap();
    let deployer = ITTDeployerSafeDispatcher { 
        contract_address: deployer_contract_address 
    };
    let unlocker_class = declare('TTUnlocker');
    let futuretoken_class = declare('TTFutureToken');
    deployer.set_class_hash(
        unlocker_class.class_hash, 
        futuretoken_class.class_hash
    );
    let feecollector_class = declare('TTFeeCollector');
    let feecollector_contract_address = 
        feecollector_class.deploy(@array![test_address_felt252]).unwrap();
    deployer.set_fee_collector(feecollector_contract_address);
    deployer
}

fn deploy_mockerc20() -> IERC20Dispatcher {
    let mockerc20_class = declare('MockERC20');
    let mockerc20_contract_address = 
        mockerc20_class.deploy(@ArrayTrait::new()).unwrap();
    IERC20Dispatcher { contract_address: mockerc20_contract_address }
}

fn deploy_ttsuite(
    deployer: ITTDeployerSafeDispatcher,
    project_id: felt252,
    allow_transferable_ft: bool
) -> (
    ITTUnlockerSafeDispatcher, 
    ITTFutureTokenSafeDispatcher, 
    IERC20Dispatcher, 
    felt252
) {
    let mockerc20 = deploy_mockerc20();
    let (unlocker_address, futuretoken_address) = deployer.deploy_ttsuite(
        mockerc20.contract_address,
        project_id,
        allow_transferable_ft,
    ).unwrap();
    let unlocker_instance = ITTUnlockerSafeDispatcher {
        contract_address: unlocker_address
    };
    let futuretoken_instance = ITTFutureTokenSafeDispatcher {
        contract_address: futuretoken_address
    };
    (unlocker_instance, futuretoken_instance, mockerc20, project_id)
}

fn get_test_preset_params_0() 
    -> (felt252, Span<u64>, u64, Span<u64>, Span<u64>) {
    (
        'test preset', 
        array![0, 10, 11, 30, 31, 60, 100].span(),
        400,
        array![0, 1000, 0, 2000, 0, 4000, 3000].span(),
        array![1, 1, 1, 1, 1, 4, 3].span()
    )
}

fn get_test_actual_params_no_skip() -> (u256, u256, u256) {
    (0, 0, 10000)
}

fn get_test_actual_params_skip() -> (u256, u256, u256) {
    (5000, 0, 10000)
}

#[test]
// #[ignore]
fn deployer_test() {
    let deployer_instance = deploy_deployer();
    let (
            unlocker_instance, 
            futuretoken_instance, 
            mockerc20_instance, 
            project_id
        ) = deploy_ttsuite(deployer_instance, 'test project', true);
    assert(
        IVersionableDispatcher { 
            contract_address: unlocker_instance.contract_address 
        }.version() == '2.0.3', 
        'TTUnlocker version check'
    );
    assert(
        IVersionableDispatcher { 
            contract_address: futuretoken_instance.contract_address 
        }.version() == '2.0.1', 
        'TTFutureToken version check'
    );
    assert(
        unlocker_instance.get_futuretoken().unwrap() == 
        futuretoken_instance.contract_address,
        'TTFutureToken wrong in unlocker'
    );
    // Should fail duplicate project ID
    match deployer_instance.deploy_ttsuite(
        mockerc20_instance.contract_address,
        project_id,
        true
    ) {
        Result::Ok(_) => panic_with_felt252(
            'Should panic'
        ),
        Result::Err(data) => {
            assert(*data.at(0) == TTDeployerErrors::ALREADY_DEPLOYED, '');
        }
    }
    // Should fail if classhash of unlocker and ft are empty
    deployer_instance.set_class_hash(
        0.try_into().unwrap(), 
        0.try_into().unwrap()
    );
    match deployer_instance.deploy_ttsuite(
        mockerc20_instance.contract_address,
        project_id + '1',
        true
    ) {
        Result::Ok(_) => panic_with_felt252(
            'Should panic'
        ),
        Result::Err(data) => {
            assert(*data.at(0) == TTDeployerErrors::EMPTY_CLASSHASH, '');
        }
    }
}

#[test]
// #[ignore]
fn unlocker_create_preset_test() {
    let deployer_instance = deploy_deployer();
    let (unlocker_instance, _, _, _) =
        deploy_ttsuite(deployer_instance, 'test project', true);
    let (
        preset_id, 
        linear_start_timestamps_relative, 
        linear_end_timestamp_relative, 
        linear_bips, 
        num_of_unlocks_for_each_linear
    ) = get_test_preset_params_0();
    unlocker_instance.create_preset(
        preset_id,
        linear_start_timestamps_relative,
        linear_end_timestamp_relative,
        linear_bips,
        num_of_unlocks_for_each_linear
    ).unwrap();
    let contract_preset = unlocker_instance.get_preset(preset_id).unwrap();
    let local_preset = Preset {
        linear_start_timestamps_relative, 
        linear_end_timestamp_relative, 
        linear_bips, 
        num_of_unlocks_for_each_linear
    };
    assert(
        contract_preset == local_preset,
        'Preset mismatch'
    );
    // Should panic if caller is not owner
    // Fake address to 123
    start_prank(CheatTarget::All, 123.try_into().unwrap());
    let preset_id_2 = 'test id 2';
    match unlocker_instance.create_preset(
        preset_id_2,
        linear_start_timestamps_relative,
        linear_end_timestamp_relative,
        linear_bips,
        num_of_unlocks_for_each_linear
    ) {
        Result::Ok(_) => panic_with_felt252(
            'Should panic'
        ),
        Result::Err(data) => {
            assert(
                *data.at(0) == Errors::NOT_OWNER, 
                *data.at(0)
            );
        }
    }
    stop_prank(CheatTarget::All);
    // Should panic if linear_bips don't add up to BIPS_PRECISION
    match unlocker_instance.create_preset(
        preset_id_2,
        linear_start_timestamps_relative,
        linear_end_timestamp_relative,
        array![0, 1000, 0, 2000, 0, 4000, 3001].span(),
        num_of_unlocks_for_each_linear
    ) {
        Result::Ok(_) => panic_with_felt252(
            'Should panic'
        ),
        Result::Err(data) => {
            assert(
                *data.at(0) == TTUnlockerErrors::INVALID_PRESET_FORMAT, 
                *data.at(0)
            );
        }
    }
    // Should panic if input span lengths are inconsistent
    match unlocker_instance.create_preset(
        preset_id_2,
        linear_start_timestamps_relative,
        linear_end_timestamp_relative,
        linear_bips,
        array![1, 1, 1, 1, 4, 3].span()
    ) {
        Result::Ok(_) => panic_with_felt252(
            'Should panic'
        ),
        Result::Err(data) => {
            assert(
                *data.at(0) == TTUnlockerErrors::INVALID_PRESET_FORMAT, 
                *data.at(0)
            );
        }
    }
    // Should panic if the final start timestamp is the same as end timestamp
    match unlocker_instance.create_preset(
        preset_id_2,
        linear_start_timestamps_relative,
        100,
        linear_bips,
        num_of_unlocks_for_each_linear
    ) {
        Result::Ok(_) => panic_with_felt252(
            'Should panic'
        ),
        Result::Err(data) => {
            assert(
                *data.at(0) == TTUnlockerErrors::INVALID_PRESET_FORMAT, 
                *data.at(0)
            );
        }
    }
    // Should panic if preset ID already exists
    match unlocker_instance.create_preset(
        preset_id,
        linear_start_timestamps_relative,
        linear_end_timestamp_relative,
        linear_bips,
        num_of_unlocks_for_each_linear
    ) {
        Result::Ok(_) => panic_with_felt252(
            'Should panic'
        ),
        Result::Err(data) => {
            assert(
                *data.at(0) == TTUnlockerErrors::PRESET_EXISTS, 
                *data.at(0)
            );
        }
    }
}

#[test]
// #[ignore]
fn unlocker_create_actual_test() {
    // Creating preset
    let deployer_instance = deploy_deployer();
    let (unlocker_instance, _, mockerc20_instance, _) =
        deploy_ttsuite(deployer_instance, 'test project', true);
    let (
        preset_id, 
        linear_start_timestamps_relative, 
        linear_end_timestamp_relative, 
        linear_bips, 
        num_of_unlocks_for_each_linear
    ) = get_test_preset_params_0();
    unlocker_instance.create_preset(
        preset_id,
        linear_start_timestamps_relative,
        linear_end_timestamp_relative,
        linear_bips,
        num_of_unlocks_for_each_linear
    ).unwrap();
    // Creating actual
    let (amount_skipped, amount_deposited, total_amount) = 
        get_test_actual_params_no_skip();
    let start_timestamp_absolute = get_block_timestamp();
    let recipient = test_address();
    // Should work, not depositing
    unlocker_instance.create_actual(
        recipient,
        preset_id,
        start_timestamp_absolute,
        amount_skipped,
        total_amount,
        amount_deposited,
        0
    ).unwrap();
    // Should panic if caller is not owner
    start_prank(CheatTarget::All, 123.try_into().unwrap());
    match unlocker_instance.create_actual(
        recipient,
        preset_id,
        start_timestamp_absolute,
        amount_skipped,
        total_amount,
        amount_deposited,
        0
    ) {
        Result::Ok(_) => panic_with_felt252(
            'Should panic'
        ),
        Result::Err(data) => {
            assert(
                *data.at(0) == Errors::NOT_OWNER, 
                *data.at(0)
            );
        }
    }
    stop_prank(CheatTarget::All);
    // Should panic if preset ID doesn't exist
    match unlocker_instance.create_actual(
        recipient,
        preset_id + '1',
        start_timestamp_absolute,
        amount_skipped,
        total_amount,
        amount_deposited,
        0
    ) {
        Result::Ok(_) => panic_with_felt252(
            'Should panic'
        ),
        Result::Err(data) => {
            assert(
                *data.at(0) == TTUnlockerErrors::PRESET_DOES_NOT_EXIST, 
                *data.at(0)
            );
        }
    }
    // Should panic if skip amount is equal to total amount
    match unlocker_instance.create_actual(
        recipient,
        preset_id,
        start_timestamp_absolute,
        total_amount,
        total_amount,
        amount_deposited,
        0
    ) {
        Result::Ok(_) => panic_with_felt252(
            'Should panic'
        ),
        Result::Err(data) => {
            assert(
                *data.at(0) == TTUnlockerErrors::INVALID_SKIP_AMOUNT, 
                *data.at(0)
            );
        }
    }
    // Should panic if skip amount is greater than total amount
    match unlocker_instance.create_actual(
        recipient,
        preset_id,
        start_timestamp_absolute,
        total_amount + 1,
        total_amount,
        amount_deposited,
        0
    ) {
        Result::Ok(_) => panic_with_felt252(
            'Should panic'
        ),
        Result::Err(data) => {
            assert(
                *data.at(0) == TTUnlockerErrors::INVALID_SKIP_AMOUNT, 
                *data.at(0)
            );
        }
    }
    // Should panic if ERC20 approval < amount depositing now
    match unlocker_instance.create_actual(
        recipient,
        preset_id,
        start_timestamp_absolute,
        amount_skipped,
        total_amount,
        total_amount,
        0
    ) {
        Result::Ok(_) => panic_with_felt252(
            'Should panic'
        ),
        Result::Err(data) => {
            assert(
                *data.at(0) == 'u256_sub Overflow',
                *data.at(0)
            );
        }
    }
    // Should work, depositing total amount
    IMockERC20Dispatcher {
        contract_address: mockerc20_instance.contract_address
    }.mint(test_address(), total_amount);
    mockerc20_instance.approve(
        unlocker_instance.contract_address, 
        total_amount
    );
    let actual_id = unlocker_instance.create_actual(
        recipient,
        preset_id,
        start_timestamp_absolute,
        amount_skipped,
        total_amount,
        total_amount,
        0
    ).unwrap();
    // Check storage
    let contract_actual = unlocker_instance.get_actual(actual_id).unwrap();
    let local_actual = Actual {
        preset_id,
        start_timestamp_absolute,
        amount_claimed: amount_skipped,
        total_amount,
    };
    let contract_pool = unlocker_instance.get_pool().unwrap();
    assert(
        contract_actual == local_actual &&
        contract_pool == total_amount,
        'Should match'
    );
}

#[test]
// #[ignore]
fn unlocker_deposit_test() {
    // Creating preset and actual with 0 deposit
    let deployer_instance = deploy_deployer();
    let (unlocker_instance, _, mockerc20_instance, _) =
        deploy_ttsuite(deployer_instance, 'test project', true);
    let (
        preset_id, 
        linear_start_timestamps_relative, 
        linear_end_timestamp_relative, 
        linear_bips, 
        num_of_unlocks_for_each_linear
    ) = get_test_preset_params_0();
    unlocker_instance.create_preset(
        preset_id,
        linear_start_timestamps_relative,
        linear_end_timestamp_relative,
        linear_bips,
        num_of_unlocks_for_each_linear
    ).unwrap();
    let (amount_skipped, amount_deposited, total_amount) = 
        get_test_actual_params_no_skip();
    let start_timestamp_absolute = get_block_timestamp();
    let recipient = test_address();
    let actual_id = unlocker_instance.create_actual(
        recipient,
        preset_id,
        start_timestamp_absolute,
        amount_skipped,
        total_amount,
        amount_deposited,
        0
    ).unwrap();
    // Should panic if ERC20 approval is insufficient
    match unlocker_instance.deposit(total_amount) {
        Result::Ok(_) => panic_with_felt252(
            'Should panic'
        ),
        Result::Err(data) => {
            assert(
                *data.at(0) == 'u256_sub Overflow', 
                *data.at(0)
            );
        }
    }
    // Should panic if caller is not the owner
    IMockERC20Dispatcher {
        contract_address: mockerc20_instance.contract_address
    }.mint(test_address(), total_amount);
    mockerc20_instance.approve(
        unlocker_instance.contract_address, 
        total_amount
    );
    start_prank(CheatTarget::All, 123.try_into().unwrap());
    match unlocker_instance.deposit(total_amount) {
        Result::Ok(_) => panic_with_felt252(
            'Should panic'
        ),
        Result::Err(data) => {
            assert(
                *data.at(0) == Errors::NOT_OWNER, 
                *data.at(0)
            );
        }
    }
    stop_prank(CheatTarget::All);
    // Should work
    unlocker_instance.deposit(total_amount).unwrap();
    // Check storage
    let contract_pool = unlocker_instance.get_pool().unwrap();
    assert(
        contract_pool == total_amount,
        'Should match'
    );
}

#[test]
// #[ignore]
fn unlocker_withdraw_test() {
    // Creating preset and actual with all deposit
    let deployer_instance = deploy_deployer();
    let (unlocker_instance, _, mockerc20_instance, _) =
        deploy_ttsuite(deployer_instance, 'test project', true);
    let (
        preset_id, 
        linear_start_timestamps_relative, 
        linear_end_timestamp_relative, 
        linear_bips, 
        num_of_unlocks_for_each_linear
    ) = get_test_preset_params_0();
    unlocker_instance.create_preset(
        preset_id,
        linear_start_timestamps_relative,
        linear_end_timestamp_relative,
        linear_bips,
        num_of_unlocks_for_each_linear
    ).unwrap();
    let (amount_skipped, amount_deposited, total_amount) = 
        get_test_actual_params_no_skip();
    let start_timestamp_absolute = get_block_timestamp();
    let recipient = test_address();
    IMockERC20Dispatcher {
        contract_address: mockerc20_instance.contract_address
    }.mint(test_address(), total_amount);
    mockerc20_instance.approve(
        unlocker_instance.contract_address, 
        total_amount
    );
    let actual_id = unlocker_instance.create_actual(
        recipient,
        preset_id,
        start_timestamp_absolute,
        amount_skipped,
        total_amount,
        total_amount,
        0
    ).unwrap();
    // Should panic if caller is not owner
    start_prank(CheatTarget::All, 123.try_into().unwrap());
    match unlocker_instance.withdraw_deposit(total_amount) {
        Result::Ok(_) => panic_with_felt252(
            'Should panic'
        ),
        Result::Err(data) => {
            assert(
                *data.at(0) == Errors::NOT_OWNER, 
                *data.at(0)
            );
        }
    }
    stop_prank(CheatTarget::All);
    // Should panic if withdraw amount exceeds available funds
    match unlocker_instance.withdraw_deposit(total_amount + 1) {
        Result::Ok(_) => panic_with_felt252(
            'Should panic'
        ),
        Result::Err(data) => {
            assert(
                *data.at(0) == 'u256_sub Overflow', 
                *data.at(0)
            );
        }
    }
    // Should work
    let balance_before = mockerc20_instance.balance_of(test_address());
    unlocker_instance.withdraw_deposit(total_amount).unwrap();
    // Check storage & balance
    assert(
        unlocker_instance.get_pool().unwrap().is_zero(), 
        'Pool in storage not zero'
    );
    let balance_after = mockerc20_instance.balance_of(test_address());
    assert(
        balance_after - balance_before == total_amount,
        'Balance mismatch'
    );
}

#[test]
// #[ignore]
fn unlocker_claimable_calculation_unit_test() {
    let deployer_instance = deploy_deployer();
    let (unlocker_instance, _, mockerc20_instance, _) =
        deploy_ttsuite(deployer_instance, 'test project', true);

    let preset_linear_end_timestamp_relative = 126240000;
    let preset_linear_start_timestamps_relative = array![0, 126240000].span();
    let preset_linear_bips = array![10000, 0].span();
    let preset_bips_precision = 10000;
    let preset_num_of_unlocks_for_each_linear = array![48, 1].span();
    let actual_total_amount = 566666;
    let actual_start_timestamp_absolute = 0;
    let mut claim_timestamp_absolute = 2630000;
    let mut result = 
        unlocker_instance.calculate_amount_of_tokens_to_claim_at_timestamp(
            actual_start_timestamp_absolute,
            preset_linear_end_timestamp_relative,
            preset_linear_start_timestamps_relative,
            claim_timestamp_absolute,
            preset_linear_bips,
            preset_num_of_unlocks_for_each_linear,
            preset_bips_precision,
            actual_total_amount
        ).unwrap();
    assert(
        result == 11805, 'Mismatch with TS logic'
    );
    claim_timestamp_absolute = 12312312;
    result = 
        unlocker_instance.calculate_amount_of_tokens_to_claim_at_timestamp(
            actual_start_timestamp_absolute,
            preset_linear_end_timestamp_relative,
            preset_linear_start_timestamps_relative,
            claim_timestamp_absolute,
            preset_linear_bips,
            preset_num_of_unlocks_for_each_linear,
            preset_bips_precision,
            actual_total_amount
        ).unwrap();
    assert(
        result == 47222, 'Mismatch with TS logic'
    );
    claim_timestamp_absolute = 426240000;
    result = 
        unlocker_instance.calculate_amount_of_tokens_to_claim_at_timestamp(
            actual_start_timestamp_absolute,
            preset_linear_end_timestamp_relative,
            preset_linear_start_timestamps_relative,
            claim_timestamp_absolute,
            preset_linear_bips,
            preset_num_of_unlocks_for_each_linear,
            preset_bips_precision,
            actual_total_amount
        ).unwrap();
    assert(
        result == 566666, 'Mismatch with TS logic'
    );
    claim_timestamp_absolute = 76240000;
    result = 
        unlocker_instance.calculate_amount_of_tokens_to_claim_at_timestamp(
            actual_start_timestamp_absolute,
            preset_linear_end_timestamp_relative,
            preset_linear_start_timestamps_relative,
            claim_timestamp_absolute,
            preset_linear_bips,
            preset_num_of_unlocks_for_each_linear,
            preset_bips_precision,
            actual_total_amount
        ).unwrap();
    assert(
        result == 330555, 'Mismatch with TS logic'
    );
    claim_timestamp_absolute = 2629999;
    result = 
        unlocker_instance.calculate_amount_of_tokens_to_claim_at_timestamp(
            actual_start_timestamp_absolute,
            preset_linear_end_timestamp_relative,
            preset_linear_start_timestamps_relative,
            claim_timestamp_absolute,
            preset_linear_bips,
            preset_num_of_unlocks_for_each_linear,
            preset_bips_precision,
            actual_total_amount
        ).unwrap();
    assert(
        result == 0, 'Mismatch with TS logic'
    );
}

#[test]
// #[ignore]
fn unlocker_claim_test() {
    // Creating preset and actual with full deposit
    let deployer_instance = deploy_deployer();
    let (unlocker_instance, _, mockerc20_instance, _) =
        deploy_ttsuite(deployer_instance, 'test project', true);
    let (
        preset_id, 
        linear_start_timestamps_relative, 
        linear_end_timestamp_relative, 
        linear_bips, 
        num_of_unlocks_for_each_linear
    ) = get_test_preset_params_0();
    unlocker_instance.create_preset(
        preset_id,
        linear_start_timestamps_relative,
        linear_end_timestamp_relative,
        linear_bips,
        num_of_unlocks_for_each_linear
    ).unwrap();
    let (amount_skipped, amount_deposited, total_amount) = 
        get_test_actual_params_no_skip();
    let start_timestamp_absolute = get_block_timestamp();
    let recipient = test_address();
    IMockERC20Dispatcher {
        contract_address: mockerc20_instance.contract_address
    }.mint(test_address(), total_amount);
    mockerc20_instance.approve(
        unlocker_instance.contract_address, 
        total_amount
    );
    start_warp(CheatTarget::All, 0);
    let actual_id = unlocker_instance.create_actual(
        recipient,
        preset_id,
        start_timestamp_absolute,
        amount_skipped,
        total_amount,
        total_amount,
        0
    ).unwrap();
    // Testing calculation
    start_warp(CheatTarget::All, 10);
    let (mut delta_claimable_amount, _) = 
        unlocker_instance.calculate_amount_claimable(actual_id).unwrap();
    assert(
        delta_claimable_amount == 0,
        delta_claimable_amount.try_into().unwrap()
    );
    start_warp(CheatTarget::All, 11);
    let (mut delta_claimable_amount, _) = 
        unlocker_instance.calculate_amount_claimable(actual_id).unwrap();
    assert(
        delta_claimable_amount == 1000,
        delta_claimable_amount.try_into().unwrap()
    );
    start_warp(CheatTarget::All, 30);
    let (mut delta_claimable_amount, _) = 
        unlocker_instance.calculate_amount_claimable(actual_id).unwrap();
    assert(
        delta_claimable_amount == 1000,
        delta_claimable_amount.try_into().unwrap()
    );
    start_warp(CheatTarget::All, 31);
    let (mut delta_claimable_amount, _) = 
        unlocker_instance.calculate_amount_claimable(actual_id).unwrap();
    assert(
        delta_claimable_amount == 3000,
        delta_claimable_amount.try_into().unwrap()
    );
    start_warp(CheatTarget::All, 59);
    let (mut delta_claimable_amount, _) = 
        unlocker_instance.calculate_amount_claimable(actual_id).unwrap();
    assert(
        delta_claimable_amount == 3000,
        delta_claimable_amount.try_into().unwrap()
    );
    start_warp(CheatTarget::All, 70);
    let (mut delta_claimable_amount, _) = 
        unlocker_instance.calculate_amount_claimable(actual_id).unwrap();
    assert(
        delta_claimable_amount == 4000,
        delta_claimable_amount.try_into().unwrap()
    );
    start_warp(CheatTarget::All, 200);
    let (mut delta_claimable_amount, _) = 
        unlocker_instance.calculate_amount_claimable(actual_id).unwrap();
    assert(
        delta_claimable_amount == 8000,
        delta_claimable_amount.try_into().unwrap()
    );
    start_warp(CheatTarget::All, 399);
    let (mut delta_claimable_amount, _) = 
        unlocker_instance.calculate_amount_claimable(actual_id).unwrap();
    assert(
        delta_claimable_amount == 9000,
        delta_claimable_amount.try_into().unwrap()
    );
    start_warp(CheatTarget::All, 400);
    let (mut delta_claimable_amount, _) = 
        unlocker_instance.calculate_amount_claimable(actual_id).unwrap();
    assert(
        delta_claimable_amount == 10000,
        delta_claimable_amount.try_into().unwrap()
    );
    start_warp(CheatTarget::All, 1000);
    let (mut delta_claimable_amount, _) = 
        unlocker_instance.calculate_amount_claimable(actual_id).unwrap();
    assert(
        delta_claimable_amount == 10000,
        delta_claimable_amount.try_into().unwrap()
    );
    // Claiming to recipient address
    let balance_before = mockerc20_instance.balance_of(test_address());
    unlocker_instance.claim(actual_id, Zeroable::zero()).unwrap();
    let balance_after = mockerc20_instance.balance_of(test_address());
    assert(
        balance_after - balance_before == total_amount,
        'Balance mismatch'
    );
    let amount_claimed_after = 
        unlocker_instance.get_actual(actual_id).unwrap().amount_claimed;
    assert(
        amount_claimed_after == total_amount,
        'Amount claimed mismatch'
    );
    let (delta_claimable_amount, updated_amount_claimed) = 
        unlocker_instance.calculate_amount_claimable(actual_id).unwrap();
    assert(
        delta_claimable_amount == 0,
        delta_claimable_amount.try_into().unwrap()
    );
    assert(
        updated_amount_claimed == total_amount,
        updated_amount_claimed.try_into().unwrap()
    );
    stop_warp(CheatTarget::All);
    // TODO: Claiming to override recipient
}

#[test]
// #[ignore]
fn unlocker_cancel_test() {
    // Creating preset and actual with no deposit
    let deployer_instance = deploy_deployer();
    let (unlocker_instance, _, mockerc20_instance, _) =
        deploy_ttsuite(deployer_instance, 'test project', true);
    let (
        preset_id, 
        linear_start_timestamps_relative, 
        linear_end_timestamp_relative, 
        linear_bips, 
        num_of_unlocks_for_each_linear
    ) = get_test_preset_params_0();
    unlocker_instance.create_preset(
        preset_id,
        linear_start_timestamps_relative,
        linear_end_timestamp_relative,
        linear_bips,
        num_of_unlocks_for_each_linear
    ).unwrap();
    let (amount_skipped, amount_deposited, total_amount) = 
        get_test_actual_params_no_skip();
    start_warp(CheatTarget::All, 0);
    let start_timestamp_absolute = get_block_timestamp();
    let recipient = test_address();
    let actual_id = unlocker_instance.create_actual(
        recipient,
        preset_id,
        start_timestamp_absolute,
        amount_skipped,
        total_amount,
        amount_deposited,
        0
    ).unwrap();
    // Cancelling, should work, but claim should fail (insufficient deposit)
    start_warp(CheatTarget::All, 11);
    unlocker_instance.cancel(actual_id).unwrap();
    match unlocker_instance.claim(actual_id, Zeroable::zero()) {
        Result::Ok(_) => panic_with_felt252(
            'Should panic'
        ),
        Result::Err(data) => {
            assert(
                *data.at(0) == 'u256_sub Overflow',
                *data.at(0)
            );
        }
    }
    // Over-depositing (total amount)
    IMockERC20Dispatcher {
        contract_address: mockerc20_instance.contract_address
    }.mint(test_address(), total_amount);
    mockerc20_instance.approve(
        unlocker_instance.contract_address, 
        total_amount
    );
    unlocker_instance.deposit(total_amount).unwrap();
    let mut balance = mockerc20_instance.balance_of(
        unlocker_instance.contract_address
    );
    // Balance should be the over-deposit
    assert(
        balance == total_amount,
        'Balance mismatch'
    );
    // Claiming should work
    unlocker_instance.claim(
        actual_id, 
        Zeroable::zero()
    ).unwrap();
    balance = mockerc20_instance.balance_of(test_address());
    assert(
        balance == 1000,
        balance.try_into().unwrap()
    );
}

#[test]
// #[ignore]
fn unlocker_cancelable_test() {
    // Creating preset and actual with full deposit
    let deployer_instance = deploy_deployer();
    let (unlocker_instance, _, mockerc20_instance, _) =
        deploy_ttsuite(deployer_instance, 'test project', true);
    let (
        preset_id, 
        linear_start_timestamps_relative, 
        linear_end_timestamp_relative, 
        linear_bips, 
        num_of_unlocks_for_each_linear
    ) = get_test_preset_params_0();
    unlocker_instance.create_preset(
        preset_id,
        linear_start_timestamps_relative,
        linear_end_timestamp_relative,
        linear_bips,
        num_of_unlocks_for_each_linear
    ).unwrap();
    let (amount_skipped, amount_deposited, total_amount) = 
        get_test_actual_params_no_skip();
    let start_timestamp_absolute = get_block_timestamp();
    let recipient = test_address();
    IMockERC20Dispatcher {
        contract_address: mockerc20_instance.contract_address
    }.mint(test_address(), total_amount);
    mockerc20_instance.approve(
        unlocker_instance.contract_address, 
        total_amount
    );
    start_warp(CheatTarget::All, 0);
    let actual_id = unlocker_instance.create_actual(
        recipient,
        preset_id,
        start_timestamp_absolute,
        amount_skipped,
        total_amount,
        total_amount,
        0
    ).unwrap();
    // Should panic if try to disable cancel while not being the owner
    start_prank(CheatTarget::All, 123.try_into().unwrap());
    match unlocker_instance.disable_cancel() {
        Result::Ok(_) => panic_with_felt252(
            'Should panic'
        ),
        Result::Err(data) => {
            assert(
                *data.at(0) == Errors::NOT_OWNER, 
                *data.at(0)
            );
        }
    }
    stop_prank(CheatTarget::All);
    // Should not panic if call as owner
    unlocker_instance.disable_cancel();
    // Cancel should now fail
    match unlocker_instance.cancel(actual_id) {
        Result::Ok(_) => panic_with_felt252(
            'Should panic'
        ),
        Result::Err(data) => {
            assert(
                *data.at(0) == TTUnlockerErrors::UNAUTHORIZED, 
                *data.at(0)
            );
        }
    }
}