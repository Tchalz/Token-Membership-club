# Token Membership Club

A token-gated membership system on Ethereum. Pay 0.01 ETH, receive a membership NFT, and unlock members-only content in the web app. The wallet is the login and the NFT is the membership card, so there are no accounts or passwords.

**Live app:** https://token-membership-club.vercel.app
**Contract (Sepolia):** [`0xF5Ac6e16A620db314463F7fB9C707E9c070C2120`](https://sepolia.etherscan.io/address/0xF5Ac6e16A620db314463F7fB9C707E9c070C2120) (source verified)

> Testnet prototype. It runs on Sepolia with free test ETH and has not been audited. Do not deploy to mainnet with real funds without a security audit.

## How it works

1. A visitor connects MetaMask. The app switches them to Sepolia.
2. If they aren't a member, they click **Join the club** and pay the mint price.
3. The contract's `join()` mints them a membership NFT.
4. The app calls `isMember(address)`, which returns true when the wallet holds the NFT, and reveals the members-only section along with the member's NFT.

## Smart contract

`src/MembershipClub.sol` is an ERC-721 built on OpenZeppelin (`ERC721URIStorage`, `Ownable`, `Pausable`).

| Feature | Detail |
|---|---|
| Mint price | 0.01 ETH, adjustable by the owner (`setMintPrice`) |
| Supply cap | 500, can be raised but never below tokens already minted (`setMaxSupply`) |
| One per wallet | `hasMinted` blocks re-joining, even if the NFT is transferred away |
| Overpayment | Any ETH above the mint price is refunded |
| Access check | `isMember(address)` returns true if the wallet holds a membership NFT |
| Owner controls | `withdraw`, `pause` / `unpause`, `setBaseTokenURI` |

Token metadata URIs are `baseTokenURI + tokenId`, saved at mint time. Changing `baseTokenURI` later affects only future mints.

## Project structure

```
src/             MembershipClub.sol
test/            Foundry tests
script/          Deploy.s.sol (deployment script)
frontend-react/  React + Vite web app (ethers v6)
.github/         CI workflow (format, build, test)
```

## Getting started

Requires [Foundry](https://book.getfoundry.sh/) and Node.js.

```bash
git clone https://github.com/Tchalz/Token-Membership-club.git
cd Token-Membership-club
git submodule update --init --recursive
```

### Contracts

```bash
forge build
forge test
forge fmt --check
```

### Deploy

The script reads one optional environment variable, `BASE_TOKEN_URI`, the base link for NFT metadata. It must end with `/`, for example `ipfs://<FOLDER_CID>/`. If it is unset, the contract deploys with an empty base URI and tokens have no real metadata.

```bash
export BASE_TOKEN_URI="ipfs://<FOLDER_CID>/"

forge script script/Deploy.s.sol \
  --rpc-url <SEPOLIA_RPC_URL> \
  --account <KEYSTORE_NAME> \
  --broadcast
```

The script does not read a private key from the environment. The deployer is chosen on the command line, preferably with an encrypted keystore (`cast wallet import <KEYSTORE_NAME> --interactive`) rather than `--private-key`. Never commit a `.env` file or a private key.

### Frontend

```bash
cd frontend-react
npm install
npm run dev
```

Open http://localhost:5173. To point the app at your own deployment, update `CONTRACT` in `frontend-react/src/App.jsx`.

## Trying it

You need MetaMask and Sepolia ETH (free from any Sepolia faucet): at least 0.01 ETH plus gas. On mobile, open the site inside the MetaMask app's built-in browser, because regular mobile browsers have no wallet.

MetaMask may show a phishing warning for new `.vercel.app` domains. This is a common false positive for new sites.

## Known limitations

- Existing tokens have a placeholder `tokenURI` (`"0"`), so the app shows a generated avatar instead of a real NFT image.
- The members-only section holds placeholder content.
- Membership is checked in the frontend only. Gating content elsewhere (for example a Discord role) needs separate verification.
- Not audited.

## Possible next steps

- Real NFT artwork and metadata hosted on IPFS
- Real gated content behind the membership check
- Discord or server-side access enforcement
- Security audit before any mainnet deployment

## License

MIT
