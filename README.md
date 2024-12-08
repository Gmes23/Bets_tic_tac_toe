# Tic Tac Toe on Sui: React + Sui Client Integration
## Overview
This tutorial demonstrates how to use the React frontend application to interact with the Tic Tac Toe game deployed on the Sui blockchain. Players can connect wallets, create games, join existing games using an object ID, and play the game to completion.
A working version of this project can be found at [vercel] (https://bets-tic-tac-3pntjbzhn-gerardo-mestanzas-projects.vercel.app/)

### Features
- Blockchain-Powered Gameplay: Game logic is executed through a Sui Move smart contract.
- Wallet Integration: Connect your wallet to create or join games.
- Multiplayer: Play against another wallet-addressed player.
- Game State Sync: Automatic updates of game state between players using polling.
- Decentralized NFT Rewards: The winner receives an on-chain trophy NFT.

### Setup Instructions

#### Prerequisites
- **Sui CLI Installed**: Ensure you have the Sui CLI installed and the Sui fullnode running locally or on testnet.
- **Node.js Installed**: Ensure you have Node.js (version 16+) and npm installed for React development.
- **Git Installed**: Required to clone the project repository.

#### Getting Started
1. Clone the Project Repository
` git clone https://github.com/your-repo/tic-tac-toe.git` 
2. cd tic-tac-toe/front
Install Dependencies
` npm install` 
3. Start the Development Server
` npm start ` 
The app will be available at http://localhost:3000.

#### Step-by-Step Guide
1. Connect Wallet
Click the Connect Wallet button.
The app will connect to the first available wallet and display the connected wallet address.
2. Start a New Game (Player 1)
`Player 1` places the adress of `Player 2` in the input field and clicks Start New Game to initialize a new game on the blockchain.
The game object ID will be displayed. Share this ID with Player 2.
3. Join a Game (Player 2)
Enter the game object ID in the input field and click Join Game.
The game state will update dynamically based on the blockchain.
4. Make a Move
Click on an empty cell to place a mark. The turn will alternate between Player X (player 1) and Player O (player 2) until a winner is determined.
The app ensures that only the correct player can make a move during their turn.
5. Display Winner
Once a player wins, a trophy object will be created signify there is a winner and the game will stop. The winner's information will be displayed.

### Design Document
GameApp:

Handles wallet connection, game creation, joining, and moves.
Displays the game board dynamically based on blockchain state.

Game Creation:
Key Functions

1. Connect Wallet
```javascript
const connectWallet = () => {
  if (wallets.length > 0) {
    connect({ wallet: wallets[0] }, { onSuccess: () => setIsConnected(true) });
  }
};
```
This function connects the user's wallet to the application.
It checks if wallets are available (wallets.length > 0).
Uses the connect method provided by the wallet library to establish a connection.
If connection is successful, it updates the state variable isConnected to true.
Allowing the user to interact with the game once their wallet is connected.

```javascript
const startNewGame = async () => {
  const tx = new Transaction();
  tx.moveCall({
    target: "shared::new",
    arguments: [tx.pure.address(account.address), tx.pure.address(account.address)],
  });
  signAndExecuteTransaction({ transaction: tx });
};
```
2. Start New Game
Initializes a new game on the blockchain. Creates a new transaction (tx) and sets the required parameters.
By calling the `shared::new` function in the smart contract we create a game object.
It uses the connected wallet's address `(account.address)` for Player X and Player O during testing.
Signs and executes the transaction to create the game, returning a unique `objectId` for the game.


3. Join Existing Game
```javascript
const joinExistingGame = async (gameObjectId) => {
    try {
      const gameState = await client.getObject({
        id: gameObjectId,
        options: { showContent: true },
      });
      if (gameState) {
        // The gameState object contains metadata and the content of the game object from theblockchain.
        // The content includes fields such as the board state, the turn, and the players' addresses.
        // All this is derived from the objectId; object IDs on Sui are unique, similar to addresses
        const boardData = gameState.data.content.fields.board;
    ......
```
`joinExistingGame` Allows Player 2 to join an existing game by entering the gameObjectId created by Player 1.
This Fetches the game state from the blockchain using the entered gameObjectId.
Updates the local state with the game board (setGameBoard) and the game object ID (setCreatedObjectId).
Finally it enables Player 2 to make moves based on the existing game

4. Make a Move
```javascript
Copy code
const makeMove = async (row, col) => {
  const tx = new Transaction();
  tx.moveCall({
    target: "shared::place_mark",
    arguments: [tx.object(createdObjectId), tx.pure.u8(row), tx.pure.u8(col)],
  });
  signAndExecuteTransaction({ transaction: tx });
};
```
`makeMove` Allows a player to make a move on the game board.
Creates a transaction to call the `shared::place_mark` function in the smart contract.
Uses the row and col parameters to specify the cell where the mark should be placed.
It then executes the transaction and updates the local game board state.
Toggles the turn between Player X and Player O.
Finally it ensures no moves are allowed after a winner is determined or if the game ends in a draw.


5. Determine Winner
```javascript
const determineWinner = (transaction) => {
  const effects = transaction.effects;
  if (effects?.created?.some((obj) => obj.reference.objectId)) {
    return Winner.You; // Assuming the current user won if a trophy was created
  }
  return Winner.None;
};
```
This function determines if a player has won the game by checking if a trophy object was created in the transaction effects.
If a trophy is created, it returns `Winner.You` indicating the current player has won.
Otherwise, it returns `Winner.None` indicating the game is still in progress or has ended in a draw.
The function is called after every move to update the game's state and display the winner.


### Deployment to Vercel
Run npm run build to generate a production build.
Deploy the build folder to Vercel via the Vercel CLI or web interface.
By following these instructions, you can set up, play, and extend the Tic Tac Toe game on the Sui blockchain with React

### Resources
To learn more about the technologies used in this project, check out the following resources:


- **[Sui-getting-started](https://docs.sui.io/guides/developer/getting-started/sui-install)**
- **[Sui-first-app](https://docs.sui.io/guides/developer/first-app)**
- **[Sui-tic-tac-toe](https://docs.sui.io/guides/developer/app-examples/tic-tac-toe)**
- **[Move-book](https://move-book.com/)**
- **[React](https://react.dev/learn)**
