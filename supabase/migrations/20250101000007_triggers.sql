-- ==============================================================================
-- TRIGGERS
-- ==============================================================================
-- All database triggers consolidated in one file
-- ==============================================================================

-- ====================== AUTH TRIGGER ======================
-- Function to handle new user registration
-- Automatically creates profile and assigns super_admin role if user is in whitelist
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

-- ====================== AUTOMATIC TIMESTAMP UPDATES ======================
-- Automatic timestamp updates using moddatetime extension
create trigger handle_updated_at before update on public.organizations
  for each row execute procedure moddatetime (updated_at);

create trigger handle_updated_at before update on public.profiles
  for each row execute procedure moddatetime (updated_at);

create trigger handle_entitlements_updated_at before update on public.entitlements
  for each row execute procedure public.moddatetime(updated_at);

create trigger handle_plans_updated_at before update on public.plans
  for each row execute procedure public.moddatetime(updated_at);

create trigger handle_product_plans_updated_at before update on public.product_plans
  for each row execute procedure public.moddatetime(updated_at);

create trigger handle_updated_at before update on public.role_templates
  for each row execute procedure moddatetime (updated_at);

-- Trigger for recycle_bin updated_at
create trigger handle_recycle_bin_updated_at 
  before update on public.recycle_bin
  for each row 
  execute procedure moddatetime(updated_at);

-- ====================== TRIAL VALIDATION TRIGGER ======================
-- Trigger function to validate and set trial dates
CREATE OR REPLACE FUNCTION public.validate_trial_dates()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_trial_days integer;
BEGIN
  -- If status is 'trial', ensure trial dates are set
  IF NEW.status = 'trial' THEN
    -- If trial_starts_at is null, set it to now
    IF NEW.trial_starts_at IS NULL THEN
      NEW.trial_starts_at := now();
    END IF;
    
    -- Calculate trial_ends_at based on product's trial_days
    IF NEW.trial_ends_at IS NULL THEN
      -- Get trial_days from the product
      SELECT trial_days INTO v_trial_days
      FROM public.products
      WHERE id = NEW.product_id;
      
      -- If product has trial_days configured, calculate trial_ends_at
      IF v_trial_days IS NOT NULL AND v_trial_days > 0 THEN
        NEW.trial_ends_at := NEW.trial_starts_at + (v_trial_days || ' days')::interval;
      END IF;
      -- If v_trial_days is NULL or 0, trial_ends_at remains NULL (unlimited trial)
    END IF;
  END IF;

  -- If status is NOT 'trial', clear trial dates
  IF NEW.status != 'trial' THEN
    NEW.trial_starts_at := NULL;
    NEW.trial_ends_at := NULL;
  END IF;

  RETURN NEW;
END;
$$;

-- Create trigger
DROP TRIGGER IF EXISTS validate_trial_dates_trigger ON public.org_product_subscriptions;
CREATE TRIGGER validate_trial_dates_trigger
  BEFORE INSERT OR UPDATE ON public.org_product_subscriptions
  FOR EACH ROW
  EXECUTE FUNCTION public.validate_trial_dates();

COMMENT ON FUNCTION public.validate_trial_dates() IS 'Trigger function that automatically sets trial_starts_at when status is set to trial, calculates trial_ends_at based on products.trial_days, and clears trial dates when status is changed from trial.';
