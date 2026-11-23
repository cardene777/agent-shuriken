# Spoken Japanese that sounds natural to the ear

Rules for writing scripts and speech scripts.
Each rule comes with a source for why it is written that way.
The default style is a polite way of talking like a radio host, and when the caller asks for another style, follow that.

## Finish each sentence

- Carry each sentence through to its predicate. Do not end a sentence on a particle, as in 「〜の話を。」 ("the story of ~.") or 「〜について。」 ("about ~.").
- Inversion that moves a noun phrase after the predicate is allowed. As in 「困りますね、言い回しまで同じになると。」 ("It's a problem, when even the phrasing becomes the same."), first finish with 「です」 or 「ます」, then add the rest.
- Trailing-off sentences such as 「〜んですけど。」 ("~, but.") or 「〜ので。」 ("because ~.") may be used when you leave the rest to the other person. Trailing off happens normally in speech (Yokomori 2011).
- Listing three or more things as 「〜する、〜する、〜する、といったもの」 ("does ~, does ~, does ~, and things like that") sounds like reading out a bulleted list. Group them as 「〜ことや、〜こと、〜ことがあります」 ("there is ~, ~, and ~"), or split the sentence.
- Put one new piece of information in a sentence, and keep a sentence to about 40 characters. For narration, 30 to 40 characters per sentence is a guide (@SOHO).
- Do not cut sentences too short. A row of only short sentences sounds like a telegram (NHK Science & Technology Research Laboratories, Tanaka and Mino 2011).

## Ask questions politely

- End a polite question with 「〜ませんか？」 or 「〜ですか？」, and do not drop 「か」.
- Use a question to voice, on behalf of the listeners, a doubt they are likely to have. The asking role stands in for the listeners, and it is not a role that quizzes an expert (NPR two-way).
- The speaker who knows a term explains its meaning by rephrasing it within the flow of the talk. Do not have the partner ask 「〜というのは、どういう〜ですか？」 ("what kind of ~ is ~?").

## Use polite spoken words

- Do not use contractions. Say 「〜てしまう」「では」「ですよね」「ようです」.
- Do not use written-language sentence endings or the continuative suspended form (連用中止). Say 「である」「であり、」「12あり、」「〜しており、」「における」 as 「です」「で」「12あって」「〜していて」「での」. The continuative suspended form is used a lot in written language (MIT written-language lessons).
- Homophones, and words with four or more Sino-Japanese (on-reading) kanji in a row, are hard to tell apart by ear, so open them up into native Japanese words (Agency for Cultural Affairs, 『公用文作成の考え方』 2022).
- Repeat the same word rather than rephrasing it. Listeners cannot look back at an earlier word (NPR Would you say it that way).
- In one utterance, do not use empty words such as 「所」「こと」「もの」「ある」 three times. This is different from repeating a noun that points to the same thing. When light words pile up, the listener cannot catch what they refer to.
- Do not translate established loanwords (バージョン、ファイル、ツール) ("version", "file", "tool") into native Japanese.

## Say hearsay in hearsay form

- Close facts taken from a source with 「〜ようです」「〜ということです」「〜としています」「〜と書かれています」 ("it seems", "it is said that", "~ states that", "it is written that"). NHK news also uses 「ということです」 and 「としています」 as set sentence endings (Tanaka et al. 2015).
- Do not assert advice or effects outright. Say 「見本を見せる方が効くようです」 ("showing an example seems to work better"), not 「見本を見せるのが効きます」 ("showing an example works").
- Do not say it more strongly than the source. If the source says 「特定の操作を防げた」 ("it prevented certain operations"), do not say 「入れるだけで防げる」 ("just adding it prevents them").
- Name a source by its actual type and name. Say 「公式ドキュメント」 ("the official documentation"), 「研究チームの論文」 ("the research team's paper"), or 「エヌピーアールの報道」 ("NPR's reporting"), and do not blur it as 「手引き」 ("a guide") or 「ある記事」 ("an article").
- When you state your own view, show the speaker with 「〜と思います」 ("I think ~"), and keep it apart from facts.

## Make it a conversation

