use starknet::ContractAddress;

#[starknet::interface]
trait IDateTrait<T> {
    fn get_next_token_id(self: @T) -> u256;
    fn mint_date_nft(
        ref self: T, 
        partner: ContractAddress
    );
    fn submit_date_experience(
        ref self: T, 
        partner: ContractAddress,
        experience_uri: ByteArray
    );
}

#[starknet::contract]
pub mod DateContract {
    use starknet::{ContractAddress, get_caller_address};
    use openzeppelin_introspection::src5::SRC5Component;
    use super::{IDateTrait};
    use starknet::storage::{
        StoragePointerReadAccess, StoragePointerWriteAccess, StoragePathEntry, Map,
    };
    use openzeppelin_token::erc721::{ERC721Component, ERC721HooksEmptyImpl};
 


    component!(path: ERC721Component, storage: erc721, event: ERC721Event);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    #[abi(embed_v0)]
    impl ERC721Impl = ERC721Component::ERC721Impl<ContractState>;
    impl ERC721InternalImpl = ERC721Component::InternalImpl<ContractState>;
    
    #[storage]
    struct Storage {
        date_submissions: Map<(ContractAddress, ContractAddress), bool>,        
        next_token_id: u256,
        #[substorage(v0)]
        erc721: ERC721Component::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        
    }



    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC721Event: ERC721Component::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
        
        DateSubmissionRegistered: DateSubmissionRegistered
    }

    #[derive(Drop, starknet::Event)]
    struct DateSubmissionRegistered {
        submitter: ContractAddress,
        partner: ContractAddress
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        name: ByteArray,
        symbol: ByteArray,
        base_uri: ByteArray
    ) {
        self.erc721.initializer(name, symbol, base_uri);
        self.next_token_id.write(1);
    }



    

    #[abi(embed_v0)]
    impl IDateTraitImpl of IDateTrait<ContractState>{
    fn get_next_token_id(self: @ContractState) -> u256 {
        self.next_token_id.read()
    }

    fn mint_date_nft(
        ref self: ContractState, 
        partner: ContractAddress
    ) {
        let caller = get_caller_address();
                let caller_submitted = self.date_submissions.entry((caller, partner)).read();
        let partner_submitted = self.date_submissions.entry((caller, partner)).read();
        
        assert!(caller_submitted && partner_submitted, "Mutual submission required");
        
        let token_id = self.next_token_id.read();
        self.erc721.mint(caller, token_id);
        
        self.next_token_id.write(token_id + 1);
        
        self.date_submissions.entry((caller, partner)).write(false);
        self.date_submissions.entry((caller, partner)).write(false);
    }

    fn submit_date_experience(
        ref self: ContractState, 
        partner: ContractAddress,
        experience_uri: ByteArray
    ) {
        
        let caller = get_caller_address();
        
        assert!(caller != partner, "Cannot submit with self");
        
        self.date_submissions.entry((caller, partner)).write(true);
        
        self.emit(DateSubmissionRegistered { submitter: caller, partner });
    }
}
}