# Stacks Tap-It: Blockchain Gaming & DeFi Contracts

A comprehensive suite of smart contracts built on the **Stacks blockchain** using **Clarity**, featuring interactive gaming contracts and decentralized finance (DeFi) protocols.

## Overview

This project demonstrates advanced Clarity smart contract development patterns for gaming and financial applications on the Stacks blockchain. It includes both the `games` module (gaming contracts with wagers and multiplayer mechanics) and the `tapit` module (core DeFi infrastructure).

## Project Structure

```
stacks-tapit/
├── games/                          # Gaming contracts module
│   ├── contracts/
│   │   ├── CoinTossingGame.clar    # Single-player coin flip game
│   │   ├── PingPong.clar           # Two-player competitive game with powerups
│   │   └── NumberGuesser.clar      # Number guessing game contract
│   ├── tests/                      # Vitest test suite
│   ├── settings/
│   │   ├── Devnet.toml
│   │   ├── Testnet.toml
│   │   └── Mainnet.toml
│   ├── Clarinet.toml               # Clarinet project config
│   ├── package.json
│   ├── tsconfig.json
│   └── vitest.config.ts
│
└── tapit/                          # Core DeFi infrastructure
    ├── contracts/
    ├── tests/
    ├── settings/
    └── [Standard Clarinet structure]
```

## Gaming Contracts (`games/`)

### 1. CoinTossingGame.clar
**Purpose:** Single-player coin flip game with escrowed wagers

**Key Features:**
- Create games with specified wagers
- Fund games with STX
- Flip coins and determine winners
- Claim winnings or request refunds
- Full game lifecycle management

**Key Functions:**
- `create-game (stake-amount)` - Initialize a new game
- `fund-game (game-id)` - Fund a game with STX
- `flip-coin (game-id guess)` - Flip and guess outcome
- `claim-winnings (game-id)` - Claim winning payouts
- `cancel-game (game-id)` - Cancel active game
- `request-refund (game-id)` - Request refund for unresolved games

**Technical Details:**
- Minimum stake: 10 STX (10,000,000 microSTX)
- Game states: Pending, Funded, Completed, Cancelled
- Error handling with 9 distinct error codes
- Event logging for game lifecycle

---

### 2. PingPong.clar
**Purpose:** Two-player competitive game with staking, powerups, and timeout refunds

**Key Features:**
- Multi-round competitive gameplay
- Powerup system (health, damage boost, freeze)
- Staking mechanism for player investment
- Timeout refund protection
- Developer fee vault
- Game pause functionality

**Key Functions:**
- `create-game (opponent stake-amount)` - Create new game
- `join-game (game-id stake-amount)` - Accept and join game
- `play-round (game-id move)` - Execute game move
- `end-game (game-id result)` - Conclude game
- `grant-powerup (game-id player powerup-type)` - Award powerup
- `use-powerup (game-id powerup-id)` - Use powerup in game
- `claim-timeout-refund (game-id)` - Refund after timeout
- `withdraw-dev-fees ()` - Contract admin withdrawal

**Technical Details:**
- Game states: Created, Active, Completed, Refunded
- 3 powerup types: Health (+50 HP), Damage (2x damage), Freeze (skip opponent turn)
- Max 100 rounds per game
- Timeout: 1,440 blocks (≈6 hours on Stacks)
- Dev fee: 2.5% of winning amount
- Query functions for game state inspection

---

### 3. NumberGuesser.clar
**Purpose:** Number guessing game with range prediction

**Key Features:**
- Guess numbers within dynamic ranges
- Adjustable difficulty levels
- Scoring based on proximity to target
- Multi-guess rounds

## DeFi Contracts (`tapit/`)

The `tapit` module contains core infrastructure for DeFi applications (details to be expanded based on contract implementations).

## Getting Started

