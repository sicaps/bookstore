// Book struct to store book details

pub mod purchase;
#[derive(Drop, Serde, starknet::Store)]
struct Book {
    title: felt252,
    author: felt252,
    description: felt252,
    price: u16,
    quantity: u8,
}

// Interface for Bookstore contract
#[starknet::interface]
trait IBookstore<T> {
    fn add_book(
        ref self: T, 
        title: felt252, 
        author: felt252, 
        description: felt252, 
        price: u16, 
        quantity: u8
    );
    fn update_book(ref self: T, title: felt252, price: u16, quantity: u8);
    fn remove_book(ref self: T, title: felt252);
    fn get_book(self: @T, title: felt252) -> Book;
    fn check_availability(self: @T, title: felt252) -> (bool, u16);
    fn purchase_book(ref self: T, title: felt252) -> bool;
}


#[starknet::contract]
mod Bookstore {
    use starknet::ContractAddress;
    use starknet::get_caller_address;
    use super::Book;
    use starknet::storage::{
        StoragePointerReadAccess, StoragePointerWriteAccess, Map, StorageMapReadAccess, 
        StorageMapWriteAccess, };

    // Storage for the contract
    #[storage]
    struct Storage {
        owner: ContractAddress,
        books: Map::<felt252, Book>, // Map book title to Book struct
    }

    // Events
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        BookAdded: BookAdded,
        BookUpdated: BookUpdated,
        BookRemoved: BookRemoved,
    }

    #[derive(Drop, starknet::Event)]
    struct BookAdded {
        #[key]
        title: felt252,
        author: felt252,
        price: u16,
        quantity: u8,
    }

    #[derive(Drop, starknet::Event)]
    struct BookUpdated {
        #[key]
        title: felt252,
        price: u16,
        quantity: u8,
    }

    #[derive(Drop, starknet::Event)]
    struct BookRemoved {
        #[key]
        title: felt252,
    }

    // Constructor to initialize the contract
    #[constructor]
    fn constructor(ref self: ContractState) {
        self.owner.write(get_caller_address());
    }

    // Internal functions
    #[generate_trait]
    impl InternalFunctions of InternalTrait {
        fn assert_only_owner(self: @ContractState) {
            let caller = get_caller_address();
            let owner = self.owner.read();
            assert(caller == owner, 'Caller is not the owner');
        }
    }

    // Implementation of the Bookstore interface
    #[abi(embed_v0)]
    impl BookstoreImpl of super::IBookstore<ContractState> {
        // Function to add a new book (owner only)
        fn add_book(
            ref self: ContractState, 
            title: felt252, 
            author: felt252, 
            description: felt252, 
            price: u16, 
            quantity: u8
        ) {
            // Only owner can add books
            InternalFunctions::assert_only_owner(@self);
            
            // Create a new book struct
            let book = Book {
                title,
                author,
                description,
                price,
                quantity,
            };
            
            // Store the book in the map
            self.books.write(title, book);
            
            // Emit event
            self.emit(Event::BookAdded(BookAdded { title, author, price, quantity }));
        }

        // Function to update book details (owner only)
        fn update_book(
            ref self: ContractState, 
            title: felt252, 
            price: u16, 
            quantity: u8
        ) {
            // Only owner can update books
            InternalFunctions::assert_only_owner(@self);
            
            // Get the current book
            let book = self.books.read(title);
            
            // Create an updated book
            let updated_book = Book {
                title: book.title,
                author: book.author,
                description: book.description,
                price,
                quantity,
            };
            
            // Update the book in the map
            self.books.write(title, updated_book);
            
            // Emit event
            self.emit(Event::BookUpdated(BookUpdated { title, price, quantity }));
        }

        // Function to remove a book (owner only)
        fn remove_book(ref self: ContractState, title: felt252) {
            // Only owner can remove books
            InternalFunctions::assert_only_owner(@self);
            
            // Remove the book from storage
            self.books.write(title, Book { 
                title: 0, 
                author: 0, 
                description: 0, 
                price: 0, 
                quantity: 0 
            });
            
            // Emit event
            self.emit(Event::BookRemoved(BookRemoved { title }));
        }

        // Function to get book details
        fn get_book(self: @ContractState, title: felt252) -> Book {
            self.books.read(title)
        }

        // Function to check if a book is available and get its price
        fn check_availability(self: @ContractState, title: felt252) -> (bool, u16) {
            let book = self.books.read(title);
            (book.quantity > 0, book.price)
        }

        // Function to decrease the quantity when a book is purchased
        fn purchase_book(ref self: ContractState, title: felt252) -> bool {
            let book = self.books.read(title);
            
            // Check if book is available
            if book.quantity == 0 {
                return false;
            }
            
            // Update the book quantity
            let updated_book = Book {
                title: book.title,
                author: book.author,
                description: book.description,
                price: book.price,
                quantity: book.quantity - 1,
            };
            
            self.books.write(title, updated_book);
            
            true
        }
    }
}

