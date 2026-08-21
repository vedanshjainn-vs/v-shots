-- JioSaavn CMS fields + feature flags
ALTER TABLE public.home_layout_config
  ADD COLUMN IF NOT EXISTS provider TEXT DEFAULT 'youtube',
  ADD COLUMN IF NOT EXISTS playback_provider TEXT DEFAULT 'youtube_web',
  ADD COLUMN IF NOT EXISTS fallback_provider TEXT DEFAULT 'youtube_web',
  ADD COLUMN IF NOT EXISTS subtitle TEXT,
  ADD COLUMN IF NOT EXISTS published BOOLEAN NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS config_version INTEGER NOT NULL DEFAULT 1;

CREATE TABLE IF NOT EXISTS public.home_section_items (
  id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  section_id TEXT NOT NULL REFERENCES public.home_layout_config(id) ON DELETE CASCADE,
  content_id TEXT NOT NULL, title TEXT NOT NULL, artist TEXT, artwork_url TEXT,
  provider TEXT NOT NULL DEFAULT 'youtube',
  playback_provider TEXT NOT NULL DEFAULT 'youtube_web',
  fallback_provider TEXT NOT NULL DEFAULT 'youtube_web',
  jiosaavn_url TEXT, jiosaavn_enabled BOOLEAN NOT NULL DEFAULT false,
  youtube_video_id TEXT, sort_order INTEGER NOT NULL DEFAULT 0,
  is_enabled BOOLEAN NOT NULL DEFAULT true, metadata JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.home_config (
  id TEXT PRIMARY KEY DEFAULT 'current',
  version INTEGER NOT NULL DEFAULT 1, status TEXT NOT NULL DEFAULT 'published',
  published_at TIMESTAMPTZ, updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.feature_flags (
  key TEXT PRIMARY KEY, value BOOLEAN NOT NULL DEFAULT false,
  description TEXT, updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_home_section_items_section_id ON public.home_section_items(section_id);
CREATE INDEX IF NOT EXISTS idx_home_section_items_sort_order ON public.home_section_items(section_id, sort_order);

ALTER TABLE public.home_section_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.home_config ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.feature_flags ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "public read home_section_items" ON public.home_section_items;
CREATE POLICY "public read home_section_items" ON public.home_section_items FOR SELECT USING (true);
DROP POLICY IF EXISTS "public read home_config" ON public.home_config;
CREATE POLICY "public read home_config" ON public.home_config FOR SELECT USING (true);
DROP POLICY IF EXISTS "public read feature_flags" ON public.feature_flags;
CREATE POLICY "public read feature_flags" ON public.feature_flags FOR SELECT USING (true);

DROP POLICY IF EXISTS "admin write home_layout_config" ON public.home_layout_config;
CREATE POLICY "admin write home_layout_config" ON public.home_layout_config FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
DROP POLICY IF EXISTS "admin write home_section_items" ON public.home_section_items;
CREATE POLICY "admin write home_section_items" ON public.home_section_items FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
DROP POLICY IF EXISTS "admin write home_config" ON public.home_config;
CREATE POLICY "admin write home_config" ON public.home_config FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
DROP POLICY IF EXISTS "admin write feature_flags" ON public.feature_flags;
CREATE POLICY "admin write feature_flags" ON public.feature_flags FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');

INSERT INTO public.home_config (id, version, status, published_at) VALUES ('current', 1, 'published', now()) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.feature_flags (key, value, description) VALUES
  ('enable_jiosaavn_web_playback', false, 'Enable JioSaavn web playback'),
  ('enable_jiosaavn_search_fallback', true, 'Allow JioSaavn search fallback'),
  ('enable_jiosaavn_exact_urls', true, 'Allow exact JioSaavn URLs'),
  ('enable_remote_home', true, 'Fetch Home config from Supabase'),
  ('enable_youtube_web_playback', true, 'Enable YouTube playback')
ON CONFLICT (key) DO NOTHING;
