use starknet::{ContractAddress};

#[starknet::interface]
trait ITTHook<TContractState> {
    fn did_call(
        ref self: TContractState,
        selector: felt252,
        context: Span::<felt252>,
        caller: ContractAddress
    );
}