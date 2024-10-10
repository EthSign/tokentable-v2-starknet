#[starknet::contract]
pub mod MockERC721Receiver {
    use openzeppelin::{
        introspection::src5::{SRC5Component, SRC5Component::InternalImpl}, account::interface,
    };

    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;

    #[storage]
    struct Storage {
        // Component storage
        #[substorage(v0)]
        src5: SRC5Component::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        // Component events
        #[flat]
        SRC5Event: SRC5Component::Event,
    }

    #[constructor]
    fn constructor(ref self: ContractState) {
        self.src5.register_interface(interface::ISRC6_ID);
    }
}