- Include back-channel responses. In TV interviews they come about once every 10 seconds (Komiya 1986, cited in the review by Chen 2002). Besides 「ええ」「なるほど」「そうなんですね」, respond by repeating the other person's words.
- Attach the sentence-final particles 「ね」「よ」「よね」 to the polite style. In everyday conversation, 「ね」 is 7 times and 「よ」 is 4 times more frequent than in written language (Hara 2026, comparing the Corpus of Everyday Japanese Conversation with a written-language corpus).
- Vary the length of utterances. Mix short responding utterances with long explaining ones. In real chats, 23% of utterances are 4 characters or fewer (check_spontaneity.py in kaburi-tts).
- You may use joint utterances, where one speaker takes up and completes what the other started to say (Hayashi 2003).
- Do not make the speakers agree on everything. Include one difference in views (Pacific Content).
- When you change topics, use 「そういえば」「で、」「〜といえば」 ("by the way", "so,", "speaking of ~"), and do not use the same set phrase every time (Makihara).
- Do not use the same sentence ending three times in a row.
- Do not start every responding utterance with the same back-channel word. After responding with 「ええ。」, respond next with a repeat of the other person's words or with a different back-channel word.
- Do not restate what the other person just said in almost the same words. When the discussion repeats a point that was read out, rephrase it briefly or add your own take on it.
- Do not attach 「ね」 or 「よね」 to every line. Do not use 「ね」 twice in one utterance.
- Use a comparison to a familiar thing at most once per topic, and do not use a comparison of the same type as in the previous topic.
- Close a topic only after taking up what the other person just said.
- In the opening preview, do not pack the topics into one utterance. Split the sentences by topic.
- Do not invent the speakers' real experiences (things they ate, places they went).

## Follow the caller's constraints

- The number of characters per line, whether Latin letters and symbols are not allowed, and whether readings are written in kana all follow the caller's constraints.
- When the voice generator does not convert numbers into readings, write numbers whose reading can vary in kana. Irodori-TTS does not convert numbers into readings (text_normalization.py in Irodori-TTS).

## Sources

- 横森大輔 (Yokomori Daisuke) 2011, 「言いさし」 ("trailing off") https://www2.ninjal.ac.jp/past-events/2009_2021/event/specialists/project-meeting/files/20111217-043re/20111217_yokomori.pdf
- 田中・美野 (Tanaka and Mino) 2011 (NHK Science & Technology Research Laboratories) https://www.anlp.jp/proceedings/annual_meeting/2011/pdf_dir/B3-8.pdf
- 田中ほか (Tanaka et al.) 2015 (sentence endings in NHK news) https://anlp.jp/proceedings/annual_meeting/2015/pdf_dir/E5-2.pdf
- NPR Reporter two-ways https://www.npr.org/sections/npr-training/2025/05/28/g-s1-67598/reporter-two-ways-how-to-sound-natural-even-with-a-script
- NPR Would you say it that way https://www.npr.org/sections/npr-training/2025/05/31/g-s1-66074/would-you-say-it-that-way-tips-on-writing-for-your-voice
- 文化庁 (Agency for Cultural Affairs), 『公用文作成の考え方』 ("How to write official documents") 2022 https://www.bunka.go.jp/seisaku/bunkashingikai/kokugo/hokoku/pdf/93651301_01.pdf
- MIT 書き言葉レッスン (MIT written-language lessons, the continuative suspended form) https://web.mit.edu/kakikotoba/renyoo-chuushi.html
- 陳 (Chen) 2002 (a review of research on back-channel responses) https://www.dc.ocha.ac.jp/comparative-cultures/jle/saizensen/saizensen2002/PDF-kiji/02-ChenT-re051120-final.pdf
- 原 (Hara) 2026 (frequency of sentence-final particles) https://clrd.ninjal.ac.jp/lrw/lrw2026/lrw2026c3_paper.pdf
- Hayashi 2003 Joint Utterance Construction in Japanese Conversation https://benjamins.com/catalog/sidag.12
- 牧原 (Makihara) (topic changes) https://tsukuba.repo.nii.ac.jp/record/2003605/files/NCK_11-1.pdf
- Pacific Content (two hosts) https://pacific-content.com/double-acts-dynamic-duos-co-hosts/
- @SOHO (narration scripts) https://atsoho.com/blog/voice-over-script
- llm-jp/kaburi-tts (Apache-2.0) https://github.com/llm-jp/kaburi-tts
- Irodori-TTS (MIT) https://github.com/Aratako/Irodori-TTS
