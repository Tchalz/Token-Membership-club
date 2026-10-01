import { useEffect, useState } from "react";
import { BrowserProvider, Contract, formatEther } from "ethers";
import "./App.css";

const CONTRACT = "0xF5Ac6e16A620db314463F7fB9C707E9c070C2120";
const SEPOLIA_HEX = "0xaa36a7";
const ABI = [
  "function isMember(address) view returns (bool)",
  "function mintPrice() view returns (uint256)",
  "function join() payable",
];

export default function App() {
  const [contract, setContract] = useState(null);
  const [account, setAccount] = useState(null);
  const [price, setPrice] = useState("…");
  const [isMember, setIsMember] = useState(false);
  const [status, setStatus] = useState({ text: "", err: false });
  const [joining, setJoining] = useState(false);

  const say = (text, err = false) => setStatus({ text, err });

  // Reload the page when the wallet account or network changes
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
          <h2>Members only</h2>
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
