-- ════════════════════════════════════════════════════════════════════════════
-- V Shots — Notifications Schema
-- ════════════════════════════════════════════════════════════════════════════
--
-- Tables:
-- - notification_preferences: User notification settings
-- - notification_history: Track sent/opened notifications
-- - user_devices: FCM tokens and device info
-- - user_engagement: User activity signals for smart notifications

-- Notification Preferences
CREATE TABLE IF NOT EXISTS notification_preferences (
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
  notifications_enabled BOOLEAN DEFAULT true,
  new_music_enabled BOOLEAN DEFAULT true,
  recommendations_enabled BOOLEAN DEFAULT true,
  trending_enabled BOOLEAN DEFAULT true,
  winback_enabled BOOLEAN DEFAULT true,
  update_notifications_enabled BOOLEAN DEFAULT true,
  preferred_time TIME,
  timezone TEXT DEFAULT 'UTC',
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Notification History
CREATE TABLE IF NOT EXISTS notification_history (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  notification_type TEXT NOT NULL,
  content_id TEXT,
  title TEXT,
  body TEXT,
  sent_at TIMESTAMPTZ DEFAULT now(),
  opened_at TIMESTAMPTZ,
  clicked BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_notification_history_user ON notification_history(user_id);
CREATE INDEX idx_notification_history_type ON notification_history(notification_type);
CREATE INDEX idx_notification_history_sent ON notification_history(sent_at DESC);

-- User Devices (FCM tokens)
CREATE TABLE IF NOT EXISTS user_devices (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  fcm_token TEXT NOT NULL,
  platform TEXT DEFAULT 'android',
  device_model TEXT,
  os_version TEXT,
  app_version TEXT,
  last_active_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(user_id, fcm_token)
);

CREATE INDEX idx_user_devices_user ON user_devices(user_id);
CREATE INDEX idx_user_devices_token ON user_devices(fcm_token);

-- User Engagement (for smart notifications)
CREATE TABLE IF NOT EXISTS user_engagement (
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
  last_active_at TIMESTAMPTZ DEFAULT now(),
  sessions_count INTEGER DEFAULT 0,
  average_active_hour INTEGER,
  recent_artists JSONB DEFAULT '[]'::jsonb,
  recent_genres JSONB DEFAULT '[]'::jsonb,
  notification_opens INTEGER DEFAULT 0,
  notification_clicks INTEGER DEFAULT 0,
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Row Level Security
ALTER TABLE notification_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE notification_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_devices ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_engagement ENABLE ROW LEVEL SECURITY;

-- Policies
CREATE POLICY "Users can view their own preferences"
  ON notification_preferences FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can update their own preferences"
  ON notification_preferences FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own preferences"
  ON notification_preferences FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can view their own history"
  ON notification_history FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "System can insert notification history"
  ON notification_history FOR INSERT
  WITH CHECK (true); -- Allow server-side inserts

CREATE POLICY "Users can update their own history"
  ON notification_history FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can view their own devices"
  ON user_devices FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own devices"
  ON user_devices FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own devices"
  ON user_devices FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own devices"
  ON user_devices FOR DELETE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can view their own engagement"
  ON user_engagement FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can update their own engagement"
  ON user_engagement FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "System can insert engagement"
  ON user_engagement FOR INSERT
  WITH CHECK (true);

-- Enable realtime for notification preferences (for settings sync)
ALTER PUBLICATION supabase_realtime ADD TABLE notification_preferences;
