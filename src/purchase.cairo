// Interface for Purchase contractuse
#[starknet::interface]
use starknet::ContractAddress;
trait IPurchase<T> {
    fn buy_book(ref self: T, title: felt252) -> bool;
    fn get_bookstore(self: @T) -> ContractAddress;
}

#[starknet::contract]
mod Purchase {
    use starknet::ContractAddress;
    use starknet::get_caller_address;
    use starknet::storage::{
        StoragePointerReadAccess, StoragePointerWriteAccess, };
    
    // Import the Bookstore interface for cross-contract calls
    //use super::{IBookstoreDispatcher, IBookstoreDispatcherTrait, };
    use crate::{IBookstoreDispatcher, IBookstoreDispatcherTrait};

    // Storage for the contract
    #[storage]
    struct Storage {
        bookstore_address: ContractAddress,
    }

    // Events
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        BookPurchased: BookPurchased,
    }

    #[derive(Drop, starknet::Event)]
    struct BookPurchased {
        #[key]
        buyer: ContractAddress,
        title: felt252,
        price: u16,
    }

    // Constructor to set the Bookstore contract address
    #[constructor]
    fn constructor(ref self: ContractState, bookstore_address: ContractAddress) {
        self.bookstore_address.write(bookstore_address);
    }

    // Implementation of the Purchase interface
    #[abi(embed_v0)]
    impl PurchaseImpl of super::IPurchase<ContractState> {
        // Function to buy a book
        fn buy_book(ref self: ContractState, title: felt252) -> bool {
            let caller = get_caller_address();
            let bookstore_address = self.bookstore_address.read();
            
            // Create a dispatcher to interact with the Bookstore contract
            let bookstore_dispatcher = IBookstoreDispatcher { contract_address: bookstore_address };
            
            // Check if the book is available and get its price
            let (available, price) = bookstore_dispatcher.check_availability(title);
            
            // If book is not available, return false
            if !available {
                return false;
            }
            
            // Purchase the book from the Bookstore contract
            let purchased = bookstore_dispatcher.purchase_book(title);
            
            // If purchase successful, emit an event
            if purchased {
                self.emit(Event::BookPurchased(BookPurchased { 
                    buyer: caller, 
                    title, 
                    price 
                }));
            }
            
            purchased
        }

        // Function to get the Bookstore contract address
        fn get_bookstore(self: @ContractState) -> ContractAddress {
            self.bookstore_address.read()
        }
    }
}