### Prerequisites
- **Node.js** (v16+)
- **Clarinet CLI** - [Installation guide](https://docs.stacks.co/clarinet)
- **Git**

### Installation

```bash
# Clone the repository
git clone <repository-url>
cd stacks-tapit

# Install dependencies for games module
cd games
npm install

# Install dependencies for tapit module
cd ../tapit
npm install
```

### Running Tests

```bash
# Test games contracts
cd games
npm run test                 # Run all tests
npm run test:watch          # Watch mode with coverage
npm run test:report         # Generate coverage report

# Test tapit contracts
cd ../tapit
npm run test
```

### Development Workflow

```bash
# Start Clarinet development environment
clarinet console

# In the Clarinet console:
(contract-call? .coin-toss-game create-game u10000000)
```

## Contract Architecture Patterns

### Data Management
- **Data Variables**: Track global state (counters, pools, totals)
- **Maps**: Store structured data (games, groups, member histories)
- **Error Codes**: Consistent error handling (u1-u9 range)

### Security Patterns
- Principal-based access control
- STX transfer validation with error handling
- Guard assertions for pre-condition checks
- Immutable game state transitions

### Function Organization
- **Public Functions**: State-modifying operations (begin with `define-public`)
- **Read-Only Functions**: Query operations (begin with `define-read-only`)
- **Private Functions**: Internal utilities (begin with `define-private`)

## Error Codes Reference

### Common Error Codes
| Code | Description |
|------|-------------|
| u1 | Invalid group/game ID |
| u2 | Insufficient stake amount |
| u3 | Group/game not active |
| u4 | Member/player not found |
| u5 | Unauthorized access |
| u6 | Invalid stake amount |
| u7 | Duplicate member |
| u8 | History not found |
| u9 | Transfer failed |

## Key Technologies

- **Clarity**: Smart contract language for Stacks
- **Stacks Blockchain**: Layer-1 smart contract platform for Bitcoin
- **Vitest**: Unit testing framework
- **Clarinet**: Development environment and testing framework
- **TypeScript**: Test suite language

## Configuration

### Network Settings

Edit the appropriate settings file:

```toml
# games/settings/Devnet.toml
[network]
name = "devnet"
node_rpc_address = "http://localhost:20443"
```

Available configurations:
- `Devnet.toml` - Local development
- `Testnet.toml` - Stacks Testnet
- `Mainnet.toml` - Stacks Mainnet

## API Reference

### CoinTossingGame Functions

```clarity
;; Create and manage coin toss games
(create-game (stake-amount uint))
(fund-game (game-id uint))
(flip-coin (game-id uint) (guess bool))
(claim-winnings (game-id uint))
(cancel-game (game-id uint))

;; Queries
(get-game-details (game-id uint))
(get-active-games-count)
(get-player-win-rate (player principal))
```

### PingPong Functions

```clarity
;; Game management
(create-game (opponent principal) (stake-amount uint))
(join-game (game-id uint) (stake-amount uint))
(play-round (game-id uint) (move uint))
(end-game (game-id uint) (result bool))

;; Powerup system
(grant-powerup (game-id uint) (player principal) (powerup-type uint))
(use-powerup (game-id uint) (powerup-id uint))

;; Withdrawals
(claim-timeout-refund (game-id uint))
(withdraw-dev-fees)

;; Queries
(get-game-state (game-id uint))
(get-player-stats (player principal))
(get-active-games (player principal))
```

## Contributing

1. Create a feature branch: `git checkout -b feature/new-contract`
2. Implement contract changes
3. Add comprehensive tests in `tests/` directory
4. Ensure all tests pass: `npm run test`
5. Commit with meaningful messages
6. Push and create a pull request

## Testing

Tests are written in TypeScript using Vitest and the Clarinet SDK:

```typescript
// Example test structure
describe("CoinTossingGame", () => {
  it("should create a game", () => {
    const wallet = accounts.deployer;
    const response = simnet.callPublicFn(
      "coin-toss-game",
      "create-game",
      [Cl.uint(10000000)],
      wallet.address
    );
    expect(response.result).toBeOk();
  });
});
```

## Deployment

### Testnet Deployment

```bash
cd games
clarinet deploy --testnet
```

### Mainnet Deployment

```bash
# IMPORTANT: Ensure thorough testing before mainnet deployment
clarinet deploy --mainnet
```

## Performance Considerations

- **Map Size Limits**: Lists capped at 1,000 items per map entry
- **Block Time**: ~10 minutes per Stacks block
- **Transaction Cost**: Varies based on bytecode size
- **Gas Optimization**: Use efficient map queries and avoid nested loops

## Monitoring & Debugging

```bash
# View contract calls in development
clarinet console

# Check transaction history
(contract-call? .coin-toss-game get-active-games-count)

# Debug with detailed output
npm run test:report
```

## Known Limitations

- Maximum list size: 1,000 members per group/game
- Map iteration not natively supported (requires manual tracking)
- No cross-contract calls to external protocols (planned for future versions)
- Single STX denomination (no other tokens currently)

## Roadmap

- [ ] Multi-token support (sNS, others)
- [ ] Cross-contract composability
- [ ] Advanced powerup mechanics
- [ ] Tournament bracket system
- [ ] DAO governance layer
- [ ] Mainnet launch

## Security Audits

Current Status: **In Development** - Not audited for production

Before mainnet deployment:
- [ ] Internal code review
- [ ] Security audit by third party
- [ ] Formal verification of critical functions
- [ ] Community testing on testnet

## Resources

- [Stacks Documentation](https://docs.stacks.co/)
- [Clarity Language Guide](https://docs.stacks.co/clarity)
- [Clarinet Documentation](https://docs.stacks.co/clarinet)
- [Stacks GitHub](https://github.com/stacks-network)

## Support

- **Issues**: Report bugs via GitHub Issues
- **Discussions**: Join [Stacks Discord](https://discord.gg/stacks)
- **Documentation**: See `docs/` folder for detailed guides

## License

ISC License - See LICENSE file for details

## Disclaimer

These contracts are provided as-is for educational and development purposes. Use at your own risk. Always conduct thorough security audits before deploying to mainnet with real assets.

---

**Last Updated:** December 19, 2025  
**Project Version:** 1.0.0  
**Clarity Version:** 3.0+  
**Stacks Network:** Compatible with Stacks 2.4+
