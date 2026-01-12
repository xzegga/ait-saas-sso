-- Create role_templates table for storing role templates
create table public.role_templates (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  description text,
  roles jsonb not null, -- Array of role definitions: [{role_name: string, is_default: boolean}]
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  created_by uuid references auth.users(id) on delete set null
);

-- Enable RLS
alter table public.role_templates enable row level security;

-- Create index for faster lookups
create index idx_role_templates_name on public.role_templates(name);

-- Automatic timestamp updates
create trigger handle_updated_at before update on public.role_templates
  for each row execute procedure moddatetime (updated_at);
