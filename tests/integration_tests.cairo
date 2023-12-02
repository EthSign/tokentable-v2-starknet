use core::result::ResultTrait;
use core::traits::TryInto;
use debug::PrintTrait;
use snforge_std::{
    declare, 
    ContractClassTrait,
    test_address,
    start_prank,
    stop_prank,
    CheatTarget,
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
                IUnlockerSafeDispatcher,
                IUnlockerSafeDispatcherTrait,
                UnlockerErrors,
            },
            futuretoken::{
                IFutureTokenSafeDispatcher,
                IFutureTokenSafeDispatcherTrait,
            },
            deployer::{
                IDeployerSafeDispatcher,
                IDeployerSafeDispatcherTrait,
                DeployerErrors,
            },
            feecollector::{
                IFeeCollectorSafeDispatcher,
                IFeeCollectorSafeDispatcherTrait,
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
    access::ownable::OwnableComponent::Errors,
    token::erc20::interface::{
        IERC20Dispatcher,
        IERC20DispatcherTrait
    },
};

fn deploy_deployer() -> IDeployerSafeDispatcher {
    let deployer_class = declare('Deployer');
    let deployer_contract_address = 
        deployer_class.deploy(@ArrayTrait::new()).unwrap();
    let deployer = IDeployerSafeDispatcher { 
        contract_address: deployer_contract_address 
    };
    let unlocker_class = declare('Unlocker');
    let futuretoken_class = declare('FutureToken');
    deployer.set_class_hash(
        unlocker_class.class_hash, 
        futuretoken_class.class_hash
    );
    let feecollector_class = declare('FeeCollector');
    let feecollector_contract_address = 
        feecollector_class.deploy(@ArrayTrait::new()).unwrap();
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
    deployer: IDeployerSafeDispatcher,
    project_id: felt252,
    allow_transferable_ft: bool
) -> (
    IUnlockerSafeDispatcher, 
    IFutureTokenSafeDispatcher, 
    IERC20Dispatcher, 
    felt252
) {
    let mockerc20 = deploy_mockerc20();
    let (unlocker_address, futuretoken_address) = deployer.deploy_ttsuite(
        mockerc20.contract_address,
        project_id,
        allow_transferable_ft,
    ).unwrap();
    let unlocker_instance = IUnlockerSafeDispatcher {
        contract_address: unlocker_address
    };
    let futuretoken_instance = IFutureTokenSafeDispatcher {
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
    (0, 0, 566666)
}

fn get_test_actual_params_skip() -> (u256, u256, u256) {
    (100000, 0, 566666)
}

#[test]
#[ignore]
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
        'Unlocker version check'
    );
    assert(
        IVersionableDispatcher { 
            contract_address: futuretoken_instance.contract_address 
        }.version() == '2.0.1', 
        'FutureToken version check'
    );
    assert(
        unlocker_instance.get_futuretoken().unwrap() == 
        futuretoken_instance.contract_address,
        'FutureToken wrong in unlocker'
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
            assert(*data.at(0) == DeployerErrors::ALREADY_DEPLOYED, '');
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
            assert(*data.at(0) == DeployerErrors::EMPTY_CLASSHASH, '');
        }
    }
}

#[test]
#[ignore]
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
                *data.at(0) == UnlockerErrors::INVALID_PRESET_FORMAT, 
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
                *data.at(0) == UnlockerErrors::INVALID_PRESET_FORMAT, 
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
                *data.at(0) == UnlockerErrors::INVALID_PRESET_FORMAT, 
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
                *data.at(0) == UnlockerErrors::PRESET_EXISTS, 
                *data.at(0)
            );
        }
    }
}

#[test]
#[ignore]
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
        amount_deposited
    ).unwrap();
    // Should panic if preset ID doesn't exist
    match unlocker_instance.create_actual(
        recipient,
        preset_id + '1',
        start_timestamp_absolute,
        amount_skipped,
        total_amount,
        amount_deposited
    ) {
        Result::Ok(_) => panic_with_felt252(
            'Should panic'
        ),
        Result::Err(data) => {
            assert(
                *data.at(0) == UnlockerErrors::PRESET_DOES_NOT_EXIST, 
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
        amount_deposited
    ) {
        Result::Ok(_) => panic_with_felt252(
            'Should panic'
        ),
        Result::Err(data) => {
            assert(
                *data.at(0) == UnlockerErrors::INVALID_SKIP_AMOUNT, 
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
        amount_deposited
    ) {
        Result::Ok(_) => panic_with_felt252(
            'Should panic'
        ),
        Result::Err(data) => {
            assert(
                *data.at(0) == UnlockerErrors::INVALID_SKIP_AMOUNT, 
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
        total_amount
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
        total_amount
    ).unwrap();
    // Check storage
    let contract_actual = unlocker_instance.get_actual(actual_id).unwrap();
    let local_actual = Actual {
        preset_id,
        start_timestamp_absolute,
        amount_claimed: amount_skipped,
        total_amount,
        amount_deposited: total_amount
    };
    assert(
        contract_actual == local_actual,
        'Should match'
    );
}