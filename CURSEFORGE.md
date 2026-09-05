# Notes for the CurseForge listing

## What their rules actually say about AI

Checked 2026-09-04 against the two documents that govern this.

**[Mod Authors Terms and Conditions](https://legal.overwolf.com/docs/curseforge/mod-authors-terms/)**
does not mention AI, machine learning or generated content anywhere. What it
does require is that you warrant you hold the rights to what you upload, and it
states plainly: *Mod Authors cannot copy+paste code, text or design from other
Mods on CurseForge.*

**[Moderation Policies](https://support.curseforge.com/support/solutions/articles/9000197279-moderation-policies)**
has one AI clause, headed **AI Misleading Content Disclosure**. It requires a
clear and visible disclaimer, on the image or in the description, for showcase
images that are AI generated, edited or enhanced and could misrepresent how the
mod actually looks.

So:

- **Disclosing AI-written code is not required.** Nothing forbids it either, so
  disclosing voluntarily is fine.
- **The image clause may apply to you.** The minimap button icon is AI
  generated. It is the addon's actual icon rather than a screenshot, so it does
  not misrepresent anything, but if it goes in the gallery as a showcase image
  the cheap and safe move is to say so in the caption.
- **Screenshots must be real.** Any in-game shots you upload should be actual
  captures, not AI touched up, or the clause bites for real.

One thing worth knowing, not a CurseForge rule: in the US, purely AI-generated
images are not currently copyrightable. That affects your ability to stop
someone else reusing the icon. It does not affect your right to ship it. Not
legal advice, just the reason not to be surprised.

## Paste-ready disclosure for the project description

> **How this addon was made**
>
> FarmMap was written with AI assistance. I directed the design, tested every
> version in game, and made every call about how it should behave. Claude
> (Anthropic) wrote the code and the tests. The minimap button icon was AI
> generated and then converted to a game texture.
>
> No code, text or design was copied from any other addon. Two existing addons
> were read while building this, GatherMate2 and Leatrix_Plus, to work out how
> the current minimap API behaves in practice. What came from them is factual
> knowledge about the API, not code.
>
> Source and full history: https://github.com/SnowMewKat/wow-farmmap (MIT)

The repo is public, so that source link resolves.

## Screenshots for the gallery

These have to come from Snow, because the addon only runs on her client.

- **They must be genuine captures.** Their AI clause is specifically about
  showcase images that were generated, edited or enhanced and could
  misrepresent how the mod looks. A real screenshot needs no disclaimer; an AI
  touched-up one does, and is not worth the trouble.
- **The shot that sells it** is mid-flight with nodes only on: ore and herb
  blips floating over the world with no map behind them. That is the whole
  pitch in one image, and it is hard to describe in words.
- **Worth including too:** the options panel, and a before and after pair
  showing the normal minimap versus the node view.
- Crop out anything personal: character name, guild chat, Battle.net friends,
  real names in the chat log. Chat is the usual culprit.
- 1920x1080 or larger, PNG or JPG.

## Listing details, already set in the TOC

| Field | Value |
|---|---|
| Category | Map & Minimap (`## X-Category`) |
| License | MIT (`## X-License`) |
| Website | the GitHub repo (`## X-Website`) |
| Game version | 12.1.0, from `## Interface: 120100` |
| Project slug | should be `farmmap`, to match the addon folder name |

## Uploading

Upload the zip from a release, not a hand-made one. `tools/package.py` builds it
with a single top-level `FarmMap` folder, which is the layout CurseForge and the
CurseForge app both expect, and it fails the build if that is ever not true.
