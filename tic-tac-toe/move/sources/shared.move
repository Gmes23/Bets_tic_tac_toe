module tic_tac_toe::game {
    use sui::object::{Self, UID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use std::vector;
    use sui::event;
    use sui::object::ID;
    use sui::balance::{Self, Balance};
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;

    // Error constants
    const INVALID_MOVE: u64 = 0;
    const NOT_YOUR_TURN: u64 = 1;
    const GAME_OVER: u64 = 2;
    const INVALID_POSITION: u64 = 3;
    const POSITION_TAKEN: u64 = 4;
    const PLAYER_ALREADY_JOINED: u64 = 5;
    const GAME_NOT_STARTED: u64 = 6;
    const INVALID_BET_AMOUNT: u64 = 7;

    // Game status
    const IN_PROGRESS: u8 = 0;
    const X_WON: u8 = 1;
    const O_WON: u8 = 2;
    const DRAW: u8 = 3;

    public struct Game has key {
        id: UID,
        board: vector<u8>,
        player_x: address,
        player_o: address,
        current_turn: address,
        status: u8,
        pot: Balance<SUI>,    // Total betting pool
        bet_amount: u64       // Required bet amount
    }

    public struct GameResult has copy, drop {
        game_id: ID,
        winner: address,
        status: u8,
        payout_amount: u64    // Amount won
    }

    // === Events ===
    public struct GameCreated has copy, drop {
        game_id: ID,
        player_x: address,
        bet_amount: u64
    }

    public struct PlayerJoined has copy, drop {
        game_id: ID,
        player_o: address,
        bet_amount: u64
    }

    public struct MoveMade has copy, drop {
        game_id: ID,
        player: address,
        position: u8
    }

    // === Public functions ===

    public fun create_game(bet: Coin<SUI>, ctx: &mut TxContext) {
        let sender = tx_context::sender(ctx);
        let bet_amount = coin::value(&bet);
        
        let game = Game {
            id: object::new(ctx),
            board: vector[0,0,0,0,0,0,0,0,0],
            player_x: sender,
            player_o: @0x0,
            current_turn: sender,
            status: IN_PROGRESS,
            pot: coin::into_balance(bet),
            bet_amount: bet_amount
        };

        event::emit(GameCreated {
            game_id: object::uid_to_inner(&game.id),
            player_x: sender,
            bet_amount
        });

        transfer::share_object(game);
    }

    public fun join_game(game: &mut Game, bet: Coin<SUI>, ctx: &mut TxContext) {
        let sender = tx_context::sender(ctx);
        let bet_amount = coin::value(&bet);
        
        assert!(game.player_o == @0x0, PLAYER_ALREADY_JOINED);
        assert!(sender != game.player_x, PLAYER_ALREADY_JOINED);
        assert!(bet_amount == game.bet_amount, INVALID_BET_AMOUNT);
        
        balance::join(&mut game.pot, coin::into_balance(bet));
        game.player_o = sender;

        event::emit(PlayerJoined {
            game_id: object::uid_to_inner(&game.id),
            player_o: sender,
            bet_amount
        });
    }

    public fun make_move(game: &mut Game, position: u8, ctx: &mut TxContext) {
        let sender = tx_context::sender(ctx);
        
        // Validations
        assert!(game.player_o != @0x0, GAME_NOT_STARTED);
        assert!(game.status == IN_PROGRESS, GAME_OVER);
        assert!(sender == game.current_turn, NOT_YOUR_TURN);
        assert!(position < 9, INVALID_POSITION);
        assert!(*vector::borrow(&game.board, (position as u64)) == 0, POSITION_TAKEN);

        // Make move
        let mark = if (sender == game.player_x) { 1 } else { 2 };
        *vector::borrow_mut(&mut game.board, (position as u64)) = mark;

        event::emit(MoveMade {
            game_id: object::uid_to_inner(&game.id),
            player: sender,
            position
        });

        // Update turn
        game.current_turn = if (sender == game.player_x) { 
            game.player_o 
        } else { 
            game.player_x 
        };

        // Check game status
        check_game_status(game, ctx);
    }

    public fun get_game_status(game: &Game): u8 {
        game.status
    }

    public fun get_winner(game: &Game): address {
        assert!(game.status == X_WON || game.status == O_WON, GAME_NOT_STARTED);
        if (game.status == X_WON) {
            game.player_x
        } else {
            game.player_o
        }
    }

    // === Private functions ===

    fun check_game_status(game: &mut Game, ctx: &mut TxContext) {
        // Check all winning combinations
        check_line(game, 0, 1, 2, ctx);
        check_line(game, 3, 4, 5, ctx);
        check_line(game, 6, 7, 8, ctx);
        //check rows
        check_line(game, 0, 3, 6, ctx);
        check_line(game, 1, 4, 7, ctx);
        check_line(game, 2, 5, 8, ctx);
        // Check diagonals
        check_line(game, 0, 4, 8, ctx);
        check_line(game, 2, 4, 6, ctx);

        // Check for draw
        if (game.status == IN_PROGRESS) {
            let mut is_full = true;
            let mut i = 0;
            while (i < 9) {
                if (*vector::borrow(&game.board, i) == 0) {
                    is_full = false;
                    break
                };
                i = i + 1;
            };
            if (is_full) {
                game.status = DRAW;
                let split_amount = balance::value(&game.pot) / 2;
                
                // Return half to each player
                transfer::public_transfer(
                    coin::from_balance(balance::split(&mut game.pot, split_amount), ctx),
                    game.player_x
                );
                transfer::public_transfer(
                    coin::from_balance(balance::withdraw_all(&mut game.pot), ctx),
                    game.player_o
                );

                event::emit(GameResult {
                    game_id: object::uid_to_inner(&game.id),
                    winner: @0x0,
                    status: DRAW,
                    payout_amount: split_amount
                });
            };
        };
    }

    fun check_line(game: &mut Game, a: u64, b: u64, c: u64, ctx: &mut TxContext) {
        let board = &game.board;
        let val_a = *vector::borrow(board, a);
        if (val_a != 0) {
            let val_b = *vector::borrow(board, b);
            let val_c = *vector::borrow(board, c);
            if (val_a == val_b && val_b == val_c) {
                game.status = if (val_a == 1) { X_WON } else { O_WON };
                let winner = if (val_a == 1) { game.player_x } else { game.player_o };
                let total_pot = balance::value(&game.pot);
                
                // Transfer entire pot to winner
                transfer::public_transfer(
                    coin::from_balance(balance::withdraw_all(&mut game.pot), ctx), 
                    winner
                );

                event::emit(GameResult {
                    game_id: object::uid_to_inner(&game.id),
                    winner,
                    status: game.status,
                    payout_amount: total_pot
                });
            }
        }
    }
}