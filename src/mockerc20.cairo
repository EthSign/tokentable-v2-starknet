#[starknet::contract]
mod MockERC20 {
    use openzeppelin::token::erc20::erc20::ERC20Component::InternalTrait;
    use openzeppelin::token::erc20::ERC20Component;
    use tokentable_v2::components::interfaces::mockerc20::{
        IMockERC20
    };
    use starknet::ContractAddress;

    component!(path: ERC20Component, storage: erc20, event: ERC20Event);

    #[abi(embed_v0)]
    impl ERC20Impl = ERC20Component::ERC20Impl<ContractState>;
    #[abi(embed_v0)]
    impl ERC20MetadataImpl = ERC20Component::ERC20MetadataImpl<ContractState>;
    #[abi(embed_v0)]
    impl ERC20CamelOnlyImpl = ERC20Component::ERC20CamelOnlyImpl<ContractState>;
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
        fn mint(
            ref self: ContractState,
            to: ContractAddress,
            amount: u256
        ) {
            self.erc20._mint(to, amount);
        }
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
    ) {
        let name = 'MockERC20';
        let symbol = 'M20';
        self.erc20.initializer(name, symbol);
    }
}