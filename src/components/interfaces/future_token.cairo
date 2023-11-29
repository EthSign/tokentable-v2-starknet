use starknet::{ContractAddress};

#[starknet::interface]
trait IFutureToken<TContractState> {
    fn initialize(
        ref self: TContractState,
        project_token_: ContractAddress,
        allow_transfer_: bool
    );

    fn set_authorized_minter_single_use(
        ref self: TContractState,
        authorized_minter_: ContractAddress
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
}