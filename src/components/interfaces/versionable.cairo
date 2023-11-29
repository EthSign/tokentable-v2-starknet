#[starknet::interface]
trait IVersionable<TContractState> {
    fn version(self: @TContractState) -> felt252;
}