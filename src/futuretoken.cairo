#[starknet::contract]
mod TTFutureToken {
    use starknet::{
        ContractAddress, get_caller_address,
        storage::{StoragePointerReadAccess, StoragePointerWriteAccess}
    };
    use core::num::traits::Zero;
    use openzeppelin::{
        introspection::src5::SRC5Component,
        token::{erc20::interface::{ERC20ABIDispatcher, ERC20ABIDispatcherTrait},},
        access::ownable::interface::{IOwnableDispatcher, IOwnableDispatcherTrait,}
    };
    use tokentable_v2::components::{
        interfaces::{
            futuretoken::{ITTFutureToken, TTFutureTokenErrors},
            unlocker::{ITTUnlockerDispatcher, ITTUnlockerDispatcherTrait},
            versionable::IVersionable,
        },
        custom_erc721::{ERC721Component, ERC721HooksEmptyImpl}
    };

    component!(path: ERC721Component, storage: erc721, event: ERC721Event);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    // ERC721
    #[abi(embed_v0)]
    impl ERC721MixinImpl = ERC721Component::ERC721MixinImpl<ContractState>;
    impl ERC721InternalImpl = ERC721Component::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        // Component storage
        #[substorage(v0)]
        erc721: ERC721Component::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        // TTFutureToken storage
        authorized_minter: ITTUnlockerDispatcher,
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
    }

    #[constructor]
    fn constructor(ref self: ContractState, project_token: ContractAddress, is_transferable: bool) {
        let erc20_dispatcher = ERC20ABIDispatcher { contract_address: project_token };
        let name = "Future " + erc20_dispatcher.name();
        let symbol = "FT-" + erc20_dispatcher.symbol();
        self.erc721.initializer(name, symbol, "");
        self.token_counter.write(1);
        self.erc721._set_allow_transfer(is_transferable);
    }

    #[abi(embed_v0)]
    impl Versionable of IVersionable<ContractState> {
        fn version(self: @ContractState) -> felt252 {
            '2.5.8'
        }
    }

    #[abi(embed_v0)]
    impl TTFutureTokenImpl of ITTFutureToken<ContractState> {
        fn set_authorized_minter_single_use(
            ref self: ContractState, authorized_minter: ContractAddress
        ) {
            let current_authorized_minter = self.authorized_minter.read();
            assert(
                current_authorized_minter.contract_address.is_zero(),
                TTFutureTokenErrors::NOT_PERMISSIONED
            );
            self
                .authorized_minter
                .write(ITTUnlockerDispatcher { contract_address: authorized_minter });
        }

        fn mint(ref self: ContractState, to: ContractAddress, unsafe_mint: bool,) -> u256 {
            self._only_authorized_minter();
            let token_id = self._increment_token_counter_and_return_new_value();
            if unsafe_mint {
                self.erc721.mint(to, token_id,);
            } else {
                self.erc721.safe_mint(to, token_id, array![].span(),);
            }
            token_id
        }

        fn set_token_base_uri(ref self: ContractState, uri: ByteArray) {
            self._only_authorized_minter_owner();
            self.erc721._set_base_uri(uri);
        }

        fn get_claim_info(self: @ContractState, token_id: u256) -> (u256, u256, bool) {
            let (delta_amount_claimable, updated_amount_claimed) = self
                .authorized_minter
                .read()
                .calculate_amount_claimable(token_id);
            let amount_already_claimed = updated_amount_claimed - delta_amount_claimable;
            let is_cancelable = self.authorized_minter.read().is_cancelable();
            (delta_amount_claimable, amount_already_claimed, is_cancelable)
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalImplTrait {
        fn _increment_token_counter_and_return_new_value(ref self: ContractState) -> u256 {
            let value = self.token_counter.read();
            let new_value = value + 1;
            self.token_counter.write(new_value);
            value
        }

        fn _only_authorized_minter(ref self: ContractState) {
            assert(
                get_caller_address() == self.authorized_minter.read().contract_address,
                TTFutureTokenErrors::NOT_PERMISSIONED
            );
        }

        fn _only_authorized_minter_owner(ref self: ContractState) {
            assert(
                get_caller_address() == IOwnableDispatcher {
                    contract_address: self.authorized_minter.read().contract_address
                }
                    .owner(),
                TTFutureTokenErrors::NOT_PERMISSIONED
            );
        }
    }
}
