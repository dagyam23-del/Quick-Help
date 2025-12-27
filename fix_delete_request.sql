-- Fix for request deletion issue
-- Run this in Supabase SQL Editor

-- Step 1: Drop the old CHECK constraint
ALTER TABLE requests DROP CONSTRAINT IF EXISTS requests_status_check;

-- Step 2: Add new CHECK constraint that includes 'deleted'
ALTER TABLE requests ADD CONSTRAINT requests_status_check 
  CHECK (status IN ('open', 'taken', 'completed', 'deleted'));

-- Step 3: Add specific policy for deletion (if it doesn't exist)
-- This allows requester to set status to 'deleted'
DROP POLICY IF EXISTS "Requester can delete their own requests" ON requests;

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



