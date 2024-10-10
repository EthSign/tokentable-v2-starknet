#[starknet::contract]
pub mod MockERC20 {
    use openzeppelin::token::erc20::{ERC20Component, ERC20HooksEmptyImpl};
    use tokentable_v2::components::interfaces::mockerc20::{IMockERC20};
    use starknet::ContractAddress;

    component!(path: ERC20Component, storage: erc20, event: ERC20Event);

    #[abi(embed_v0)]
    impl ERC20MixinImpl = ERC20Component::ERC20MixinImpl<ContractState>;
    impl ERC20InternalImpl = ERC20Component::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc20: ERC20Component::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC20Event: ERC20Component::Event
    }

    #[abi(embed_v0)]
    impl MockERC20Impl of IMockERC20<ContractState> {
        fn mint(ref self: ContractState, to: ContractAddress, amount: u256) {
            self.erc20.mint(to, amount);
        }
    }

    #[constructor]
    fn constructor(ref self: ContractState,) {
        self.erc20.initializer("MockERC20", "M20");
    }
}
