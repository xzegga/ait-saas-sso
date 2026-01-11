-- Add status field to products table
-- status: boolean field to indicate if product is active (true) or inactive (false)
-- This is different from deleted_at which is used for soft delete (recycle bin)

-- Add column with default value first (nullable)
alter table public.products
add column if not exists status boolean default true;

-- Update existing products to be active by default
update public.products
set status = true
where status is null;

-- Now make it not null
alter table public.products
alter column status set not null;

-- Add comment to clarify the difference
comment on column public.products.status is 'Indicates if the product is active (true) or inactive (false). This is independent from deleted_at which is used for soft delete.';
