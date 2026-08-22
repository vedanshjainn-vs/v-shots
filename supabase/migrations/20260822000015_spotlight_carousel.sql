-- ═════════════════════════════════════════════════════════════════════════════
-- V Shots — 00015 Daily Spotlight carousel
-- ═════════════════════════════════════════════════════════════════════════════
-- Owner request (2026-08-22): the Daily Spotlight hero should auto-rotate
-- through MULTIPLE cards chosen from the admin panel (e.g. Top 100 Songs
-- India + Top Weekly Hindi). Sections flagged is_spotlight=true are rendered
-- in the auto-sliding carousel at the top of Home (in their sort order) and
-- are EXCLUDED from the regular horizontal shelf list (no duplicates).
--
-- Non-destructive: adds one nullable-free column with a safe default;
-- pre-flags the existing Top 100 Songs India hero so the current look is
-- preserved on first upgrade.
-- ═════════════════════════════════════════════════════════════════════════════

ALTER TABLE home_layout_config
  ADD COLUMN IF NOT EXISTS is_spotlight boolean NOT NULL DEFAULT false;

-- Preserve the existing hero: Top 100 Songs India stays the first spotlight
-- card until the owner flags more sections in the admin panel.
UPDATE home_layout_config
SET is_spotlight = true
WHERE id = 'top100_india';
