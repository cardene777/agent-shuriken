# The entry point of a natural explanation

A standard for not starting text that explains a product, a feature, or a mechanism with a definition sentence that is correct but mechanical.

## The order in which readers first take things in

In the introduction of an explanation, put an event the reader can picture before the category name.

1. Who is trying to do what.
2. If they go ahead as they are, where the answer or the judgment splits.
3. What the product or the mechanism lets them keep, separate, or check.

In this order, the reader can judge when they themselves would use it before learning the name.
Do not dramatize the event. Briefly pick one scene that is specific to the subject and actually happens.

## Do not start with only a category word

Sentences like the following are grammatically correct, but they do not convey any movement to the reader.

```text
Xは、Yのための機能です。
Xは、Yを支援するツールです。
Xは、Yの進め方です。
```

(The three lines read "X is a feature for Y.", "X is a tool that supports Y.", and "X is a way of working for Y.")

`機能` ("feature"), `ツール` ("tool"), `仕組み` ("mechanism"), and `進め方` ("way of working") only show the kind of the subject; they do not explain who does what.
In the introduction, cut them, or use them as a supplement after explaining the concrete action.

```text
悪い例: Kiro Specsは、AI開発の進め方です。
良い例: Kiro Specsでは、利用者に何が起きるかを書いてから、実装方法と作業を分けて残します。
```

(悪い例 is the bad example: "Kiro Specs is a way of doing AI development." 良い例 is the good example: "In Kiro Specs, you first write what happens to the user, and then keep the implementation approach and the tasks separately.")

However, for glossaries, API references, and definition sentences in specifications, showing the category first suits the reader's purpose better.
Do not apply this standard uniformly to every explanation.

## Building the introduction

Limit a paragraph to one scene, with three sentences as a guide.

```text
AIに「夜は通知しない」と頼んでも、それだけでは実装が決まりません。
緊急通知を通すか、旅行中の利用者の時刻をどう扱うかで、答えが分かれます。
Kiro Specsでは、こうした約束を先に書き、実装方法と作業を別に残します。
```

(The three lines read: "Even if you ask an AI for 'no notifications at night,' that alone does not settle the implementation." "The answer splits on whether urgent notifications get through and how to handle the time of a user who is traveling." "In Kiro Specs, you write promises like these first, and keep the implementation approach and the tasks separately.")

Give each sentence a different role.

| Sentence | Role |
| --- | --- |
| 1st sentence | Put a scene the reader knows |
| 2nd sentence | Show concretely what is undecided |
| 3rd sentence | Give the name, and write the operation the subject performs |

Do not start with a generalization that still holds when the subject is swapped, such as 「AIに実装を頼むと、コードは早く書けます」 ("If you ask an AI to implement something, the code gets written fast").
Go straight into a scene that only that text has.

## Checks after writing

- With the product name and the category word hidden, can you still tell who is deciding what?
- Are `機能`, `ツール`, `仕組み`, or `進め方` used in place of an explanation of the action?
- Are terms the reader does not know placed before the scene or the action?
- If the first sentence would still work with a different product name swapped in, rewrite it into a scene specific to the subject.
