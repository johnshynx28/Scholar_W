-- ============================================================================
-- Scholar Wallet - COMPLETE Supabase setup (ONE file, safe to re-run).
--
-- Replaces: supabase_schema.sql, supabase_setup_fixed.sql,
--           supabase_registration_verification.sql,
--           supabase_no_watcher_and_delete.sql, supabase_cashout.sql
--
-- Run this ONE file in the Supabase SQL Editor. Nothing else is needed.
-- Also required once: Supabase Dashboard > Authentication > Third-Party Auth
-- > add your Firebase project.
--
-- Firebase tokens need NO custom claim, so requests arrive as role `anon`.
-- That is safe: every policy and RPC is keyed on wallet_uid() (the verified
-- Firebase `sub`). No valid token -> wallet_uid() is NULL -> matches nothing.
--
-- To make an account an ADMIN (after the user signs up in the app):
--   update public.profiles set role = 'admin' where email = 'admin@school.edu';
-- ============================================================================
begin;

-- ------------------------------------------------------------------ tables
-- One row per Firebase user (id = Firebase UID, so text, never uuid).
create table if not exists public.profiles (
  id text primary key,
  full_name text not null default '',
  email text,
  role text not null default 'scholar',            -- 'scholar' | 'admin'
  balance numeric not null default 0,
  student_number text,
  university text,
  program text,
  year_level text,
  is_active boolean not null default false,        -- only verified + active get paid
  fcm_token text,
  biometric_registered boolean not null default false,
  biometric_enrolled_at timestamptz,
  declared_scholar boolean not null default false,
  scholarship_name text not null default '',
  scholarship_reference text not null default '',
  verification_status text not null default 'pending'
    check (verification_status in ('pending','under_review','needs_info','approved','rejected')),
  review_notes text not null default '',
  reviewed_by text,
  reviewed_at timestamptz,
  created_at timestamptz not null default now()
);

-- Re-run on an existing project: add anything that is missing.
alter table public.profiles add column if not exists full_name text not null default '';
alter table public.profiles add column if not exists email text;
alter table public.profiles add column if not exists role text not null default 'scholar';
alter table public.profiles add column if not exists balance numeric not null default 0;
alter table public.profiles add column if not exists student_number text;
alter table public.profiles add column if not exists university text;
alter table public.profiles add column if not exists program text;
alter table public.profiles add column if not exists year_level text;
alter table public.profiles add column if not exists is_active boolean not null default false;
alter table public.profiles add column if not exists fcm_token text;
alter table public.profiles add column if not exists biometric_registered boolean not null default false;
alter table public.profiles add column if not exists biometric_enrolled_at timestamptz;
alter table public.profiles add column if not exists declared_scholar boolean not null default false;
alter table public.profiles add column if not exists scholarship_name text not null default '';
alter table public.profiles add column if not exists scholarship_reference text not null default '';
alter table public.profiles add column if not exists verification_status text not null default 'pending'
  check (verification_status in ('pending','under_review','needs_info','approved','rejected'));
alter table public.profiles add column if not exists review_notes text not null default '';
alter table public.profiles add column if not exists reviewed_by text;
alter table public.profiles add column if not exists reviewed_at timestamptz;
alter table public.profiles add column if not exists created_at timestamptz not null default now();
alter table public.profiles alter column is_active set default false;
update public.profiles set is_active = false
  where role = 'scholar' and verification_status <> 'approved';
create index if not exists profiles_verification_idx on public.profiles(role, verification_status);

-- ONE global Standard Allowance (row id = 1). No per-scholar amount anywhere.
create table if not exists public.allowance_settings (
  id int primary key default 1,
  allowance_amount numeric not null default 5000,
  label text not null default 'Monthly Allowance',
  updated_at timestamptz not null default now(),
  constraint allowance_settings_single_row check (id = 1)
);
insert into public.allowance_settings (id, allowance_amount, label)
  values (1, 5000, 'Monthly Allowance') on conflict (id) do nothing;

-- Wallet ledger (+ credit / - debit)
create table if not exists public.transactions (
  id bigint generated always as identity primary key,
  scholar_id text not null references public.profiles(id),
  title text not null,
  subtitle text,
  amount numeric not null,
  type text not null,                              -- 'credit' | 'debit'
  status text not null default 'completed',
  batch_id text,
  created_at timestamptz not null default now()
);
alter table public.transactions add column if not exists subtitle text;
alter table public.transactions add column if not exists status text not null default 'completed';
alter table public.transactions add column if not exists batch_id text;

