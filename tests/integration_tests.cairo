use debug::PrintTrait;
use snforge_std::{
    declare, 
    ContractClassTrait,
    test_address,
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
                IUnlockerDispatcher,
                IUnlockerDispatcherTrait,
            },
            futuretoken::{
                IFutureTokenDispatcher,
                IFutureTokenDispatcherTrait,
            },
            deployer::{
                IDeployerDispatcher,
                IDeployerDispatcherTrait,
            },
            feecollector::{
                IFeeCollectorDispatcher,
                IFeeCollectorDispatcherTrait,
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
use openzeppelin::token::erc20::interface::{
    IERC20Dispatcher,
    IERC20DispatcherTrait,
};

fn deploy_deployer() -> IDeployerDispatcher {
    let deployer_class = declare('Deployer');
    let deployer_contract_address = 
        deployer_class.deploy(@ArrayTrait::new()).unwrap();
    let deployer = IDeployerDispatcher { 
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
    deployer: IDeployerDispatcher,
    project_id: felt252,
    allow_transferable_ft: bool
) -> (
    IUnlockerDispatcher, 
    IFutureTokenDispatcher, 
    IERC20Dispatcher, 
    felt252
) {
    let mockerc20 = deploy_mockerc20();
    let (unlocker_address, futuretoken_address) = deployer.deploy_ttsuite(
        mockerc20.contract_address,
        project_id,
        allow_transferable_ft,
    );
    let unlocker_instance = IUnlockerDispatcher {
        contract_address: unlocker_address
    };
    let futuretoken_instance = IFutureTokenDispatcher {
        contract_address: futuretoken_address
    };
    (unlocker_instance, futuretoken_instance, mockerc20, project_id)
}

fn get_test_preset_params() 
    -> (felt252, Span<u64>, u64, Span<u64>, Span<u64>) {
    (
        'test preset', 
        array![0, 10, 11, 30, 31, 60, 100].span(),
        400,
        array![0, 1000, 0, 2000, 0, 4000, 3000].span(),
        array![1, 1, 1, 1, 1, 4, 3].span()
    )
}

#[test]
fn deployer_test() {
    let deployer_instance = deploy_deployer();
    let (unlocker_instance, futuretoken_instance, _, project_id) =
        deploy_ttsuite(deployer_instance, 'test project', true);
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
}

#[test]
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
    ) = get_test_preset_params();
    unlocker_instance.create_preset(
        preset_id,
        linear_start_timestamps_relative,
        linear_end_timestamp_relative,
        linear_bips,
        num_of_unlocks_for_each_linear
    );
    let contract_preset = unlocker_instance.get_preset(preset_id);
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
}