#[starknet::contract]
mod TTFeeCollector {
    use starknet::{
        ContractAddress,
        get_caller_address,
    };
    use openzeppelin::{
        access::ownable::OwnableComponent,
        token::erc20::interface::{
            IERC20Dispatcher,
            IERC20DispatcherTrait
        }
    };
    use tokentable_v2::components::interfaces::{
        feecollector::ITTFeeCollector,
        versionable::IVersionable,
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

    const BIPS_PRECISION: u256 = 10000;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        default_fee_bips: u256,
        custom_fee_bips: LegacyMap<ContractAddress, u256>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        OwnableEvent: OwnableComponent::Event,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        owner: ContractAddress,
    ) {
        self.ownable.initializer(owner);
    }

    #[abi(embed_v0)]
    impl Versionable of IVersionable<ContractState> {
        fn version(self: @ContractState) -> felt252 {
            '2.0.1'
        }
    }

    #[abi(embed_v0)]
    impl TTFeeCollectorImpl of ITTFeeCollector<ContractState> {
        fn withdraw_fee(
            ref self: ContractState,
            token: ContractAddress,
            amount: u256
        ) {
            self.ownable.assert_only_owner();
            IERC20Dispatcher {
                contract_address: token
            }.transfer(self.ownable.owner(), amount);
        }

        fn set_default_fee(
            ref self: ContractState,
            bips: u256
        ) {
            self.ownable.assert_only_owner();
            self.default_fee_bips.write(bips);
        }

        fn set_custom_fee(
            ref self: ContractState,
            unlocker_instance: ContractAddress,
            bips: u256
        ) {
            self.ownable.assert_only_owner();
            self.custom_fee_bips.write(unlocker_instance, bips);
        }

        fn get_default_fee(
            self: @ContractState
        ) -> u256 {
            self.default_fee_bips.read()
        }

        fn get_fee(
            self: @ContractState,
            unlocker_instance: ContractAddress,
            tokens_transferred: u256
        ) -> u256 {
            let mut fee_bips = self.custom_fee_bips.read(unlocker_instance);
            if fee_bips == 0 {
                fee_bips = self.default_fee_bips.read();
            } else if fee_bips == BIPS_PRECISION {
                fee_bips = 0;
            }
            tokens_transferred * fee_bips / BIPS_PRECISION
        }
    }
}