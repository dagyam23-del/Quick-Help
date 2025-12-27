-- QuickHelp Database Setup Script
-- Run this in Supabase SQL Editor
-- This script creates the database tables and security policies

-- ============================================
-- CREATE TABLES
-- ============================================

-- Create requests table
-- Stores help requests posted by students
CREATE TABLE IF NOT EXISTS requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  description TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'taken', 'completed', 'deleted')),
  requester_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  helper_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create messages table
-- Stores chat messages for each request
CREATE TABLE IF NOT EXISTS messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  request_id UUID NOT NULL REFERENCES requests(id) ON DELETE CASCADE,
  sender_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  message TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create profiles table
-- Public profile info visible to other users (name + avatar)
CREATE TABLE IF NOT EXISTS profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT,
  avatar_url TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create request_archives table
-- Stores per-user "deleted/archived" conversations (soft-delete per user)
CREATE TABLE IF NOT EXISTS request_archives (
  request_id UUID NOT NULL REFERENCES requests(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  archived_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  PRIMARY KEY (request_id, user_id)
);

-- Create comments table
-- Stores public comments on requests (visible to all users viewing the request)
CREATE TABLE IF NOT EXISTS comments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  request_id UUID NOT NULL REFERENCES requests(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  comment TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create request_files table
-- Stores files uploaded by requester for helpers to download
CREATE TABLE IF NOT EXISTS request_files (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  request_id UUID NOT NULL REFERENCES requests(id) ON DELETE CASCADE,
  uploaded_by UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  file_name TEXT NOT NULL,
  file_path TEXT NOT NULL,
  file_size BIGINT NOT NULL,
  mime_type TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================
-- ENABLE ROW LEVEL SECURITY (RLS)
-- ============================================

ALTER TABLE requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE request_archives ENABLE ROW LEVEL SECURITY;
ALTER TABLE comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE request_files ENABLE ROW LEVEL SECURITY;

-- ============================================
-- RLS POLICIES FOR REQUESTS TABLE
-- ============================================

-- Policy: Anyone can create a request
DO $$
BEGIN
  CREATE POLICY "Anyone can create requests"
    ON requests
    FOR INSERT
    WITH CHECK (true);
EXCEPTION WHEN duplicate_object THEN
  NULL;
END $$;

-- Policy: Anyone can view open requests
DO $$
BEGIN
  CREATE POLICY "Anyone can view open requests"
    ON requests
    FOR SELECT
    USING (status = 'open');
EXCEPTION WHEN duplicate_object THEN
  NULL;
END $$;

-- Policy: Requester and helper can view their own requests (taken/completed)
DO $$
BEGIN
  CREATE POLICY "Users can view their own requests"
    ON requests
    FOR SELECT
    USING (
      auth.uid() = requester_id OR 
      auth.uid() = helper_id
    );
EXCEPTION WHEN duplicate_object THEN
  NULL;
END $$;

-- Policy: Requester can update their own requests
DO $$
BEGIN
  CREATE POLICY "Requester can update their own requests"
    ON requests
    FOR UPDATE
    USING (auth.uid() = requester_id)
    WITH CHECK (auth.uid() = requester_id);
EXCEPTION WHEN duplicate_object THEN
  NULL;
END $$;

-- Policy: Anyone can volunteer for open requests
-- This allows any user to become a helper for an open request
DO $$
BEGIN
  CREATE POLICY "Anyone can volunteer for open requests"
    ON requests
    FOR UPDATE
    USING (
      status = 'open' AND 
      auth.uid() != requester_id
    )
    WITH CHECK (
      status = 'taken' AND
      helper_id = auth.uid()
    );
EXCEPTION WHEN duplicate_object THEN
  NULL;
END $$;

-- Policy: Requester or helper can mark request as completed
DO $$
BEGIN
  CREATE POLICY "Requester or helper can complete requests"
    ON requests
    FOR UPDATE
    USING (
      status = 'taken' AND
      (auth.uid() = requester_id OR auth.uid() = helper_id)
    )
    WITH CHECK (
      status = 'completed' AND
      (auth.uid() = requester_id OR auth.uid() = helper_id)
    );
EXCEPTION WHEN duplicate_object THEN
  NULL;
END $$;

-- Policy: Requester can delete their own requests (set status to 'deleted')
DO $$
BEGIN
  CREATE POLICY "Requester can delete their own requests"
    ON requests
    FOR UPDATE
    USING (
      auth.uid() = requester_id AND
      status != 'deleted'
    )
    WITH CHECK (
      auth.uid() = requester_id AND
      status = 'deleted'
    );
EXCEPTION WHEN duplicate_object THEN
  NULL;
END $$;

-- ============================================
-- RLS POLICIES FOR MESSAGES TABLE
-- ============================================

-- Policy: Only requester and helper can view messages for a request
DO $$
BEGIN
  CREATE POLICY "Requester and helper can view messages"
    ON messages
    FOR SELECT
    USING (
      EXISTS (
        SELECT 1 FROM requests
        WHERE requests.id = messages.request_id
        AND (requests.requester_id = auth.uid() OR requests.helper_id = auth.uid())
      )
    );
EXCEPTION WHEN duplicate_object THEN
  NULL;
END $$;

-- Policy: Only requester and helper can send messages
-- Messages can only be sent once a request is taken (has a helper)
DO $$
BEGIN
  CREATE POLICY "Requester and helper can send messages"
    ON messages
    FOR INSERT
    WITH CHECK (
      EXISTS (
        SELECT 1 FROM requests
        WHERE requests.id = messages.request_id
        AND (requests.requester_id = auth.uid() OR requests.helper_id = auth.uid())
        AND requests.status IN ('taken', 'completed')
      )
      AND sender_id = auth.uid()
    );
EXCEPTION WHEN duplicate_object THEN
  NULL;
END $$;

-- ============================================
-- RLS POLICIES FOR PROFILES TABLE
-- ============================================

-- Policy: Anyone can view profiles (public info only)
DO $$
BEGIN
  CREATE POLICY "Anyone can view profiles"
    ON profiles
    FOR SELECT
    USING (true);
EXCEPTION WHEN duplicate_object THEN
  NULL;
END $$;

-- Policy: Users can create their own profile row
DO $$
BEGIN
  CREATE POLICY "Users can create their own profile"
    ON profiles
    FOR INSERT
    WITH CHECK (auth.uid() = id);
EXCEPTION WHEN duplicate_object THEN
  NULL;
END $$;

-- Policy: Users can update their own profile row
DO $$
BEGIN
  CREATE POLICY "Users can update their own profile"
    ON profiles
    FOR UPDATE
    USING (auth.uid() = id)
    WITH CHECK (auth.uid() = id);
EXCEPTION WHEN duplicate_object THEN
  NULL;
END $$;

-- ============================================
-- RLS POLICIES FOR REQUEST_ARCHIVES TABLE
-- ============================================

-- Policy: Users can view their own archived conversations
DO $$
BEGIN
  CREATE POLICY "Users can view their own request archives"
    ON request_archives
    FOR SELECT
    USING (auth.uid() = user_id);
EXCEPTION WHEN duplicate_object THEN
  NULL;
END $$;

-- Policy: Users can archive (soft-delete) a conversation for themselves
DO $$
BEGIN
  CREATE POLICY "Users can create their own request archives"
    ON request_archives
    FOR INSERT
    WITH CHECK (auth.uid() = user_id);
EXCEPTION WHEN duplicate_object THEN
  NULL;
END $$;

-- Policy: Users can unarchive (delete archive row) for themselves
DO $$
BEGIN
  CREATE POLICY "Users can delete their own request archives"
    ON request_archives
    FOR DELETE
    USING (auth.uid() = user_id);
EXCEPTION WHEN duplicate_object THEN
  NULL;
END $$;

-- ============================================
-- RLS POLICIES FOR COMMENTS TABLE
-- ============================================

-- Policy: Anyone can view comments on requests (public comments)
DO $$
BEGIN
  CREATE POLICY "Anyone can view comments"
    ON comments
    FOR SELECT
    USING (true);
EXCEPTION WHEN duplicate_object THEN
  NULL;
END $$;

-- Policy: Authenticated users can add comments
DO $$
BEGIN
  CREATE POLICY "Authenticated users can add comments"
    ON comments
    FOR INSERT
    WITH CHECK (auth.uid() = user_id AND auth.uid() IS NOT NULL);
EXCEPTION WHEN duplicate_object THEN
  NULL;
END $$;

-- Policy: Users can delete their own comments
DO $$
BEGIN
  CREATE POLICY "Users can delete their own comments"
    ON comments
    FOR DELETE
    USING (auth.uid() = user_id);
EXCEPTION WHEN duplicate_object THEN
  NULL;
END $$;

-- ============================================
-- RLS POLICIES FOR REQUEST_FILES TABLE
-- ============================================

-- Policy: Anyone can view files for a request (helpers need to see them)
DO $$
BEGIN
  CREATE POLICY "Anyone can view request files"
    ON request_files
    FOR SELECT
    USING (true);
EXCEPTION WHEN duplicate_object THEN
  NULL;
END $$;

-- Policy: Only requester can upload files for their request
DO $$
BEGIN
  CREATE POLICY "Requester can upload files"
    ON request_files
    FOR INSERT
    WITH CHECK (
      auth.uid() = uploaded_by AND
      EXISTS (
        SELECT 1 FROM requests
        WHERE requests.id = request_files.request_id
        AND requests.requester_id = auth.uid()
      )
    );
EXCEPTION WHEN duplicate_object THEN
  NULL;
END $$;

-- Policy: Only requester can delete files from their request
DO $$
BEGIN
  CREATE POLICY "Requester can delete their files"
    ON request_files
    FOR DELETE
    USING (
      auth.uid() = uploaded_by AND
      EXISTS (
        SELECT 1 FROM requests
        WHERE requests.id = request_files.request_id
        AND requests.requester_id = auth.uid()
      )
    );
EXCEPTION WHEN duplicate_object THEN
  NULL;
END $$;

-- ============================================
-- STORAGE: AVATAR BUCKET + POLICIES
-- ============================================

-- Create avatar bucket (public read)
-- NOTE: This may fail if you don't have permissions on storage.buckets
-- If it fails, create the bucket manually in Supabase Dashboard:
-- Go to Storage > New bucket > Name: 'avatar' > Public: Yes
DO $$
BEGIN
  INSERT INTO storage.buckets (id, name, public)
  VALUES ('avatar', 'avatar', true)
  ON CONFLICT (id) DO UPDATE SET public = true;
EXCEPTION 
  WHEN insufficient_privilege THEN
    RAISE NOTICE 'Cannot create storage bucket. Please create it manually in the Dashboard.';
  WHEN OTHERS THEN
    RAISE NOTICE 'Error creating storage bucket: %. You may need to create it manually.', SQLERRM;
END $$;

-- ============================================
-- STORAGE POLICIES (Avatar bucket)
-- ============================================
-- NOTE: Storage policies cannot be created via SQL without superuser privileges.
-- Please create these policies manually in the Supabase Dashboard:
-- 
-- 1. Go to Storage > Policies in your Supabase Dashboard
-- 2. Select the 'avatar' bucket (create it if it doesn't exist)
-- 3. Add the following policies:
--
-- Policy 1: "Public read avatar"
--   Type: SELECT
--   Target roles: public
--   Policy definition: bucket_id = 'avatar'
--
-- Policy 2: "Users can upload their own avatar"
--   Type: INSERT
--   Target roles: authenticated
--   Policy definition: bucket_id = 'avatar' AND auth.uid() = owner
--
-- Policy 3: "Users can update their own avatar"
--   Type: UPDATE
--   Target roles: authenticated
--   Policy definition: bucket_id = 'avatar' AND auth.uid() = owner
--
-- Policy 4: "Users can delete their own avatar"
--   Type: DELETE
--   Target roles: authenticated
--   Policy definition: bucket_id = 'avatar' AND auth.uid() = owner
--
-- Alternatively, you can try running these via the Supabase SQL Editor
-- with superuser privileges (if available):
--
-- CREATE POLICY "Public read avatar"
--   ON storage.objects FOR SELECT
--   USING (bucket_id = 'avatar');
--
-- CREATE POLICY "Users can upload their own avatar"
--   ON storage.objects FOR INSERT
--   WITH CHECK (bucket_id = 'avatar' AND auth.uid() = owner);
--
-- CREATE POLICY "Users can update their own avatar"
--   ON storage.objects FOR UPDATE
--   USING (bucket_id = 'avatar' AND auth.uid() = owner)
--   WITH CHECK (bucket_id = 'avatar' AND auth.uid() = owner);
--
-- CREATE POLICY "Users can delete their own avatar"
--   ON storage.objects FOR DELETE
--   USING (bucket_id = 'avatar' AND auth.uid() = owner);

-- ============================================
-- CREATE INDEXES FOR PERFORMANCE
-- ============================================

CREATE INDEX IF NOT EXISTS idx_requests_status ON requests(status);
CREATE INDEX IF NOT EXISTS idx_requests_requester_id ON requests(requester_id);
CREATE INDEX IF NOT EXISTS idx_requests_helper_id ON requests(helper_id);
CREATE INDEX IF NOT EXISTS idx_messages_request_id ON messages(request_id);
CREATE INDEX IF NOT EXISTS idx_messages_created_at ON messages(created_at);
CREATE INDEX IF NOT EXISTS idx_profiles_name ON profiles(name);
CREATE INDEX IF NOT EXISTS idx_request_archives_user_id ON request_archives(user_id);
CREATE INDEX IF NOT EXISTS idx_comments_request_id ON comments(request_id);
CREATE INDEX IF NOT EXISTS idx_comments_created_at ON comments(created_at);
CREATE INDEX IF NOT EXISTS idx_request_files_request_id ON request_files(request_id);
CREATE INDEX IF NOT EXISTS idx_request_files_uploaded_by ON request_files(uploaded_by);

-- ============================================
-- SETUP COMPLETE
-- ============================================
-- After running this script:
-- 1. Go to Database > Replication in Supabase Dashboard
-- 2. Enable replication for 'messages' table (required for real-time chat)
-- 3. Optionally enable replication for 'requests' table (for real-time updates)
