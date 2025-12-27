# File Upload Setup Guide

This guide will help you set up file upload functionality for requesters to upload files for helpers.

## Step 1: Run Database SQL

1. Open your **Supabase Dashboard**
2. Go to **SQL Editor** (left sidebar)
3. Click **New Query**
4. Copy and paste the following SQL code:

```sql
-- Create request_files table (if not already created)
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

-- Enable RLS
ALTER TABLE request_files ENABLE ROW LEVEL SECURITY;

-- Policy: Anyone can view files for a request
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

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_request_files_request_id ON request_files(request_id);
CREATE INDEX IF NOT EXISTS idx_request_files_uploaded_by ON request_files(uploaded_by);
```

5. Click **Run** (or press Ctrl+Enter)
6. Wait for success message

## Step 2: Create Storage Bucket

1. In Supabase Dashboard, go to **Storage** (left sidebar)
2. Click **New bucket** button (top right)
3. Fill in the details:
   - **Name**: `request-files` (must be exactly this name)
   - **Public bucket**: ✅ **Enable this** (check the box)
   - **File size limit**: Leave default or set your preferred limit (e.g., 10 MB)
   - **Allowed MIME types**: Leave empty (allows all file types)
4. Click **Create bucket**

## Step 3: Set Storage Policies

1. Still in **Storage**, click on the **`request-files`** bucket you just created
2. Go to the **Policies** tab
3. Click **New Policy**

### Policy 1: Public Read Access
- **Policy name**: `Public read request files`
- **Allowed operations**: ✅ SELECT (check only SELECT)
- **Policy definition**:
  ```sql
  bucket_id = 'request-files'
  ```
- Click **Review** then **Save policy**

### Policy 2: Authenticated Upload
- **Policy name**: `Authenticated users can upload files`
- **Allowed operations**: ✅ INSERT (check only INSERT)
- **Policy definition**:
  ```sql
  bucket_id = 'request-files' AND auth.role() = 'authenticated'
  ```
- Click **Review** then **Save policy**

### Policy 3: Requester Delete
- **Policy name**: `Requester can delete their files`
- **Allowed operations**: ✅ DELETE (check only DELETE)
- **Policy definition**:
  ```sql
  bucket_id = 'request-files' AND auth.uid() = owner
  ```
- Click **Review** then **Save policy**

## Step 4: Verify Setup

1. Go back to **SQL Editor**
2. Run this query to verify the table exists:
   ```sql
   SELECT * FROM request_files LIMIT 1;
   ```
   (Should return empty result or show table structure)

3. Go to **Storage** and verify:
   - ✅ `request-files` bucket exists
   - ✅ Bucket is marked as **Public**
   - ✅ Three policies are listed under the bucket

## Step 5: Test in App

1. **As a Requester**:
   - Create a request or open an existing request you created
   - Scroll down to the **Files** section
   - Click **Upload File** button
   - Select a file from your device
   - File should appear in the list

2. **As a Helper**:
   - Open a request where you volunteered to help
   - Scroll to the **Files** section
   - You should see uploaded files
   - Click on a file to download it

## Troubleshooting

### Error: "Bucket not found"
- Make sure the bucket name is exactly `request-files` (with hyphen, lowercase)
- Check that the bucket exists in Storage

### Error: "Permission denied"
- Verify all three storage policies are created
- Make sure the bucket is set to **Public**
- Check that you're logged in as the requester when uploading

### Error: "Policy violation"
- Double-check the policy definitions match exactly as shown above
- Make sure RLS is enabled on the `request_files` table

### Files not showing
- Check that the SQL was run successfully
- Verify the `request_files` table exists in Database > Tables
- Check browser console for errors (F12)

## Summary Checklist

- [ ] `request_files` table created
- [ ] RLS policies added to `request_files` table
- [ ] `request-files` storage bucket created
- [ ] Storage bucket is **Public**
- [ ] Three storage policies created (SELECT, INSERT, DELETE)
- [ ] Tested file upload as requester
- [ ] Tested file download as helper

## Need Help?

If you encounter any issues:
1. Check the Supabase Dashboard logs (Settings > Logs)
2. Check browser console for errors
3. Verify all SQL commands ran successfully
4. Make sure bucket name matches exactly: `request-files`




