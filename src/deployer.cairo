#[starknet::contract]
mod Deployer {
    use starknet::{
        ContractAddress,
        get_caller_address,
        get_contract_address,
        class_hash::ClassHash,
        syscalls::deploy_syscall,
    };
    use openzeppelin::{
        access::ownable::{
            OwnableComponent,
            interface::{
                IOwnableDispatcher,
                IOwnableDispatcherTrait
            }
        },
    };
    use tokentable_v2::components::{
        structs::ttsuite::TTSuite,
        interfaces::{
            versionable::IVersionable,
            deployer::{
                IDeployer,
                DeployerEvents,
                DeployerErrors
            },
            futuretoken::{
                IFutureTokenDispatcher,
                IFutureTokenDispatcherTrait
            }
        },
    };

    component!(
        path: OwnableComponent, 
        storage: ownable, 
        event: OwnableEvent
    );

    // Ownable
    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    #[abi(embed_v0)]
    impl OwnableCamelOnlyImpl =
        OwnableComponent::OwnableCamelOnlyImpl<ContractState>;
    impl InternalOwnableImpl = OwnableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        registry: LegacyMap<felt252, TTSuite>,
        unlocker_classhash: ClassHash,
        futuretoken_classhash: ClassHash,
        fee_collector_instance: ContractAddress,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        TokenTableSuiteDeployed: DeployerEvents::TokenTableSuiteDeployed,
        ClassHashChanged: DeployerEvents::ClassHashChanged,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
    ) {
        self.ownable.initializer(get_caller_address());
    }

    #[abi(embed_v0)]
    impl Versionable of IVersionable<ContractState> {
        fn version(self: @ContractState) -> felt252 {
            '2.0.2'
        }
    }

    #[abi(embed_v0)]
    impl DeployerImpl of IDeployer<ContractState> {
        fn deploy_ttsuite(
            ref self: ContractState,
            project_token: ContractAddress,
            project_id: felt252,
            allow_transferable_ft: bool
        ) -> (ContractAddress, ContractAddress) {
            assert(
                self.unlocker_classhash.read().is_non_zero() &&
                self.futuretoken_classhash.read().is_non_zero(),
                DeployerErrors::EMPTY_CLASSHASH
            );
            let current_ttsuite = self.registry.read(project_id);
            assert(
                current_ttsuite.unlocker_instance.is_zero(),
                DeployerErrors::ALREADY_DEPLOYED
            );
            let futuretoken_constructor_calldata: Array::<felt252> =
                array![project_token.into(), allow_transferable_ft.into()];
            let (futuretoken_instance, _) = deploy_syscall(
                self.futuretoken_classhash.read(), 
                project_id, 
                futuretoken_constructor_calldata.span(), 
                false
            ).unwrap();
            let unlocker_constructor_calldata: Array::<felt252> = 
                array![
                    project_token.into(), 
                    futuretoken_instance.into(), 
                    get_contract_address().into()
                ];
            let (unlocker_instance, _) = deploy_syscall(
                self.unlocker_classhash.read(), 
                project_id,
                unlocker_constructor_calldata.span(), 
                false
            ).unwrap();
            IFutureTokenDispatcher {
                contract_address: futuretoken_instance
            }.set_authorized_minter_single_use(unlocker_instance);
            IOwnableDispatcher {
                contract_address: unlocker_instance
            }.transfer_ownership(get_caller_address());
            self.emit(
                Event::TokenTableSuiteDeployed(
                    DeployerEvents::TokenTableSuiteDeployed {
                        by: get_caller_address(),
                        project_id,
                        project_token,
                        unlocker_instance,
                        futuretoken_instance
                    }
                )
            );
            let new_ttsuite = TTSuite {
                unlocker_instance,
                futuretoken_instance
            };
            self.registry.write(project_id, new_ttsuite);
            (unlocker_instance, futuretoken_instance)
        }

        fn set_class_hash(
            ref self: ContractState,
            unlocker_classhash: ClassHash,
            futuretoken_classhash: ClassHash,
        ) {
            self.unlocker_classhash.write(unlocker_classhash);
            self.futuretoken_classhash.write(futuretoken_classhash);
            self.emit(
                Event::ClassHashChanged(
                    DeployerEvents::ClassHashChanged {
                        unlocker_classhash,
                        futuretoken_classhash,
                    }
                )
            );
        }

        fn set_fee_collector(
            ref self: ContractState,
            fee_collector: ContractAddress
        ) {
            self.fee_collector_instance.write(fee_collector);
        }

        fn get_class_hash(
            self: @ContractState
        ) -> (ClassHash, ClassHash) {
            (self.unlocker_classhash.read(),
            self.futuretoken_classhash.read())
        }

        fn get_fee_collector(
            self: @ContractState
        ) -> ContractAddress {
            self.fee_collector_instance.read()
        }

        fn get_ttsuite(
            self: @ContractState,
            project_id: felt252,
        ) -> TTSuite {
            self.registry.read(project_id)
        }
    }
}