-- Payout Events (one disbursement batch)
create table if not exists public.disbursements (
  id text primary key,
  title text not null,
  amount_per_scholar numeric not null,
  recipient_count int not null,
  status text not null default 'issued',           -- 'issued' | 'completed'
  created_at timestamptz not null default now()
);

-- Payout QR: one single-use claim per scholar per payout.
--   issued   = amount reserved, waiting for scan
--   received = scanned + biometric confirmed, balance credited
--   voided   = admin cancelled before it was scanned
create table if not exists public.allowance_claims (
  id bigint generated always as identity primary key,
  batch_id text not null,
  batch_title text not null default 'Allowance',
  scholar_id text not null references public.profiles(id),
  amount numeric not null,
  token text not null unique,
  status text not null default 'issued',
  issued_at timestamptz not null default now(),
  claimed_at timestamptz
);
alter table public.allowance_claims add column if not exists batch_title text not null default 'Allowance';
alter table public.allowance_claims add column if not exists issued_at timestamptz not null default now();
alter table public.allowance_claims add column if not exists claimed_at timestamptz;
create index if not exists allowance_claims_scholar_idx on public.allowance_claims(scholar_id, status);

-- Registration Verification history
create table if not exists public.registration_reviews (
  id bigint generated always as identity primary key,
  scholar_id text not null references public.profiles(id),
  reviewer_id text references public.profiles(id),
  from_status text not null,
  decision text not null,
  notes text not null default '',
  created_at timestamptz not null default now()
);

-- Cash Out MOCKUP: saved account details only, nothing is verified or sent.
create table if not exists public.linked_accounts (
  id bigint generated always as identity primary key,
  scholar_id text not null references public.profiles(id),
  provider text not null check (provider in ('gcash','maya','bank')),
  bank_name text not null default '',
  account_name text not null,
  account_number text not null,
  created_at timestamptz not null default now(),
  unique (scholar_id, provider, account_number)
);

create table if not exists public.withdrawals (
  id bigint generated always as identity primary key,
  scholar_id text not null references public.profiles(id),
  amount numeric not null check (amount > 0),
  -- Snapshot, so history stays correct if the account is unlinked later.
  provider text not null,
  bank_name text not null default '',
  account_name text not null,
  account_number text not null,
  status text not null default 'completed'
    check (status in ('pending','completed','rejected','cancelled')),
  reference text not null default '',              -- simulated reference
  admin_note text not null default '',
  processed_at timestamptz,
  created_at timestamptz not null default now()
);
create index if not exists withdrawals_scholar_idx on public.withdrawals(scholar_id, created_at desc);

-- --------------------------------------------------------------- helpers
create or replace function public.wallet_uid() returns text
language sql stable set search_path = '' as $$
  select nullif(auth.jwt()->>'sub', '')
$$;

create or replace function public.wallet_is_admin() returns boolean
language sql stable security definer set search_path = '' as $$
  select exists(select 1 from public.profiles
    where id = public.wallet_uid() and role = 'admin')
$$;

create or replace function public.wallet_is_verified() returns boolean
language sql stable security definer set search_path = '' as $$
  select exists(select 1 from public.profiles where id = public.wallet_uid()
    and role = 'scholar' and verification_status = 'approved' and is_active)
$$;

