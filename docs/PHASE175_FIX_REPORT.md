# PHASE 17.5 FIX REPORT — "Har section Continue Listening ban jata hai"
**Date:** 2026-08-21
**User report:** Admin me koi bhi type select karo (jaise YouTube Playlist + link), save karo → app me wo section Continue Listening ban jata hai.

---

## ROOT CAUSE (do layers — dono fix)

**Layer 1 — APP (decisive):** `HomeFeedService._buildFromCms()` personalized key-map ko **type check ke pehle** lagata tha. Admin me "+ Personalized" (ya koi personalized section) ka `section_key` (jaise `continue_listening`) tab bhi row me rehta tha jab editor ne type badal diya — aur app key dekh kar hi shelf bana deta tha. Nataja: playlist/search/manual sab Continue Listening ban jaate the.

**Layer 2 — ADMIN:** type switch karne par stale `section_key` clear nahi hota tha; publish use wapas bhej deta tha. "+ Personalized" ka default bhi Continue Listening tha.

**Bonus bug (reproduction ke dauran mila):** jab saare personalized keys DB me already hain, "+ Personalized" duplicate `made_for_you` **id** bana deta tha → PostgREST error 21000 → **poora Publish fail** (atomic, koi partial write nahi).

## LIVE DB REPAIR (migration `20260821000010`, applied)

| Row | Pehle | Ab |
|---|---|---|
| `trending_now` | key=`continue_listening`, title "Continue Listening 💖" (accidentally converted) | canonical Trending Now (youtube_search, query restored) |
| `india_hits` | key=`continue_listening`, **tumhara playlist URL sahi tha** | key=`india_hits`, playlist URL intact |
| `jiosaavn_test` / `e2e_playlist_test` | key=`continue_listening` | keys fixed; hidden state preserved; e2e temp disabled |
| Remaining hijack rows | 4 | **0 (verified)** |

## FIXES

**App** (`5ee095f`): personalized key-map ab SIRF tab apply hota hai jab section ka type sach me `personalized` ho — source type wins. +4 regression tests (playlist/search/jiosaavn stale keys stay their types; personalized still maps). **398/398 tests, analyze/format clean, CI `32521743428` ✅**

**Admin** (`aa87307` → `1bf4e67`, production r8 live):
- Type switch par stale personalized key regenerate (editor save + publish-time guard dono pe)
- "+ Personalized" ab Made For You default; saare engines used hain to warning toast (duplicate id banane se mana)
- doPublish draft ids validate karta hai — duplicate ids par clear error, koi partial write nahi
- App-branch parity `0c21ffb`, CI `32523870390` ✅

## PRODUCTION PROOF (real deployed admin, no demo)

User ka exact flow headless Chrome se chalaya:
`+ Catalog → type YouTube Playlist → URL paste → title → Save → Publish`

| Check | Result |
|---|---|
| India Hits card = **Catalog** badge (Continue nahi) | ✅ |
| Naya section save → card key `home_…` (personalized nahi) | ✅ |
| Publish → DB row: `source_type=youtube_playlist`, `source_value=<URL>`, `section_key=home_mt3eobli`, visible+published | ✅ |
| Earlier failed-publish attempt ne kuch nahi likha (atomic) | ✅ |
| Cleanup (test row hidden+unpublished) | ✅ |
| 0 JS errors | ✅ |

Screenshots: `device-test/phase175-qa/` (00-02).

## APP PAR ANDAR AB KYA DIKHEGA

Live DB ab correct hai: **Continue Listening (auto) → Made For You → India Hits (tumhari playlist) → Because You Listened To → Punjabi → Hindi Indie → International Pop → Chill & LoFi**. Note: data fix ki wajah se **purana APK bhi ab sahi dikhayega**; app-side fix future admin edits ke liye hai (naye APK me, CI `32523870390`).

## COMMITS

- App: `5ee095f` (app fix + migration) → `0c21ffb` (admin parity) — CI `32523870390` ✅
- Deploy: `aa87307` → `1bf4e67` — Pages live **`v=20260821-r8`** ✅
- `main` untouched · no force-push
