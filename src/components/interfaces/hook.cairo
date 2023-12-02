use starknet::{ContractAddress};

#[starknet::interface]
trait ITTHook<TContractState> {
    fn did_call(
        ref self: TContractState,
        function_name: felt252,
        context: Span<felt252>,
        caller: ContractAddress
    );
}