-- ------------------------------------------- registration verification RPCs
create or replace function public.review_registration(
  p_scholar_id text, p_expected_status text, p_decision text, p_notes text,
  p_roster_checked boolean default false
) returns void language plpgsql security definer set search_path = '' as $$
declare v public.profiles;
begin
  if not public.wallet_is_admin() then raise exception 'ADMIN_REQUIRED'; end if;
  select * into v from public.profiles where id = p_scholar_id and role = 'scholar' for update;
  if not found then raise exception 'REGISTRATION_NOT_FOUND'; end if;
  if v.verification_status <> p_expected_status then raise exception 'STALE_REVIEW'; end if;
  if v.verification_status in ('approved','rejected') then raise exception 'REGISTRATION_ALREADY_DECIDED'; end if;
  if p_decision is null or p_decision not in ('under_review','needs_info','approved','rejected') then
    raise exception 'INVALID_DECISION';
  end if;
  if p_decision = v.verification_status then raise exception 'NO_STATUS_CHANGE'; end if;
  if p_decision in ('needs_info','rejected') and length(trim(coalesce(p_notes,''))) = 0 then
    raise exception 'REASON_REQUIRED';
  end if;
  if p_decision = 'approved' and (not coalesce(p_roster_checked,false) or
      not v.declared_scholar or length(trim(v.scholarship_name)) = 0) then
    raise exception 'VERIFY_OFFICIAL_ROSTER_FIRST';
  end if;
  update public.profiles set verification_status = p_decision,
    is_active = (p_decision = 'approved'), review_notes = trim(coalesce(p_notes,'')),
    reviewed_by = public.wallet_uid(), reviewed_at = now() where id = v.id;
  insert into public.registration_reviews(scholar_id,reviewer_id,from_status,decision,notes)
    values(v.id, public.wallet_uid(), v.verification_status, p_decision, trim(coalesce(p_notes,'')));
end;
$$;

create or replace function public.resubmit_registration(
  p_declared_scholar boolean, p_scholarship_name text, p_scholarship_reference text
) returns void language plpgsql security definer set search_path = '' as $$
declare v public.profiles;
begin
  select * into v from public.profiles where id = public.wallet_uid() and role = 'scholar' for update;
  if not found or v.verification_status <> 'needs_info' then raise exception 'INFORMATION_NOT_REQUESTED'; end if;
  if p_declared_scholar is null then raise exception 'DECLARATION_REQUIRED'; end if;
  if p_declared_scholar and length(trim(coalesce(p_scholarship_name,''))) = 0 then
    raise exception 'SCHOLARSHIP_NAME_REQUIRED';
  end if;
  update public.profiles set declared_scholar = p_declared_scholar,
    scholarship_name = case when p_declared_scholar then trim(p_scholarship_name) else '' end,
    scholarship_reference = case when p_declared_scholar then trim(coalesce(p_scholarship_reference,'')) else '' end,
    verification_status = 'pending', is_active = false
    where id = v.id;
  insert into public.registration_reviews(scholar_id,from_status,decision,notes)
    values(v.id,'needs_info','pending','Student updated requested verification details.');
end;
$$;

create or replace function public.set_verified_scholar_active(p_scholar_id text, p_active boolean)
returns void language plpgsql security definer set search_path = '' as $$
declare v public.profiles;
begin
  if not public.wallet_is_admin() then raise exception 'ADMIN_REQUIRED'; end if;
  select * into v from public.profiles where id = p_scholar_id and role = 'scholar' for update;
  if not found or v.verification_status <> 'approved' then raise exception 'SCHOLAR_NOT_VERIFIED'; end if;
  update public.profiles set is_active = p_active where id = v.id;
  insert into public.registration_reviews(scholar_id,reviewer_id,from_status,decision,notes)
    values(v.id,public.wallet_uid(),'approved','approved',
      case when p_active then 'Payout access activated.' else 'Payout access deactivated.' end);
end;
$$;

-- ----------------------------------------------------------- payout RPCs
-- One transaction: an invalid recipient rolls back the whole batch.
create or replace function public.issue_verified_payout(p_title text, p_recipients text[])
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_batch text := gen_random_uuid()::text; v_amount numeric; v_title text;
  v_ids text[]; v_id text; v_profile public.profiles; v_result jsonb;
begin
  if not public.wallet_is_admin() then raise exception 'ADMIN_REQUIRED'; end if;
  select array_agg(distinct x order by x) into v_ids from unnest(p_recipients) x;
  if coalesce(array_length(v_ids,1),0) = 0 then raise exception 'RECIPIENTS_REQUIRED'; end if;
  select allowance_amount, coalesce(nullif(trim(p_title),''),label)
    into v_amount,v_title from public.allowance_settings where id = 1 for share;
  if v_amount is null or v_amount <= 0 then raise exception 'INVALID_ALLOWANCE'; end if;
  foreach v_id in array v_ids loop
    select * into v_profile from public.profiles where id = v_id for update;
    if not found or v_profile.role <> 'scholar' or
      v_profile.verification_status <> 'approved' or not v_profile.is_active then
      raise exception 'SCHOLAR_NOT_VERIFIED';
    end if;
  end loop;
  insert into public.disbursements(id,title,amount_per_scholar,recipient_count,status)
    values(v_batch,v_title,v_amount,array_length(v_ids,1),'issued');
  insert into public.allowance_claims(batch_id,batch_title,scholar_id,amount,token,status)
    select v_batch,v_title,x,v_amount,replace(gen_random_uuid()::text,'-',''),'issued'
      from unnest(v_ids) x;
  select jsonb_agg(to_jsonb(c) || jsonb_build_object('scholar_name', p.full_name))
    into v_result from public.allowance_claims c join public.profiles p on p.id = c.scholar_id
    where c.batch_id = v_batch;
  return v_result;
