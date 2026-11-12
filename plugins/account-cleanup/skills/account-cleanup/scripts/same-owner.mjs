// Groups of domains owned by the same company that share a sign-in page.
// A 1Password item may hold only one of the domains, and login would refuse to fill in when the sign-in page is on the other one.
// Add only groups confirmed to have the same operator: adding a group allows credentials to be filled in on pages of any domain in it.
export const SAME_OWNER = [
  // Blizzard account sign-in is on battle.net
  ["blizzard.com", "battle.net"],
  // Blockworks acquired Messari, and Messari sign-in moved to auth.blockworks.com
  ["messari.io", "blockworks.com"],
  // Paragraph moved from paragraph.xyz to paragraph.com, and the old domain redirects to the new one
  ["paragraph.xyz", "paragraph.com"],
];

// Return the item's domains plus the domains owned by the same company
export function withSameOwner(sites) {
  const out = new Set(sites);
  for (const group of SAME_OWNER) {
    if (group.some((d) => out.has(d))) for (const d of group) out.add(d);
  }
  return [...out];
}
