// AgentGate frontend — plain JS + ethers v5 (UMD global).
// Reads work without a wallet (public RPC). Writes need window.ethereum and
// the user confirms every transaction in their own wallet. No QR pairing,
// no session storage, no credentials are ever requested.
(function () {
  "use strict";

  const statusEl = document.getElementById("status");
  const listEl = document.getElementById("campaignList");
  const connectBtn = document.getElementById("connectBtn");
  const walletInfoEl = document.getElementById("walletInfo");
  const noticeEl = document.getElementById("deployNotice");
  const contractAddrEl = document.getElementById("contractAddr");

  const readProvider = new ethers.providers.JsonRpcProvider(CONFIG.rpcUrl);
  let signer = null;
  let account = null;
  let gateRead = null;
  let registryRead = new ethers.Contract(CONFIG.agentIdRegistry, REGISTRY_ABI, readProvider);

  function setStatus(msg, kind) {
    statusEl.innerHTML = msg ? `<span class="${kind || ""}">${msg}</span>` : "";
  }

  function shortAddr(a) {
    return a.slice(0, 6) + "…" + a.slice(-4);
  }

  function fmtDate(ts) {
    return new Date(ts * 1000).toLocaleString();
  }

  function campaignBadge(c) {
    const now = Math.floor(Date.now() / 1000);
    if (c.closed) return '<span class="badge closed">Closed</span>';
    if (now >= c.deadline.toNumber()) return '<span class="badge closed">Expired</span>';
    if (c.registrantCount.gte(c.maxSlots)) return '<span class="badge full">Full</span>';
    return '<span class="badge open">Open</span>';
  }

  function isOpen(c) {
    const now = Math.floor(Date.now() / 1000);
    return !c.closed && now < c.deadline.toNumber() && c.registrantCount.lt(c.maxSlots);
  }

  async function loadCampaigns() {
    if (!gateRead) {
      listEl.innerHTML = '<p class="muted">The AgentGate contract is not deployed yet. Check back after launch.</p>';
      return;
    }
    try {
      const count = (await gateRead.campaignCount()).toNumber();
      if (count === 0) {
        listEl.innerHTML = '<p class="muted">No campaigns yet. Be the first to create one below.</p>';
        return;
      }
      listEl.innerHTML = "";
      // Newest first.
      for (let id = count - 1; id >= 0; id--) {
        const c = await gateRead.getCampaign(id);
        const row = document.createElement("div");
        row.className = "campaign";
        let registeredMark = "";
        if (account) {
          try {
            if (await gateRead.isRegistered(id, account)) registeredMark = ' <span class="badge open">You are registered</span>';
          } catch (e) { /* ignore */ }
        }
        row.innerHTML =
          `<div><h3>${escapeHtml(c.name)}${campaignBadge(c)}${registeredMark}</h3>` +
          `<div class="meta">Slots: ${c.registrantCount.toString()} / ${c.maxSlots.toString()} &middot; ` +
          `Deadline: ${fmtDate(c.deadline.toNumber())} &middot; ` +
          `Creator: <span class="addr">${shortAddr(c.creator)}</span></div></div>` +
          `<div class="actions">` +
          `<button data-view="${id}" class="secondary">View</button>` +
          `<button data-register="${id}" ${isOpen(c) && account ? "" : "disabled"}>Register</button>` +
          `</div>`;
        listEl.appendChild(row);
      }
      listEl.querySelectorAll("[data-view]").forEach((b) =>
        b.addEventListener("click", () => showDetail(parseInt(b.dataset.view, 10))));
      listEl.querySelectorAll("[data-register]").forEach((b) =>
        b.addEventListener("click", () => doRegister(parseInt(b.dataset.register, 10))));
    } catch (err) {
      listEl.innerHTML = `<p class="muted">Could not load campaigns: ${escapeHtml(err.message || err)}</p>`;
    }
  }

  function escapeHtml(s) {
    return String(s).replace(/[&<>"']/g, (ch) =>
      ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[ch]));
  }

  async function showDetail(id) {
    const sec = document.getElementById("detailSection");
    const title = document.getElementById("detailTitle");
    const body = document.getElementById("detailBody");
    const regList = document.getElementById("registrantList");
    try {
      const c = await gateRead.getCampaign(id);
      title.textContent = c.name + " ";
      title.insertAdjacentHTML("beforeend", campaignBadge(c));
      body.innerHTML =
        `<table>` +
        `<tr><td>Campaign ID</td><td>${id}</td></tr>` +
        `<tr><td>Creator</td><td class="addr">${c.creator}</td></tr>` +
        `<tr><td>Slots</td><td>${c.registrantCount.toString()} / ${c.maxSlots.toString()}</td></tr>` +
        `<tr><td>Deadline</td><td>${fmtDate(c.deadline.toNumber())}</td></tr>` +
        `<tr><td>Metadata</td><td class="addr">${escapeHtml(c.metadataURI || "—")}</td></tr>` +
        `</table>` +
        (account && c.creator.toLowerCase() === account.toLowerCase() && !c.closed
          ? `<p><button id="closeBtn">Close campaign</button></p>` : "");
      const closeBtn = document.getElementById("closeBtn");
      if (closeBtn) closeBtn.addEventListener("click", () => doClose(id));

      const total = c.registrantCount.toNumber();
      if (total === 0) {
        regList.textContent = "No registrants yet.";
      } else {
        const addrs = await gateRead.getRegistrants(id, 0, Math.min(total, 100));
        regList.innerHTML = addrs.map((a) => `<div class="addr">${a}</div>`).join("") +
          (total > 100 ? `<div class="muted">…and ${total - 100} more (paged on-chain).</div>` : "");
      }
      sec.style.display = "block";
      sec.scrollIntoView({ behavior: "smooth" });
    } catch (err) {
      setStatus("Could not load campaign: " + escapeHtml(err.message || err), "bad");
    }
  }

  document.getElementById("closeDetailBtn").addEventListener("click", () => {
    document.getElementById("detailSection").style.display = "none";
  });

  async function gateWrite() {
    if (!signer) throw new Error("Connect your wallet first.");
    return new ethers.Contract(CONFIG.contractAddress, GATE_ABI, signer);
  }

  async function doRegister(id) {
    try {
      setStatus("Sending registration… confirm in your wallet.");
      const gate = await gateWrite();
      const tx = await gate.register(id);
      setStatus(`Transaction sent: ${tx.hash} — waiting for confirmation…`);
      await tx.wait();
      setStatus("Registered! You hold a slot in this campaign.", "ok");
      loadCampaigns();
    } catch (err) {
      setStatus("Registration failed: " + escapeHtml(err.message || err), "bad");
    }
  }

  async function doClose(id) {
    try {
      setStatus("Closing campaign… confirm in your wallet.");
      const gate = await gateWrite();
      const tx = await gate.closeCampaign(id);
      setStatus(`Transaction sent: ${tx.hash} — waiting for confirmation…`);
      await tx.wait();
      setStatus("Campaign closed.", "ok");
      showDetail(id);
      loadCampaigns();
    } catch (err) {
      setStatus("Close failed: " + escapeHtml(err.message || err), "bad");
    }
  }

  document.getElementById("createForm").addEventListener("submit", async (e) => {
    e.preventDefault();
    if (!CONFIG.contractAddress) {
      setStatus("The contract is not deployed yet — creating campaigns is disabled.", "bad");
      return;
    }
    const name = document.getElementById("fName").value.trim();
    const slots = parseInt(document.getElementById("fSlots").value, 10);
    const deadlineMs = new Date(document.getElementById("fDeadline").value).getTime();
    const meta = document.getElementById("fMeta").value.trim();
    if (!name || !slots || slots < 1 || !deadlineMs || deadlineMs <= Date.now()) {
      setStatus("Check the form: name, slots ≥ 1, and a future deadline are required.", "bad");
      return;
    }
    try {
      setStatus("Creating campaign… confirm in your wallet.");
      const gate = await gateWrite();
      const tx = await gate.createCampaign(name, slots, Math.floor(deadlineMs / 1000), meta);
      setStatus(`Transaction sent: ${tx.hash} — waiting for confirmation…`);
      const receipt = await tx.wait();
      setStatus("Campaign created!", "ok");
      document.getElementById("createForm").reset();
      loadCampaigns();
    } catch (err) {
      setStatus("Create failed: " + escapeHtml(err.message || err), "bad");
    }
  });

  async function updateWalletInfo() {
    if (!account) {
      walletInfoEl.innerHTML = "";
      return;
    }
    let line = `Connected: <span class="addr">${shortAddr(account)}</span>`;
    try {
      const bal = await registryRead.balanceOf(account);
      line += bal.gt(0)
        ? '<br><span class="ok">✔ Holds an Agent ID — can register</span>'
        : '<br><span class="bad">✘ No Agent ID found on this wallet</span>';
    } catch (e) {
      line += '<br><span class="muted">Could not check Agent ID status.</span>';
    }
    walletInfoEl.innerHTML = line;
  }

  connectBtn.addEventListener("click", async () => {
    if (!window.ethereum) {
      setStatus("No wallet found. Install MetaMask or Binance Wallet extension, then try again.", "bad");
      return;
    }
    try {
      const provider = new ethers.providers.Web3Provider(window.ethereum);
      await provider.send("eth_requestAccounts", []);
      const network = await provider.getNetwork();
      if (network.chainId !== CONFIG.chainId) {
        try {
          await window.ethereum.request({
            method: "wallet_switchEthereumChain",
            params: [{ chainId: "0x" + CONFIG.chainId.toString(16) }],
          });
        } catch (switchErr) {
          setStatus(`Please switch your wallet to ${CONFIG.chainName} (chain ${CONFIG.chainId}).`, "bad");
          return;
        }
      }
      signer = provider.getSigner();
      account = await signer.getAddress();
      connectBtn.textContent = shortAddr(account);
      setStatus("Wallet connected.", "ok");
      await updateWalletInfo();
      loadCampaigns();
    } catch (err) {
      setStatus("Connection failed: " + escapeHtml(err.message || err), "bad");
    }
  });

  if (window.ethereum) {
    window.ethereum.on("accountsChanged", () => window.location.reload());
    window.ethereum.on("chainChanged", () => window.location.reload());
  }

  // Init.
  if (!CONFIG.contractAddress) {
    noticeEl.textContent =
      "AgentGate is not deployed on BNB Chain yet — this page is in preview mode. Campaigns will appear here after launch.";
    noticeEl.classList.remove("hidden");
    contractAddrEl.textContent = "not deployed yet";
    document.getElementById("createBtn").disabled = true;
  } else {
    gateRead = new ethers.Contract(CONFIG.contractAddress, GATE_ABI, readProvider);
    contractAddrEl.innerHTML =
      `<a class="addr" href="${CONFIG.blockExplorer}/address/${CONFIG.contractAddress}" target="_blank" rel="noopener">${CONFIG.contractAddress}</a>`;
  }
  loadCampaigns();
})();
