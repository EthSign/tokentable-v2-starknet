use starknet::{
    ContractAddress,
    class_hash::ClassHash
};

#[starknet::interface]
trait IUpgradeable<TContractState> {
    fn upgrade(
        ref self: TContractState, 
        impl_hash: ClassHash
    );
}