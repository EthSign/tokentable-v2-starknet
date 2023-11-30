use starknet::ContractAddress;

#[derive(PartialEq, Drop, Serde, Copy, starknet::Store)]
struct TTSuite {
    unlocker_instance: ContractAddress,
    futuretoken_instance: ContractAddress,
}