-- Add status field to product_plans table
-- status: boolean field to indicate if plan is active (true) or inactive (false)
-- This is different from deleted_at which is used for soft delete (recycle bin)

-- Add column with default value first (nullable)
alter table public.product_plans
add column if not exists status boolean default true;

-- Update existing plans to be active by default
update public.product_plans
set status = true
where status is null;

-- Now make it not null
alter table public.product_plans
alter column status set not null;

-- Add comment to clarify the difference
comment on column public.product_plans.status is 'Indicates if the plan is active (true) or inactive (false). This is independent from deleted_at which is used for soft delete.';
