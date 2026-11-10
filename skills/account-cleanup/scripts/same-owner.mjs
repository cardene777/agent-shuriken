// 同じ会社が持ち、ログインの画面を共有するドメインの組。
// 1Passwordの項目には片方のドメインだけが入っていることがあり、ログインの画面が別のドメインに在ると入力を断ってしまう。
// 運営会社が同じだと確かめた組だけを足す。足すと、その組のどちらのページにも値を入れてよいことになる。
export const SAME_OWNER = [
  // Blizzard のアカウントのログインは battle.net に在る
  ["blizzard.com", "battle.net"],
  // Blockworks が Messari を買い、Messari のログインは auth.blockworks.com に移った
  ["messari.io", "blockworks.com"],
  // Paragraph は paragraph.xyz から paragraph.com へ移り、旧ドメインは新ドメインへ転送する
  ["paragraph.xyz", "paragraph.com"],
];

// 項目のドメインの並びに、同じ会社が持つドメインを足して返す
export function withSameOwner(sites) {
  const out = new Set(sites);
  for (const group of SAME_OWNER) {
    if (group.some((d) => out.has(d))) for (const d of group) out.add(d);
  }
  return [...out];
}