end;
$$;

-- Single-use receipt. Device biometrics protect the UI; this RPC does not
-- claim to attest a fingerprint on the server.
create or replace function public.claim_allowance(p_token text, p_scholar_id text)
returns numeric language plpgsql security definer set search_path = '' as $$
declare v_claim public.allowance_claims; v_profile public.profiles;
begin
  if public.wallet_uid() is null or p_scholar_id is distinct from public.wallet_uid() then
    raise exception 'CLAIM_WRONG_SCHOLAR';
  end if;
  select * into v_profile from public.profiles where id = public.wallet_uid() for update;
  if not found or v_profile.role <> 'scholar' or
      v_profile.verification_status <> 'approved' or not v_profile.is_active then
    raise exception 'SCHOLAR_NOT_VERIFIED';
  end if;
  select * into v_claim from public.allowance_claims where token = p_token for update;
  if not found then raise exception 'CLAIM_NOT_FOUND'; end if;
  if v_claim.scholar_id <> public.wallet_uid() then raise exception 'CLAIM_WRONG_SCHOLAR'; end if;
  if v_claim.status = 'received' then raise exception 'CLAIM_ALREADY_RECEIVED'; end if;
  if v_claim.status <> 'issued' then raise exception 'CLAIM_VOIDED'; end if;
  if v_claim.amount <= 0 then raise exception 'INVALID_ALLOWANCE'; end if;
  update public.allowance_claims set status = 'received', claimed_at = now() where id = v_claim.id;
  update public.profiles set balance = balance + v_claim.amount where id = public.wallet_uid();
  insert into public.transactions(scholar_id,title,subtitle,amount,type,status,batch_id)
    values(public.wallet_uid(),v_claim.batch_title,'Allowance receipt confirmed',v_claim.amount,'credit','completed',v_claim.batch_id);
  -- A batch is completed only when no issued claims remain.
  update public.disbursements d set status = 'completed' where d.id = v_claim.batch_id
    and not exists(select 1 from public.allowance_claims c where c.batch_id = d.id and c.status = 'issued');
  return v_claim.amount;
end;
$$;

-- ------------------------------------------------- Cash Out (mockup) RPCs
create or replace function public.link_account(
  p_provider text, p_bank_name text, p_account_name text, p_account_number text)
returns bigint language plpgsql security definer set search_path = '' as $$
declare v_num text := regexp_replace(coalesce(p_account_number,''), '[^0-9]', '', 'g');
        v_id bigint;
begin
  if not public.wallet_is_verified() then raise exception 'SCHOLAR_NOT_VERIFIED'; end if;
  if p_provider not in ('gcash','maya','bank') then raise exception 'BAD_PROVIDER'; end if;
  if length(trim(coalesce(p_account_name,''))) < 2 then raise exception 'BAD_ACCOUNT_NAME'; end if;
  if p_provider in ('gcash','maya') and v_num !~ '^09[0-9]{9}$' then
    raise exception 'BAD_MOBILE_NUMBER';
  end if;
  if p_provider = 'bank' then
    if length(trim(coalesce(p_bank_name,''))) < 2 then raise exception 'BAD_BANK_NAME'; end if;
    if length(v_num) < 8 or length(v_num) > 20 then raise exception 'BAD_ACCOUNT_NUMBER'; end if;
  end if;
  insert into public.linked_accounts(scholar_id, provider, bank_name, account_name, account_number)
    values (public.wallet_uid(), p_provider,
            case when p_provider = 'bank' then trim(p_bank_name) else '' end,
            trim(p_account_name), v_num)
    returning id into v_id;
  return v_id;
exception when unique_violation then
  raise exception 'ACCOUNT_ALREADY_LINKED';
end;
$$;

