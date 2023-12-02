use core::result::ResultTrait;
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

#[test]
fn deployer_test() {
    let deployer = deploy_deployer();
    let mockerc20 = deploy_mockerc20();
    let project_id = 'test project';
    let allow_transferable = true;
    let (unlocker_address, futuretoken_address) = deployer.deploy_ttsuite(
        mockerc20.contract_address,
        project_id,
        allow_transferable,
    );
    assert(
        IVersionableDispatcher {
            contract_address: unlocker_address
        }.version() == '2.0.3', 
        'Unlocker version check'
    );
    assert(
        IVersionableDispatcher {
            contract_address: futuretoken_address
        }.version() == '2.0.1', 
        'FutureToken version check'
    );
}