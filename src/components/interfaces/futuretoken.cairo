use starknet::{ContractAddress};

#[starknet::interface]
trait IFutureToken<TContractState> {
    fn set_authorized_minter_single_use(
        ref self: TContractState,
        authorized_minter: ContractAddress
    );

    fn safe_mint(
        ref self: TContractState,
        to: ContractAddress
    ) -> u256;

    fn set_uri(
        ref self: TContractState,
        uri: felt252
    );

    fn get_claim_info(
        self: @TContractState,
        token_id: u256
    ) -> (u256, u256, bool);

    fn get_base_uri(
        self: @TContractState
    ) -> felt252;
}

mod FutureTokenEvents {
    #[derive(Drop, starknet::Event)]
    struct DidSetBaseURI {
        #[key]
        new_uri: felt252
    }
}

mod FutureTokenErrors {
    const UNAUTHORIZED: felt252 = 'UNAUTHORIZED';
}