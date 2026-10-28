-- ============================================================================
-- Scholar Wallet — Supabase schema
-- Run this ONCE in the Supabase SQL editor of your project, then create a
-- PUBLIC storage bucket named `receipts` (or run the storage insert below).
-- ============================================================================

-- Profiles: one row per Firebase Auth user (id = Firebase UID)
create table if not exists profiles (
  id text primary key,
  full_name text not null,
  email text,
  role text not null default 'scholar',        -- 'scholar' | 'admin'
  balance numeric not null default 0,
  student_number text,
  university text,
  program text,
  year_level text,
  is_active boolean not null default true,      -- FR-23
  fcm_token text,                               -- FR-25
  created_at timestamptz not null default now()
);

-- Wallet ledger (FR-12)
create table if not exists transactions (
  id bigint generated always as identity primary key,
  scholar_id text not null references profiles(id),
  title text not null,
  subtitle text,
  amount numeric not null,                      -- + credit / - debit
  type text not null,                           -- 'credit' | 'debit'
  status text not null default 'completed',     -- 'completed' | 'pending' | 'rejected'
  batch_id text,
  created_at timestamptz not null default now()
);

-- Withdrawal / cash-out requests (FR-09 – FR-11, FR-22)
create table if not exists withdrawals (
  id bigint generated always as identity primary key,
  scholar_id text not null references profiles(id),
  account_name text not null,
  account_number text not null,
  payment_method text not null,                 -- GCash | PayMaya | Bank Transfer
  amount numeric not null,
  notes text,
  status text not null default 'pending',       -- 'pending' | 'approved' | 'rejected'
  created_at timestamptz not null default now()
);

-- Expense reports / liquidation (FR-15 – FR-17)
create table if not exists expenses (
  id bigint generated always as identity primary key,
  scholar_id text not null references profiles(id),
  title text not null,
  amount numeric not null,
  category text,
  description text,
  receipt_url text,
  status text not null default 'pending',       -- 'pending' | 'completed' | 'rejected'
  created_at timestamptz not null default now()
);

-- Disbursement batches (FR-21, FR-24)
create table if not exists disbursements (
  id text primary key,
  title text not null,
  amount_per_scholar numeric not null,
  recipient_count int not null,
  status text not null default 'completed',
  created_at timestamptz not null default now()
);

-- Atomic balance adjustment used by disbursements and payout approvals
create or replace function adjust_balance(p_scholar_id text, p_delta numeric)
returns void language sql as $$
  update profiles
     set balance = coalesce(balance, 0) + p_delta
   where id = p_scholar_id;
$$;

-- Public receipts bucket for receipt uploads (FR-16)
insert into storage.buckets (id, name, public)
values ('receipts', 'receipts', true)
on conflict (id) do nothing;

-- ----------------------------------------------------------------------------
-- Row Level Security: this demo build talks to Supabase with the anon key
-- without Supabase Auth sessions (auth is Firebase), so the simplest working
-- setup is RLS disabled. For production, enable RLS and add policies instead.
-- ----------------------------------------------------------------------------
alter table profiles      disable row level security;
alter table transactions  disable row level security;
alter table withdrawals   disable row level security;
alter table expenses      disable row level security;
alter table disbursements disable row level security;

-- To make an account an ADMIN, create the user in the app, then run:
--   update profiles set role = 'admin' where email = 'admin@school.edu';
