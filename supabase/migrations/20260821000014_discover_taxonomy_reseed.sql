-- V Shots — Phase 17.9: V SHOTS DISCOVER taxonomy reseed
-- Replaces the old Discover category rows with the owner-specified taxonomy:
--   A. Quick Explore (kind=source): For You / Trending / New Releases /
--      Rising Now / Surprise Me (For You + Surprise Me = engine sources)
--   B. Mood (10)  C. Language (12)  D. Genre (11)  E. Decades (4)
--   F. Activity (8)
-- Content rows only. Idempotent.

delete from public.discovery_categories;

insert into public.discovery_categories
  (id, name, emoji, query, fallback_category, sort_order, active, kind, token, ranking_order, visible, updated_at)
values
  ('for_you', 'For You', '🎯', '', 'global', 1, true, 'source', '', 'relevance', true, now()),
  ('trending', 'Trending', '🔥', 'trending songs official video 2026', 'global', 2, true, 'source', '', 'viewCount', true, now()),
  ('new', 'New Releases', '🆕', 'new music releases official audio 2026', 'global', 3, true, 'source', '', 'date', true, now()),
  ('rising_now', 'Rising Now', '📈', 'rising viral songs official audio 2026', 'global', 4, true, 'source', '', 'viewCount', true, now()),
  ('surprise_me', 'Surprise Me', '🎲', '', 'global', 5, true, 'source', '', 'relevance', true, now()),
  ('chill', 'Chill', '😌', 'chill', 'global', 10, true, 'mood', 'chill', 'relevance', true, now()),
  ('happy', 'Happy', '😄', 'happy', 'global', 11, true, 'mood', 'happy', 'relevance', true, now()),
  ('sad', 'Sad', '😢', 'sad', 'global', 12, true, 'mood', 'sad', 'relevance', true, now()),
  ('romantic', 'Romantic', '❤️', 'romantic', 'global', 13, true, 'mood', 'romantic', 'relevance', true, now()),
  ('energetic', 'Energetic', '⚡', 'energetic', 'global', 14, true, 'mood', 'energetic', 'relevance', true, now()),
  ('party', 'Party', '💃', 'party', 'global', 15, true, 'mood', 'party', 'relevance', true, now()),
  ('focus', 'Focus', '🎧', 'focus', 'global', 16, true, 'mood', 'focus', 'relevance', true, now()),
  ('sleep', 'Sleep', '😴', 'sleep', 'global', 17, true, 'mood', 'sleep', 'relevance', true, now()),
  ('workout', 'Workout', '🏋️', 'workout', 'global', 18, true, 'mood', 'workout', 'relevance', true, now()),
  ('devotional', 'Devotional', '🛕', 'devotional', 'global', 19, true, 'mood', 'devotional', 'relevance', true, now()),
  ('hindi', 'Hindi', '', 'hindi', 'global', 30, true, 'language', 'hindi', 'relevance', true, now()),
  ('punjabi', 'Punjabi', '', 'punjabi', 'global', 31, true, 'language', 'punjabi', 'relevance', true, now()),
  ('english', 'English', '', 'english', 'global', 32, true, 'language', 'english', 'relevance', true, now()),
  ('telugu', 'Telugu', '', 'telugu', 'global', 33, true, 'language', 'telugu', 'relevance', true, now()),
  ('tamil', 'Tamil', '', 'tamil', 'global', 34, true, 'language', 'tamil', 'relevance', true, now()),
  ('bhojpuri', 'Bhojpuri', '', 'bhojpuri', 'global', 35, true, 'language', 'bhojpuri', 'relevance', true, now()),
  ('haryanvi', 'Haryanvi', '', 'haryanvi', 'global', 36, true, 'language', 'haryanvi', 'relevance', true, now()),
  ('marathi', 'Marathi', '', 'marathi', 'global', 37, true, 'language', 'marathi', 'relevance', true, now()),
  ('bengali', 'Bengali', '', 'bengali', 'global', 38, true, 'language', 'bengali', 'relevance', true, now()),
  ('gujarati', 'Gujarati', '', 'gujarati', 'global', 39, true, 'language', 'gujarati', 'relevance', true, now()),
  ('malayalam', 'Malayalam', '', 'malayalam', 'global', 40, true, 'language', 'malayalam', 'relevance', true, now()),
  ('kannada', 'Kannada', '', 'kannada', 'global', 41, true, 'language', 'kannada', 'relevance', true, now()),
  ('bollywood', 'Bollywood', '', 'bollywood', 'global', 50, true, 'genre', 'bollywood', 'relevance', true, now()),
  ('indie', 'Indie', '', 'indie', 'global', 51, true, 'genre', 'indie', 'relevance', true, now()),
  ('pop', 'Pop', '', 'pop', 'global', 52, true, 'genre', 'pop', 'relevance', true, now()),
  ('hiphop', 'Hip-Hop', '', 'hip hop', 'global', 53, true, 'genre', 'hip hop', 'relevance', true, now()),
  ('edm', 'EDM', '', 'edm', 'global', 54, true, 'genre', 'edm', 'relevance', true, now()),
  ('rock', 'Rock', '', 'rock', 'global', 55, true, 'genre', 'rock', 'relevance', true, now()),
  ('lofi', 'Lo-Fi', '', 'lofi', 'global', 56, true, 'genre', 'lofi', 'relevance', true, now()),
  ('classical', 'Classical', '', 'classical', 'global', 57, true, 'genre', 'classical', 'relevance', true, now()),
  ('ghazal', 'Ghazal', '', 'ghazal', 'global', 58, true, 'genre', 'ghazal', 'relevance', true, now()),
  ('sufi', 'Sufi', '', 'sufi', 'global', 59, true, 'genre', 'sufi', 'relevance', true, now()),
  ('regional', 'Regional', '', 'regional', 'global', 60, true, 'genre', 'regional', 'relevance', true, now()),
  ('90s', '90s', '', '90s hits', 'global', 70, true, 'decade', '90s hits', 'relevance', true, now()),
  ('2000s', '2000s', '', '2000s hits', 'global', 71, true, 'decade', '2000s hits', 'relevance', true, now()),
  ('2010s', '2010s', '', '2010s hits', 'global', 72, true, 'decade', '2010s hits', 'relevance', true, now()),
  ('2020s', '2020s', '', '2020s hits', 'global', 73, true, 'decade', '2020s hits', 'relevance', true, now()),
  ('act_workout', 'Workout', '', 'workout', 'global', 79, true, 'activity', 'workout', 'relevance', true, now()),
  ('act_party', 'Party', '', 'party', 'global', 80, true, 'activity', 'party', 'relevance', true, now()),
  ('road_trip', 'Road Trip', '', 'road trip', 'global', 81, true, 'activity', 'road trip', 'relevance', true, now()),
  ('late_night', 'Late Night', '', 'late night', 'global', 82, true, 'activity', 'late night', 'relevance', true, now()),
  ('morning', 'Morning', '', 'morning', 'global', 83, true, 'activity', 'morning', 'relevance', true, now()),
  ('study', 'Study', '', 'study', 'global', 84, true, 'activity', 'study', 'relevance', true, now()),
  ('travel', 'Travel', '', 'travel', 'global', 85, true, 'activity', 'travel', 'relevance', true, now()),
  ('rainy_day', 'Rainy Day', '', 'rainy day', 'global', 86, true, 'activity', 'rainy day', 'relevance', true, now());
