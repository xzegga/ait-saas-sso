-- ==============================================================================
-- REMOVE DEFAULT DAY AND WEEK INTERVALS
-- ==============================================================================
-- This migration removes the default "day" and "week" billing intervals
-- that were created in the initial migration, keeping only "month" and "year".
-- ==============================================================================

-- Delete day and week intervals if they exist (only if they are the default ones)
delete from public.billing_intervals 
where (key = 'day' and label = 'Daily' and days = 1)
   or (key = 'week' and label = 'Weekly' and days = 7);

-- Alternative: Soft delete them instead of hard delete
-- update public.billing_intervals 
-- set deleted_at = now(), is_active = false
-- where key in ('day', 'week');
