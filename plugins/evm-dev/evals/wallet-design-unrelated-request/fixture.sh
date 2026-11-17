#!/bin/bash
# Writes the project this case starts from: one frontend file that connects a wallet and switches
# its chain.
set -eu
mkdir -p src
cat > README.md <<'EOF'
# Tidepool frontend

`src/wallet.ts` connects the user's wallet.
EOF
cat > src/wallet.ts <<'EOF'
import { createWalletClient, custom } from "viem";
import { base } from "viem/chains";

export async function connectWallet() {
  const client = createWalletClient({ chain: base, transport: custom(window.ethereum!) });
  const [address] = await client.requestAddresses();
  await client.switchChain({ id: base.id });
  return { client, address };
}
EOF
