use starknet::{ContractAddress};

#[starknet::interface]
trait IMockERC20<TContractState> {
    fn mint(
        ref self: TContractState,
        to: ContractAddress,
        amount: u256
    );
}