create or replace function public.unlink_account(p_account_id bigint)
returns void language plpgsql security definer set search_path = '' as $$
begin
  delete from public.linked_accounts
   where id = p_account_id and scholar_id = public.wallet_uid();
end;
$$;

-- Simulated cash-out: minimum PHP 100, max 2 decimals, never below zero.
create or replace function public.request_withdrawal(p_account_id bigint, p_amount numeric)
returns bigint language plpgsql security definer set search_path = '' as $$
declare v_profile public.profiles; v_acc public.linked_accounts;
        v_id bigint; v_label text;
begin
  select * into v_profile from public.profiles where id = public.wallet_uid() for update;
  if not found or v_profile.role <> 'scholar' or
     v_profile.verification_status <> 'approved' or not v_profile.is_active then
    raise exception 'SCHOLAR_NOT_VERIFIED';
  end if;
  select * into v_acc from public.linked_accounts
   where id = p_account_id and scholar_id = public.wallet_uid();
  if not found then raise exception 'ACCOUNT_NOT_FOUND'; end if;
  if p_amount is null or p_amount < 100 then raise exception 'BELOW_MINIMUM'; end if;
  if p_amount <> round(p_amount, 2) then raise exception 'BAD_AMOUNT'; end if;
  if v_profile.balance < p_amount then raise exception 'INSUFFICIENT_BALANCE'; end if;

  insert into public.withdrawals(scholar_id, amount, provider, bank_name, account_name,
                                 account_number, status, reference, processed_at)
    values (public.wallet_uid(), p_amount, v_acc.provider, v_acc.bank_name,
            v_acc.account_name, v_acc.account_number, 'completed',
            'SIM-' || upper(substr(md5(random()::text || clock_timestamp()::text), 1, 8)), now())
    returning id into v_id;

  update public.profiles set balance = balance - p_amount where id = public.wallet_uid();

  v_label := case v_acc.provider when 'gcash' then 'GCash' when 'maya' then 'Maya'
             else coalesce(nullif(v_acc.bank_name,''),'Bank') end;
  insert into public.transactions(scholar_id, title, subtitle, amount, type, status)
    values (public.wallet_uid(), 'Cash-out to ' || v_label,
            'Simulated transfer (demo, no real money)', -p_amount, 'debit', 'completed');
  return v_id;
end;
$$;

-- ---------------------------------------------------- admin delete RPCs
-- Deletes ONE scholar and their data. Never deletes admins; refuses accounts
-- that still hold a balance.
create or replace function public.admin_delete_scholar(p_scholar_id text)
returns void language plpgsql security definer set search_path = '' as $$
declare v public.profiles;
begin
  if not public.wallet_is_admin() then raise exception 'ADMIN_REQUIRED'; end if;
  select * into v from public.profiles where id = p_scholar_id for update;
  if not found then raise exception 'ACCOUNT_NOT_FOUND'; end if;
  if v.role <> 'scholar' then raise exception 'CANNOT_DELETE_ADMIN'; end if;
  if coalesce(v.balance, 0) <> 0 then raise exception 'BALANCE_NOT_ZERO'; end if;

  delete from public.withdrawals where scholar_id = v.id;
  delete from public.linked_accounts where scholar_id = v.id;
  delete from public.registration_reviews where scholar_id = v.id;
  delete from public.allowance_claims where scholar_id = v.id;
  delete from public.transactions where scholar_id = v.id;
  delete from public.profiles where id = v.id;
exception when foreign_key_violation then
  raise exception 'HAS_LINKED_RECORDS';
end;
$$;

-- Deletes every rejected / deactivated scholar with a zero balance. Accounts
-- still waiting for a decision are NOT touched. Returns how many were deleted.
create or replace function public.admin_delete_inactive_scholars()
returns integer language plpgsql security definer set search_path = '' as $$
declare r record; n integer := 0;
begin
  if not public.wallet_is_admin() then raise exception 'ADMIN_REQUIRED'; end if;
  for r in select id from public.profiles
    where role = 'scholar' and not is_active and coalesce(balance, 0) = 0
      and verification_status in ('rejected', 'approved')
  loop
    begin
      perform public.admin_delete_scholar(r.id);
      n := n + 1;
    exception when others then
      null; -- skip accounts that cannot be deleted, continue with the rest
    end;
  end loop;
  return n;
end;
$$;

