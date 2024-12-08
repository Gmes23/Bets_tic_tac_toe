module tic_tac_toe::game {
    use sui::object::{Self, UID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use std::vector;
    use sui::event;
    use sui::object::ID;

    // Error constants
    const INVALID_MOVE: u64 = 0;
    const NOT_YOUR_TURN: u64 = 1;
    const GAME_OVER: u64 = 2;
    const INVALID_POSITION: u64 = 3;
    const POSITION_TAKEN: u64 = 4;
    const PLAYER_ALREADY_JOINED: u64 = 5;
    const GAME_NOT_STARTED: u64 = 6;

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
    }

    public struct GameResult has copy, drop {
        game_id: ID,
        winner: address,
        status: u8
    }

    // === Events ===
    public struct GameCreated has copy, drop {
        game_id: ID,
        player_x: address
    }

    public struct PlayerJoined has copy, drop {
        game_id: ID,
        player_o: address
    }

    public struct MoveMade has copy, drop {
        game_id: ID,
        player: address,
        position: u8
    }

    // === Public functions ===

    public fun create_game(ctx: &mut TxContext) {
        let sender = tx_context::sender(ctx);
        let game = Game {
            id: object::new(ctx),
            board: vector[0,0,0,0,0,0,0,0,0],
            player_x: sender,
            player_o: @0x0,
            current_turn: sender,
            status: IN_PROGRESS,
        };

        event::emit(GameCreated {
            game_id: object::uid_to_inner(&game.id),
            player_x: sender
        });

        transfer::share_object(game);
    }

    public fun join_game(game: &mut Game, ctx: &mut TxContext) {
        let sender = tx_context::sender(ctx);
        assert!(game.player_o == @0x0, PLAYER_ALREADY_JOINED);
        assert!(sender != game.player_x, PLAYER_ALREADY_JOINED);
        
        game.player_o = sender;

        event::emit(PlayerJoined {
            game_id: object::uid_to_inner(&game.id),
            player_o: sender
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
        check_game_status(game);
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

    fun check_game_status(game: &mut Game) {
        // Check rows
        check_line(game, 0, 1, 2);
        check_line(game, 3, 4, 5);
        check_line(game, 6, 7, 8);

        // Check columns
        check_line(game, 0, 3, 6);
        check_line(game, 1, 4, 7);
        check_line(game, 2, 5, 8);

        // Check diagonals
        check_line(game, 0, 4, 8);
        check_line(game, 2, 4, 6);

        // Check draw
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
                event::emit(GameResult {
                    game_id: object::uid_to_inner(&game.id),
                    winner: @0x0,
                    status: DRAW
                });
            };
        };
    }

    fun check_line(game: &mut Game, a: u64, b: u64, c: u64) {
        let board = &game.board;
        let val_a = *vector::borrow(board, a);
        if (val_a != 0) {
            let val_b = *vector::borrow(board, b);
            let val_c = *vector::borrow(board, c);
            if (val_a == val_b && val_b == val_c) {
                game.status = if (val_a == 1) { X_WON } else { O_WON };
                event::emit(GameResult {
                    game_id: object::uid_to_inner(&game.id),
                    winner: if (val_a == 1) { game.player_x } else { game.player_o },
                    status: game.status
                });
            }
        }
    }
}