-- ═══════════════════════════════════════════════════════════════════
-- V SHOTS — OPTIONAL: missing social/creator tables
-- Date: 2026-09-10
--
-- ⚠️ NOT APPLIED — staged for owner decision. The Flutter app references
-- these tables (shots/likes/bookmarks/comments/follows) but they were
-- never deployed to the production DB, so creator-upload and social
-- features fail at runtime today (they're gated OFF for most users).
--
-- Apply ONLY when the owner decides to ship the creator/social feature:
--   1. Review storage buckets (shots-videos, thumbnails) exist + policies
--   2. Apply this migration in Supabase SQL Editor
--   3. Flip `enable_social` feature flag + profiles.is_creator for pilot
-- ═══════════════════════════════════════════════════════════════════

-- ── Tables (verbatim from supabase_setup.sql) ──────────────────────
-- 3. Shots Table (Short-video & social content)
CREATE TABLE IF NOT EXISTS public.shots (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  caption TEXT,
  video_url TEXT NOT NULL,
  thumbnail_url TEXT,
  duration_seconds INTEGER DEFAULT 0,
  visibility TEXT NOT NULL DEFAULT 'public' CHECK (visibility IN ('public', 'private', 'followers')),
  like_count INTEGER NOT NULL DEFAULT 0,
  comment_count INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- 4. Likes Table
CREATE TABLE IF NOT EXISTS public.likes (
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  shot_id UUID NOT NULL REFERENCES public.shots(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  PRIMARY KEY (user_id, shot_id)
);

-- 5. Comments Table
CREATE TABLE IF NOT EXISTS public.comments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  shot_id UUID NOT NULL REFERENCES public.shots(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  body TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- 6. Follows Table
CREATE TABLE IF NOT EXISTS public.follows (
  follower_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  following_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  PRIMARY KEY (follower_id, following_id),
  CONSTRAINT cannot_follow_self CHECK (follower_id != following_id)
);

-- 7. Bookmarks Table
CREATE TABLE IF NOT EXISTS public.bookmarks (
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  shot_id UUID NOT NULL REFERENCES public.shots(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  PRIMARY KEY (user_id, shot_id)
);

-- 8. Notifications Table
CREATE TABLE IF NOT EXISTS public.notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  recipient_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  actor_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  type TEXT NOT NULL CHECK (type IN ('like', 'comment', 'follow', 'mention')),
  shot_id UUID REFERENCES public.shots(id) ON DELETE CASCADE,
  read BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- ═════════════════════════════════════════════════════════════════════════════
-- Performance Indexes
-- ═════════════════════════════════════════════════════════════════════════════
CREATE INDEX IF NOT EXISTS idx_shots_user_id ON public.shots(user_id);
CREATE INDEX IF NOT EXISTS idx_shots_created_at ON public.shots(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_shots_visibility ON public.shots(visibility);
CREATE INDEX IF NOT EXISTS idx_likes_shot_id ON public.likes(shot_id);
CREATE INDEX IF NOT EXISTS idx_comments_shot_id ON public.comments(shot_id);
CREATE INDEX IF NOT EXISTS idx_follows_following_id ON public.follows(following_id);
CREATE INDEX IF NOT EXISTS idx_bookmarks_user_id ON public.bookmarks(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_recipient_id ON public.notifications(recipient_id);

-- ═════════════════════════════════════════════════════════════════════════════
-- Triggers & Automation Functions
-- ═════════════════════════════════════════════════════════════════════════════

-- Auto create profile on auth.users signup
CREATE OR REPLACE FUNCTION public.handle_new_user()

-- ── RLS enable + user-scoped policies ──────────────────────────────
CREATE POLICY "Public shots are viewable by everyone"
  ON public.shots FOR SELECT
  USING (
    visibility = 'public'
    OR (auth.uid() IS NOT NULL AND user_id = auth.uid())
    OR (
      visibility = 'followers'
      AND auth.uid() IS NOT NULL
      AND EXISTS (
        SELECT 1 FROM public.follows
        WHERE follower_id = auth.uid() AND following_id = public.shots.user_id
      )
    )
  );

DROP POLICY IF EXISTS "Users can create their own shots" ON public.shots;
CREATE POLICY "Users can create their own shots"
  ON public.shots FOR INSERT
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update their own shots" ON public.shots;
CREATE POLICY "Users can update their own shots"
  ON public.shots FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete their own shots" ON public.shots;
CREATE POLICY "Users can delete their own shots"
  ON public.shots FOR DELETE
  USING (auth.uid() = user_id);

-- 3. Likes Policies
DROP POLICY IF EXISTS "Likes are viewable by everyone" ON public.likes;
CREATE POLICY "Likes are viewable by everyone"
  ON public.likes FOR SELECT
  USING (true);

DROP POLICY IF EXISTS "Users can like as themselves" ON public.likes;
CREATE POLICY "Users can like as themselves"
  ON public.likes FOR INSERT
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can unlike their own likes" ON public.likes;
CREATE POLICY "Users can unlike their own likes"
  ON public.likes FOR DELETE
  USING (auth.uid() = user_id);

-- 4. Comments Policies
DROP POLICY IF EXISTS "Comments are viewable by everyone" ON public.comments;
CREATE POLICY "Comments are viewable by everyone"
  ON public.comments FOR SELECT
  USING (true);

DROP POLICY IF EXISTS "Users can post comments as themselves" ON public.comments;
CREATE POLICY "Users can post comments as themselves"
  ON public.comments FOR INSERT
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete their own comments" ON public.comments;
CREATE POLICY "Users can delete their own comments"
  ON public.comments FOR DELETE
  USING (auth.uid() = user_id);

-- 5. Follows Policies
DROP POLICY IF EXISTS "Follows are viewable by everyone" ON public.follows;
CREATE POLICY "Follows are viewable by everyone"
  ON public.follows FOR SELECT
  USING (true);

DROP POLICY IF EXISTS "Users can follow as themselves" ON public.follows;
CREATE POLICY "Users can follow as themselves"
  ON public.follows FOR INSERT
  WITH CHECK (auth.uid() = follower_id);

DROP POLICY IF EXISTS "Users can unfollow as themselves" ON public.follows;
CREATE POLICY "Users can unfollow as themselves"
  ON public.follows FOR DELETE
  USING (auth.uid() = follower_id);

-- 6. Bookmarks Policies
DROP POLICY IF EXISTS "Users can view only their own bookmarks" ON public.bookmarks;
CREATE POLICY "Users can view only their own bookmarks"
  ON public.bookmarks FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can create their own bookmarks" ON public.bookmarks;
CREATE POLICY "Users can create their own bookmarks"
  ON public.bookmarks FOR INSERT
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can remove their own bookmarks" ON public.bookmarks;
CREATE POLICY "Users can remove their own bookmarks"
  ON public.bookmarks FOR DELETE
