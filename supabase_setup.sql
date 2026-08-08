-- ════════════════════════════════════════════════
-- V Shots — Supabase Database Setup
-- ════════════════════════════════════════════════
-- Run this in Supabase SQL Editor

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ═══════════════════════════════════════════════
-- PROFILES TABLE
-- ═══════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS profiles (
  id UUID REFERENCES auth.users(id) PRIMARY KEY,
  email TEXT UNIQUE NOT NULL,
  display_name TEXT,
  avatar_url TEXT,
  bio TEXT,
  location TEXT,
  is_public BOOLEAN DEFAULT true,
  followers_count INTEGER DEFAULT 0,
  following_count INTEGER DEFAULT 0,
  playlist_count INTEGER DEFAULT 0,
  subscription_tier TEXT DEFAULT 'free',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ═══════════════════════════════════════════════
-- TRACKS TABLE
-- ═══════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS tracks (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  title TEXT NOT NULL,
  artist TEXT NOT NULL,
  artist_id UUID,
  album TEXT,
  album_id UUID,
  artwork_url TEXT,
  stream_url TEXT,
  duration_ms INTEGER DEFAULT 0,
  genre TEXT,
  year INTEGER,
  play_count INTEGER DEFAULT 0,
  is_explicit BOOLEAN DEFAULT false,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ═══════════════════════════════════════════════
-- ALBUMS TABLE
-- ═══════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS albums (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  title TEXT NOT NULL,
  artist TEXT NOT NULL,
  artist_id UUID,
  artwork_url TEXT,
  release_date DATE,
  total_tracks INTEGER DEFAULT 0,
  genre TEXT,
  label TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ═══════════════════════════════════════════════
-- ARTISTS TABLE
-- ═══════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS artists (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  name TEXT NOT NULL,
  image_url TEXT,
  biography TEXT,
  followers_count INTEGER DEFAULT 0,
  genres TEXT[] DEFAULT '{}',
  is_verified BOOLEAN DEFAULT false,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ═══════════════════════════════════════════════
-- PLAYLISTS TABLE
-- ═══════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS playlists (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  title TEXT NOT NULL,
  description TEXT,
  artwork_url TEXT,
  owner_id UUID REFERENCES profiles(id) NOT NULL,
  is_public BOOLEAN DEFAULT true,
  is_collaborative BOOLEAN DEFAULT false,
  track_count INTEGER DEFAULT 0,
  follower_count INTEGER DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ═══════════════════════════════════════════════
-- PLAYLIST TRACKS TABLE
-- ═══════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS playlist_tracks (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  playlist_id UUID REFERENCES playlists(id) ON DELETE CASCADE NOT NULL,
  track_id UUID REFERENCES tracks(id) NOT NULL,
  added_by UUID REFERENCES profiles(id),
  added_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  position INTEGER DEFAULT 0,
  UNIQUE(playlist_id, track_id)
);

-- ═══════════════════════════════════════════════
-- LIKED SONGS TABLE
-- ═══════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS liked_songs (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  track_id UUID REFERENCES tracks(id) NOT NULL,
  liked_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(user_id, track_id)
);

-- ═══════════════════════════════════════════════
-- SAVED ALBUMS TABLE
-- ═══════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS saved_albums (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  album_id UUID REFERENCES albums(id) NOT NULL,
  saved_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(user_id, album_id)
);

-- ═══════════════════════════════════════════════
-- FOLLOWED ARTISTS TABLE
-- ═══════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS followed_artists (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  artist_id UUID REFERENCES artists(id) NOT NULL,
  followed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(user_id, artist_id)
);

-- ═══════════════════════════════════════════════
-- PLAY HISTORY TABLE
-- ═══════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS play_history (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  track_id UUID REFERENCES tracks(id) NOT NULL,
  played_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  played_duration_ms INTEGER DEFAULT 0,
  completed BOOLEAN DEFAULT false
);

-- ═══════════════════════════════════════════════
-- SUBSCRIPTIONS TABLE
-- ═══════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS subscriptions (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE UNIQUE NOT NULL,
  plan_id TEXT NOT NULL,
  plan_name TEXT NOT NULL,
  status TEXT DEFAULT 'active',
  start_date TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  end_date TIMESTAMP WITH TIME ZONE,
  auto_renew BOOLEAN DEFAULT true,
  receipt TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ═══════════════════════════════════════════════
-- NOTIFICATIONS TABLE
-- ═══════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS notifications (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  title TEXT NOT NULL,
  body TEXT,
  type TEXT NOT NULL,
  image_url TEXT,
  action_url TEXT,
  is_read BOOLEAN DEFAULT false,
  data JSONB DEFAULT '{}',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ═══════════════════════════════════════════════
-- SETTINGS TABLE
-- ═══════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS user_settings (
  user_id UUID REFERENCES profiles(id) PRIMARY KEY,
  theme_mode TEXT DEFAULT 'dark',
  audio_quality TEXT DEFAULT 'high',
  download_quality TEXT DEFAULT 'high',
  language TEXT DEFAULT 'en',
  download_over_wifi_only BOOLEAN DEFAULT true,
  notifications_enabled BOOLEAN DEFAULT true,
  analytics_enabled BOOLEAN DEFAULT true,
  crossfade_enabled BOOLEAN DEFAULT false,
  crossfade_duration_ms INTEGER DEFAULT 3000,
  gapless_playback BOOLEAN DEFAULT true,
  normalize_volume BOOLEAN DEFAULT true,
  show_explicit_content BOOLEAN DEFAULT true,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ═══════════════════════════════════════════════
-- INDEXES
-- ═══════════════════════════════════════════════
CREATE INDEX idx_tracks_artist ON tracks(artist_id);
CREATE INDEX idx_tracks_album ON tracks(album_id);
CREATE INDEX idx_playlist_tracks_playlist ON playlist_tracks(playlist_id);
CREATE INDEX idx_liked_songs_user ON liked_songs(user_id);
CREATE INDEX idx_play_history_user ON play_history(user_id);
CREATE INDEX idx_notifications_user ON notifications(user_id);
CREATE INDEX idx_notifications_unread ON notifications(user_id, is_read) WHERE is_read = false;

-- ═══════════════════════════════════════════════
-- ROW LEVEL SECURITY
-- ═══════════════════════════════════════════════

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE playlists ENABLE ROW LEVEL SECURITY;
ALTER TABLE liked_songs ENABLE ROW LEVEL SECURITY;
ALTER TABLE saved_albums ENABLE ROW LEVEL SECURITY;
ALTER TABLE followed_artists ENABLE ROW LEVEL SECURITY;
ALTER TABLE play_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_settings ENABLE ROW LEVEL SECURITY;

-- Profiles: Users can read all, update own
CREATE POLICY "Public profiles are viewable by everyone" ON profiles
  FOR SELECT USING (true);

CREATE POLICY "Users can update own profile" ON profiles
  FOR UPDATE USING (auth.uid() = id);

-- Playlists: Public viewable, owners can edit
CREATE POLICY "Public playlists viewable" ON playlists
  FOR SELECT USING (is_public = true OR auth.uid() = owner_id);

CREATE POLICY "Users can create playlists" ON playlists
  FOR INSERT WITH CHECK (auth.uid() = owner_id);

CREATE POLICY "Users can update own playlists" ON playlists
  FOR UPDATE USING (auth.uid() = owner_id);

CREATE POLICY "Users can delete own playlists" ON playlists
  FOR DELETE USING (auth.uid() = owner_id);

-- Liked songs: Users manage own
CREATE POLICY "Users can view own liked songs" ON liked_songs
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can like songs" ON liked_songs
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can unlike songs" ON liked_songs
  FOR DELETE USING (auth.uid() = user_id);

-- Saved albums: Users manage own
CREATE POLICY "Users can view own saved albums" ON saved_albums
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can save albums" ON saved_albums
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can unsave albums" ON saved_albums
  FOR DELETE USING (auth.uid() = user_id);

-- Followed artists: Users manage own
CREATE POLICY "Users can view own followed artists" ON followed_artists
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can follow artists" ON followed_artists
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can unfollow artists" ON followed_artists
  FOR DELETE USING (auth.uid() = user_id);

-- Play history: Users manage own
CREATE POLICY "Users can view own history" ON play_history
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can add to history" ON play_history
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Notifications: Users view own
CREATE POLICY "Users can view own notifications" ON notifications
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can update own notifications" ON notifications
  FOR UPDATE USING (auth.uid() = user_id);

-- Settings: Users manage own
CREATE POLICY "Users can view own settings" ON user_settings
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can update own settings" ON user_settings
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own settings" ON user_settings
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Tracks, Albums, Artists: Public readable
CREATE POLICY "Tracks are viewable by everyone" ON tracks FOR SELECT USING (true);
CREATE POLICY "Albums are viewable by everyone" ON albums FOR SELECT USING (true);
CREATE POLICY "Artists are viewable by everyone" ON artists FOR SELECT USING (true);
CREATE POLICY "Playlist tracks viewable" ON playlist_tracks FOR SELECT USING (true);

-- ═══════════════════════════════════════════════
-- FUNCTIONS
-- ═══════════════════════════════════════════════

-- Auto-create profile on signup
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO profiles (id, email, display_name)
  VALUES (NEW.id, NEW.email, COALESCE(NEW.raw_user_meta_data->>'display_name', split_part(NEW.email, '@', 1)));
  
  INSERT INTO user_settings (user_id)
  VALUES (NEW.id);
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger for new user
CREATE OR REPLACE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- ═══════════════════════════════════════════════
-- SAMPLE DATA (Optional - for testing)
-- ═══════════════════════════════════════════════

-- Insert sample artists
INSERT INTO artists (name, image_url, genres) VALUES
  ('Aria Nova', 'https://picsum.photos/300?random=1', ARRAY['Pop', 'Electronic']),
  ('Luna Echo', 'https://picsum.photos/300?random=2', ARRAY['R&B', 'Soul']),
  ('Stellar Beat', 'https://picsum.photos/300?random=3', ARRAY['Dance', 'EDM']),
  ('Neon Pulse', 'https://picsum.photos/300?random=4', ARRAY['Synthwave', 'Electronic']),
  ('Crystal Wave', 'https://picsum.photos/300?random=5', ARRAY['Pop', 'Dance'])
ON CONFLICT DO NOTHING;

-- Insert sample albums
INSERT INTO albums (title, artist, artwork_url, release_date, total_tracks, genre) VALUES
  ('Midnight Dreams', 'Aria Nova', 'https://picsum.photos/300?random=10', '2024-01-15', 12, 'Pop'),
  ('Electric Sunrise', 'Luna Echo', 'https://picsum.photos/300?random=11', '2024-02-20', 10, 'R&B'),
  ('Ocean Waves', 'Stellar Beat', 'https://picsum.photos/300?random=12', '2024-03-10', 8, 'Dance'),
  ('City Lights', 'Neon Pulse', 'https://picsum.photos/300?random=13', '2024-04-05', 11, 'Synthwave'),
  ('Starfall', 'Crystal Wave', 'https://picsum.photos/300?random=14', '2024-05-01', 9, 'Pop')
ON CONFLICT DO NOTHING;

-- Success message
SELECT 'Database setup complete! 🎵' as message;
