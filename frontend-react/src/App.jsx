import { useEffect, useState } from "react";
import { BrowserProvider, Contract, formatEther } from "ethers";
import "./App.css";

const CONTRACT = "0xF5Ac6e16A620db314463F7fB9C707E9c070C2120";
const SEPOLIA_HEX = "0xaa36a7";
const ABI = [
  "function isMember(address) view returns (bool)",
  "function mintPrice() view returns (uint256)",
  "function join() payable",
  "function nextTokenId() view returns (uint256)",
  "function ownerOf(uint256) view returns (address)",
  "function tokenURI(uint256) view returns (string)",
];

const ipfs = (u) =>
  u && u.startsWith("ipfs://") ? "https://ipfs.io/ipfs/" + u.slice(7) : u;

// Gradient generated from the wallet address, used when there is no NFT image
function avatarStyle(addr) {
  const h1 = parseInt(addr.slice(2, 8), 16) % 360;
  const h2 = parseInt(addr.slice(8, 14), 16) % 360;
  return {
    background: `linear-gradient(135deg, hsl(${h1} 70% 55%), hsl(${h2} 70% 40%))`,
  };
}

// Finds the token owned by this wallet and reads its metadata
async function loadNft(c, addr) {
  const total = Number(await c.nextTokenId());
  const owners = await Promise.all(
    Array.from({ length: total }, (_, i) => c.ownerOf(i).catch(() => null))
  );
  const id = owners.findIndex((o) => o && o.toLowerCase() === addr.toLowerCase());
  if (id === -1) return null;
  const nft = { id, name: "Membership #" + id, image: null };
  try {
    const uri = await c.tokenURI(id);
    const meta = await (await fetch(ipfs(uri))).json();
    nft.name = meta.name || nft.name;
    nft.image = ipfs(meta.image);
  } catch {
    // no readable metadata: the avatar fallback is shown instead
  }
  return nft;
}

export default function App() {
  const [contract, setContract] = useState(null);
  const [account, setAccount] = useState(null);
  const [price, setPrice] = useState("…");
  const [isMember, setIsMember] = useState(false);
  const [nft, setNft] = useState(null);
  const [imgFailed, setImgFailed] = useState(false);
  const [status, setStatus] = useState({ text: "", err: false });
  const [joining, setJoining] = useState(false);

  const say = (text, err = false) => setStatus({ text, err });

  useEffect(() => {
    if (!window.ethereum) return;
    const reload = () => window.location.reload();
    window.ethereum.on("accountsChanged", reload);
    window.ethereum.on("chainChanged", reload);
    return () => {
      window.ethereum.removeListener("accountsChanged", reload);
      window.ethereum.removeListener("chainChanged", reload);
    };
  }, []);

  async function refresh(c, addr) {
    const member = await c.isMember(addr);
    setIsMember(member);
    say(
      member
        ? "Connected: " + addr
        : "Connected: " + addr + " (not a member yet)"
    );
    if (member) setNft(await loadNft(c, addr));
  }

  async function connect() {
    if (!window.ethereum) return say("No wallet found. Install MetaMask.", true);
    try {
      await window.ethereum.request({ method: "eth_requestAccounts" });
      try {
        await window.ethereum.request({
          method: "wallet_switchEthereumChain",
          params: [{ chainId: SEPOLIA_HEX }],
        });
      } catch {
        return say("Please switch your wallet to the Sepolia network.", true);
      }
      const provider = new BrowserProvider(window.ethereum);
      const signer = await provider.getSigner();
      const addr = await signer.getAddress();
      const c = new Contract(CONTRACT, ABI, signer);
      setContract(c);
      setAccount(addr);
      setPrice(formatEther(await c.mintPrice()));
      await refresh(c, addr);
    } catch (e) {
      say(e.shortMessage || e.message, true);
    }
  }

  async function join() {
    setJoining(true);
    try {
      say("Confirm the transaction in your wallet…");
      const tx = await contract.join({ value: await contract.mintPrice() });
      say("Waiting for confirmation…");
      await tx.wait();
      await refresh(contract, account);
    } catch (e) {
      say(e.reason || e.shortMessage || e.message, true);
    }
    setJoining(false);
  }

  return (
    <main>
      <h1>Membership Club</h1>
      <p className="sub">Sepolia testnet &middot; {price} ETH to join</p>

      {!account && <button onClick={connect}>Connect wallet</button>}
      {account && !isMember && (
        <button onClick={join} disabled={joining}>
          Join the club
        </button>
      )}
      <div id="status" className={status.err ? "err" : ""}>
        {status.text}
      </div>

      {isMember && (
        <section id="vault">
          <div className="nft">
            {nft?.image && !imgFailed ? (
              <img src={nft.image} alt={nft.name} onError={() => setImgFailed(true)} />
            ) : (
              <div className="avatar" style={avatarStyle(account)}>
                {account.slice(2, 4).toUpperCase()}
              </div>
            )}
            <div>
              <h2>{nft ? nft.name : "Members only"}</h2>
              <span className="tag">Members only</span>
            </div>
          </div>
          <p>
            Welcome in. This section renders only because{" "}
            <code>isMember()</code> returned true for your wallet. Replace this
            text with your gated content.
          </p>
        </section>
      )}
    </main>
  );
}