-- --------------------------------------------- row-level security + grants
do $$ declare t text; p record; begin
  foreach t in array array['profiles','registration_reviews','transactions',
    'disbursements','allowance_claims','allowance_settings','linked_accounts','withdrawals'] loop
    execute format('alter table public.%I enable row level security', t);
    for p in select policyname from pg_policies where schemaname = 'public' and tablename = t loop
      execute format('drop policy %I on public.%I', p.policyname, t);
    end loop;
    execute format('revoke all on public.%I from anon, authenticated', t);
  end loop;
end $$;

grant usage on schema public to anon, authenticated;

-- profiles: self-registration only as a pending scholar; never self-approve.
grant select, insert on public.profiles to anon, authenticated;
grant update (fcm_token, biometric_registered, biometric_enrolled_at)
  on public.profiles to anon, authenticated;
create policy profiles_read on public.profiles for select to anon, authenticated
  using (id = public.wallet_uid() or public.wallet_is_admin());
create policy profiles_register on public.profiles for insert to anon, authenticated
  with check (
    id = public.wallet_uid() and email = auth.jwt()->>'email' and role = 'scholar'
    and balance = 0 and verification_status = 'pending' and not is_active
    and reviewed_by is null and reviewed_at is null and review_notes = ''
    and (not declared_scholar or length(trim(scholarship_name)) > 0)
  );
create policy profiles_device_update on public.profiles for update to anon, authenticated
  using (id = public.wallet_uid()) with check (id = public.wallet_uid());

-- read-only tables (all writes go through the RPCs above)
grant select on public.registration_reviews, public.transactions,
  public.linked_accounts, public.withdrawals to anon, authenticated;
create policy reviews_read on public.registration_reviews for select to anon, authenticated
  using (scholar_id = public.wallet_uid() or public.wallet_is_admin());
create policy transactions_read on public.transactions for select to anon, authenticated
  using (scholar_id = public.wallet_uid() or public.wallet_is_admin());
create policy linked_read on public.linked_accounts for select to anon, authenticated
  using (scholar_id = public.wallet_uid() or public.wallet_is_admin());
create policy withdrawals_read on public.withdrawals for select to anon, authenticated
  using (scholar_id = public.wallet_uid() or public.wallet_is_admin());

grant select on public.disbursements to anon, authenticated;
create policy batches_read on public.disbursements for select to anon, authenticated
  using (public.wallet_is_admin() or exists(select 1 from public.allowance_claims c
    where c.batch_id = disbursements.id and c.scholar_id = public.wallet_uid()));

-- allowance_claims: admin may only void an issued claim.
grant select on public.allowance_claims to anon, authenticated;
grant update (status) on public.allowance_claims to anon, authenticated;
create policy claims_read on public.allowance_claims for select to anon, authenticated
  using (scholar_id = public.wallet_uid() or public.wallet_is_admin());
create policy claims_void on public.allowance_claims for update to anon, authenticated
  using (public.wallet_is_admin() and status = 'issued')
  with check (public.wallet_is_admin() and status = 'voided');

-- allowance_settings: any signed-in user reads; only admin changes.
grant select, insert, update on public.allowance_settings to anon, authenticated;
create policy settings_read on public.allowance_settings for select to anon, authenticated
  using (public.wallet_uid() is not null);
create policy settings_insert on public.allowance_settings for insert to anon, authenticated
  with check (public.wallet_is_admin() and id = 1 and allowance_amount > 0);
create policy settings_update on public.allowance_settings for update to anon, authenticated
  using (public.wallet_is_admin())
  with check (public.wallet_is_admin() and id = 1 and allowance_amount > 0);

-- RPC execute rights (no PUBLIC access).
do $$ declare f record; begin
  for f in select p.oid::regprocedure signature from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname in ('wallet_uid','wallet_is_admin',
      'wallet_is_verified','review_registration','resubmit_registration',
      'set_verified_scholar_active','issue_verified_payout','claim_allowance',
      'link_account','unlink_account','request_withdrawal',
      'admin_delete_scholar','admin_delete_inactive_scholars') loop
    execute format('revoke all on function %s from public', f.signature);
    execute format('grant execute on function %s to anon, authenticated', f.signature);
  end loop;
end $$;

-- Clean up leftovers from older versions of this project.
drop function if exists public.adjust_balance(text, numeric);

commit;
