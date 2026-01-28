-- ==============================================================================
-- AUTH TRIGGER - Handle New User Registration
-- ==============================================================================
-- Automatically creates profile and assigns super_admin role if user is in whitelist
-- ==============================================================================

-- Function to handle new user registration
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  user_role text;
begin
  -- 1. Determine Global Role (Check Whitelist)
  if exists (select 1 from public.super_admins where lower(email) = lower(new.email)) then
    user_role := 'super_admin';
    raise log 'HandleNewUser: Assigned super_admin to %', new.email;
  else
    user_role := 'user';
  end if;

  -- 2. Create Profile
  insert into public.profiles (id, email, full_name, role)
  values (new.id, new.email, new.raw_user_meta_data->>'full_name', user_role);

  return new;
end;
$$;

-- Connect the Trigger
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();
