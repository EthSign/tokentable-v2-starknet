use starknet::{ContractAddress};

#[starknet::interface]
trait ITrackerToken<TContractState> {
    fn initialize(
        ref self: TContractState,
        unlocker_instance: ContractAddress
    );
}