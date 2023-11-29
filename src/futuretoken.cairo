#[starknet::contract]
mod FutureToken {
    use starknet::{
        ContractAddress,
        get_caller_address
    };
    use core::Zeroable;
    use openzeppelin::{
        introspection::src5::SRC5Component,
        token::{
            erc20::interface::{
                ERC20ABIDispatcher,
                ERC20ABIDispatcherTrait
            },
        }
    };
    use tokentable_v2::components::{
        interfaces::futuretoken::{
            IFutureToken,
            FutureTokenErrors,
            FutureTokenEvents::DidSetBaseURI
        },
        custom_erc721::ERC721Component
    };

    component!(path: ERC721Component, storage: erc721, event: ERC721Event);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    
    // ERC721
    #[abi(embed_v0)]
    impl ERC721TTCustomImpl = 
        ERC721Component::ERC721TTCustomImpl<ContractState>;
    #[abi(embed_v0)]
    impl ERC721Impl = ERC721Component::ERC721Impl<ContractState>;
    #[abi(embed_v0)]
    impl ERC721MetadataImpl = 
        ERC721Component::ERC721MetadataImpl<ContractState>;
    #[abi(embed_v0)]
    impl ERC721CamelOnly = ERC721Component::ERC721CamelOnlyImpl<ContractState>;
    #[abi(embed_v0)]
    impl ERC721MetadataCamelOnly =
        ERC721Component::ERC721MetadataCamelOnlyImpl<ContractState>;
    impl ERC721InternalImpl = ERC721Component::InternalImpl<ContractState>;
    // SRC5
    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;

    #[storage]
    struct Storage {
        // Component storage
        #[substorage(v0)]
        erc721: ERC721Component::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        // FutureToken storage
        authorized_minter: ContractAddress,
        base_uri: felt252,
        token_counter: u256
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        // Component events
        #[flat]
        ERC721Event: ERC721Component::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
        // FutureToken events
        DidSetBaseURI: DidSetBaseURI
    }

    #[constructor]
    fn constructor(
        ref self: ContractState, 
        project_token: ContractAddress,
        allow_transfer_: bool
    ) {
        let erc20_dispatcher = ERC20ABIDispatcher {
            contract_address: project_token
        };
        let name = 'Future ' + erc20_dispatcher.name();
        let symbol = 'FT-' + erc20_dispatcher.symbol();
        self.erc721.initializer(name, symbol);
        self.token_counter.write(1);
        self.erc721._set_allow_transfer(allow_transfer_);
    }

    #[abi(embed_v0)]
    impl FutureTokenImpl of IFutureToken<ContractState> {
        fn set_authorized_minter_single_use(
            ref self: ContractState,
            authorized_minter_: ContractAddress
        ) {
            let current_authorized_minter = self.authorized_minter.read();
            assert(
                current_authorized_minter == Zeroable::zero(), 
                FutureTokenErrors::UNAUTHORIZED
            );
            self.authorized_minter.write(authorized_minter_);
        }

        fn safe_mint(
            ref self: ContractState,
            to: ContractAddress
        ) -> u256 {
            self._only_authorized_minter();
            let token_id = 
                self._increment_token_counter_and_return_new_value();
            self.erc721._safe_mint(
                to, 
                token_id, 
                (array![]).span()
            );
            token_id
        }

        fn set_uri(
            ref self: ContractState,
            uri: felt252
        ) {
            self._only_authorized_minter();
            self.base_uri.write(uri);
            self.emit(
                Event::DidSetBaseURI(
                    DidSetBaseURI {
                        new_uri: uri
                    }
                )
            );
        }

        fn get_claim_info(
            self: @ContractState,
            token_id: u256
        ) -> (u256, u256, bool) {
            // TODO
            (0,0,false)
        }

        fn get_base_uri(
            self: @ContractState
        ) -> felt252 {
            self.base_uri.read()
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalImplTrait {
        fn _increment_token_counter_and_return_new_value(
            ref self: ContractState
        ) -> u256 {
            let value = self.token_counter.read();
            let new_value = value + 1;
            self.token_counter.write(new_value);
            new_value
        }

        fn _only_authorized_minter(
            ref self: ContractState
        ) {
            assert(
                get_caller_address() == self.authorized_minter.read(), 
                FutureTokenErrors::UNAUTHORIZED
            );
        }
    }
}
