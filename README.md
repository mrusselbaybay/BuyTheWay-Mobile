-- Add region column to logistics_companies
ALTER TABLE public.logistics_companies 
ADD COLUMN IF NOT EXISTS region TEXT;

-- Add comment for documentation
COMMENT ON COLUMN public.logistics_companies.region IS 'Region where the logistics company is located';

create type public.application_status as enum (
  'pending',
  'accepted',
  'rejected',
  'withdrawn'   -- courier cancels their own pending application
);

create table public.courier_applications (
  id                    uuid primary key default gen_random_uuid(),
  courier_profile_id    uuid not null references public.profiles(id) on delete cascade,
  logistics_company_id  uuid not null references public.logistics_companies(id) on delete cascade,

  status                public.application_status not null default 'pending',
  applied_at            timestamptz not null default now(),
  reviewed_by           uuid references public.profiles(id),
  reviewed_at           timestamptz,
  rejection_reason      text,

  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now(),

  unique (courier_profile_id, logistics_company_id)
);

alter table public.courier_details
  add column if not exists logistics_company_id uuid references public.logistics_companies(id);

create index idx_courier_applications_company on public.courier_applications (logistics_company_id);
create index idx_courier_applications_courier on public.courier_applications (courier_profile_id);
create index idx_courier_details_company on public.courier_details (logistics_company_id);

drop index if exists courier_applications_courier_profile_id_logistics_company_id_key;
create unique index courier_applications_active_unique
  on public.courier_applications (courier_profile_id, logistics_company_id)
  where status in ('pending', 'accepted');

-- A courier may withdraw only their own pending application. The Laravel
-- endpoint PATCH /courier/applications/{application}/withdraw should invoke
-- this function using the authenticated courier's Supabase JWT.
create or replace function public.withdraw_courier_application(
  p_application_id uuid
)
returns void
language plpgsql
security definer set search_path = public
as $$
begin
  update public.courier_applications
  set status = 'withdrawn', updated_at = now()
  where id = p_application_id
    and courier_profile_id = auth.uid()
    and status = 'pending';

  if not found then
    raise exception 'Pending courier application not found';
  end if;
end;
$$;

  -- ============================================================
-- WORK / JOB APPLICATIONS SYSTEM
-- ============================================================

-- 1. Create job application status enum
create type public.job_application_status as enum (
  'pending',
  'employed',
  'rejected'
);

-- 2. Create companies table (for job postings)
create table public.companies (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  role text not null,
  region text not null,
  industry text not null,
  salary_range text not null,
  employment_type text not null,
  logo_initial text not null,
  description text not null,
  is_hiring boolean not null default true,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.companies is 'Companies that are hiring for various roles';

-- 3. Create job_applications table
create table public.job_applications (
  id uuid primary key default gen_random_uuid(),
  user_profile_id uuid not null references public.profiles(id) on delete cascade,
  company_id uuid not null references public.companies(id) on delete cascade,
  
  resume_file_name text not null,
  resume_size_bytes bigint not null,
  cover_note text,
  
  status public.job_application_status not null default 'pending',
  submitted_at timestamptz not null default now(),
  reviewed_at timestamptz,
  reviewed_by uuid references public.profiles(id) on delete set null,
  rejection_reason text,
  
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  
  unique (user_profile_id, company_id)
);

comment on table public.job_applications is 'Job applications submitted by users to companies';

-- 4. Add indexes for performance
create index idx_companies_region on public.companies (region);
create index idx_companies_is_hiring on public.companies (is_hiring);
create index idx_companies_role on public.companies (role);
create index idx_job_applications_user on public.job_applications (user_profile_id);
create index idx_job_applications_company on public.job_applications (company_id);
create index idx_job_applications_status on public.job_applications (status);
create index idx_job_applications_submitted on public.job_applications (submitted_at);

-- 5. Create view for user's application summary
create or replace view public.user_application_summary as
select 
  p.id as profile_id,
  p.email,
  p.first_name,
  p.last_name,
  count(ja.id) as total_applications,
  count(ja.id) filter (where ja.status = 'pending') as pending_count,
  count(ja.id) filter (where ja.status = 'employed') as employed_count,
  count(ja.id) filter (where ja.status = 'rejected') as rejected_count
from public.profiles p
left join public.job_applications ja on ja.user_profile_id = p.id
group by p.id, p.email, p.first_name, p.last_name;

comment on view public.user_application_summary is 'Summary of job applications per user';

-- 6. Create function to apply for a job
create or replace function public.apply_to_job(
  p_company_id uuid,
  p_resume_file_name text,
  p_resume_size_bytes bigint,
  p_cover_note text default null
)
returns uuid
language plpgsql
security definer set search_path = public
as $$
declare
  v_user_id uuid;
  v_application_id uuid;
begin
  v_user_id := auth.uid();
  
  -- Check if user already applied to this company
  if exists (
    select 1 from public.job_applications 
    where user_profile_id = v_user_id 
    and company_id = p_company_id
  ) then
    raise exception 'You have already applied to this company';
  end if;
  
  -- Check if company is hiring
  if not exists (
    select 1 from public.companies 
    where id = p_company_id 
    and is_hiring = true
  ) then
    raise exception 'This company is not currently hiring';
  end if;
  
  -- Insert application
  insert into public.job_applications (
    user_profile_id,
    company_id,
    resume_file_name,
    resume_size_bytes,
    cover_note,
    status,
    submitted_at
  ) values (
    v_user_id,
    p_company_id,
    p_resume_file_name,
    p_resume_size_bytes,
    p_cover_note,
    'pending',
    now()
  )
  returning id into v_application_id;
  
  return v_application_id;
end;
$$;

-- 7. Create function to update application status (admin only)
create or replace function public.update_application_status(
  p_application_id uuid,
  p_status public.job_application_status,
  p_rejection_reason text default null
)
returns text
language plpgsql
security definer set search_path = public
as $$
declare
  v_current_status public.job_application_status;
begin
  -- Check if user is admin
  if not public.is_admin() then
    raise exception 'Only admins can update application status';
  end if;
  
  -- Get current status
  select status into v_current_status
  from public.job_applications
  where id = p_application_id;
  
  if v_current_status is null then
    raise exception 'Application not found';
  end if;
  
  -- Update status
  update public.job_applications
  set 
    status = p_status,
    reviewed_at = now(),
    reviewed_by = auth.uid(),
    rejection_reason = case 
      when p_status = 'rejected' then p_rejection_reason 
      else null 
    end
  where id = p_application_id;
  
  return 'Application status updated successfully';
end;
$$;

-- 8. Create function to get user's applications
create or replace function public.get_user_applications()
returns table (
  id uuid,
  company_name text,
  role text,
  region text,
  company_logo_initial text,
  resume_file_name text,
  resume_size_bytes bigint,
  cover_note text,
  status public.job_application_status,
  submitted_at timestamptz,
  rejection_reason text
)
language sql
security definer set search_path = public
as $$
  select 
    ja.id,
    c.name as company_name,
    c.role,
    c.region,
    c.logo_initial as company_logo_initial,
    ja.resume_file_name,
    ja.resume_size_bytes,
    ja.cover_note,
    ja.status,
    ja.submitted_at,
    ja.rejection_reason
  from public.job_applications ja
  join public.companies c on c.id = ja.company_id
  where ja.user_profile_id = auth.uid()
  order by ja.submitted_at desc;
$$;

-- 9. Create function to get open job listings (with filters)
create or replace function public.get_open_jobs(
  p_region text default null,
  p_search text default null
)
returns table (
  id uuid,
  name text,
  role text,
  region text,
  industry text,
  salary_range text,
  employment_type text,
  logo_initial text,
  description text,
  already_applied boolean
)
language sql
security definer set search_path = public
as $$
  select 
    c.id,
    c.name,
    c.role,
    c.region,
    c.industry,
    c.salary_range,
    c.employment_type,
    c.logo_initial,
    c.description,
    exists (
      select 1 from public.job_applications ja
      where ja.company_id = c.id
      and ja.user_profile_id = auth.uid()
    ) as already_applied
  from public.companies c
  where c.is_hiring = true
  and (p_region is null or c.region = p_region)
  and (p_search is null or 
    c.name ilike '%' || p_search || '%' or 
    c.role ilike '%' || p_search || '%'
  )
  order by c.created_at desc;
$$;

-- 10. Create updated_at trigger for new tables
create trigger trg_companies_updated_at 
  before update on public.companies 
  for each row 
  execute function public.set_updated_at();

create trigger trg_job_applications_updated_at 
  before update on public.job_applications 
  for each row 
  execute function public.set_updated_at();

-- 11. RLS Policies
alter table public.companies enable row level security;
alter table public.job_applications enable row level security;

-- Companies: Anyone can view, only admins can manage
create policy "companies_select_public" 
  on public.companies for select 
  using (true);

create policy "companies_insert_admin_only" 
  on public.companies for insert 
  with check (public.is_admin());

create policy "companies_update_admin_only" 
  on public.companies for update 
  using (public.is_admin());

create policy "companies_delete_admin_only" 
  on public.companies for delete 
  using (public.is_admin());

-- Job Applications: Users can view their own, admins can view all
create policy "job_applications_select_own_or_admin" 
  on public.job_applications for select 
  using (
    user_profile_id = auth.uid() 
    or public.is_admin()
  );

create policy "job_applications_insert_own" 
  on public.job_applications for insert 
  with check (user_profile_id = auth.uid());

create policy "job_applications_update_admin_only" 
  on public.job_applications for update 
  using (public.is_admin());

-- 12. Insert sample job postings (optional)
insert into public.companies (
  id, name, role, region, industry, salary_range, employment_type, 
  logo_initial, description, is_hiring, created_at
) values 
(
  gen_random_uuid(), 
  'Brightwave Digital',
  'Flutter Developer',
  'NCR - Metro Manila',
  'Software',
  '₱45k - ₱70k',
  'Full-time',
  'B',
  'Brightwave builds fintech apps used by over 2M users. Looking for a mobile engineer to join our core app team, working closely with design and backend.',
  true,
  now()
),
(
  gen_random_uuid(),
  'Verdant Foods Co.',
  'Logistics Coordinator',
  'Calabarzon',
  'Supply Chain',
  '₱28k - ₱35k',
  'Full-time',
  'V',
  'Verdant Foods manages cold-chain logistics for fresh produce across Luzon. We need a coordinator to manage route planning and vendor relations.',
  true,
  now()
),
(
  gen_random_uuid(),
  'Pixel & Pine Studio',
  'UI/UX Designer',
  'Remote',
  'Design',
  '₱35k - ₱55k',
  'Contract',
  'P',
  'A fully remote product design studio working with startups across Southeast Asia. We value async communication and outcome-driven work.',
  true,
  now()
);

-- 13. Verify everything was created
select table_name 
from information_schema.tables 
where table_schema = 'public' 
and table_name in ('companies', 'job_applications')
order by table_name;

select typname 
from pg_type 
where typname = 'job_application_status';


create extension if not exists "pgcrypto"; -- gen_random_uuid()

-- -------------------------------------------------------------------------
-- 1. Enums
-- -------------------------------------------------------------------------

create type public.user_role as enum (
  'buyer',
  'seller',
  'driver',          -- employed driver under a logistics company
  'courier',         -- independent courier
  'logistics',       -- owner/registrant of a logistics company
  'admin',           -- platform admin (approves everything)
  'logistics_admin'  -- staff account that manages a logistics company's drivers/orders
);

create type public.approval_status as enum (
  'pending',
  'approved',
  'rejected'
);

create type public.sex_type as enum ('Male', 'Female');

create type public.vehicle_type as enum (
  'Motorcycle',
  'Car',
  'Van',
  'Bicycle',
  'Truck'
);

create type public.document_type as enum (
  'valid_id',
  'business_permit',
  'mayors_permit',
  'dti_sec_registration',
  'orcr',
  'drivers_license'
);

-- Polymorphic "who does this address/document belong to" tag.
create type public.owner_kind as enum (
  'profile',
  'logistics_company'
);

-- -------------------------------------------------------------------------
-- 2. profiles  (1:1 with auth.users)
-- -------------------------------------------------------------------------
-- Personal info collected in the "Personal" / "Owner Details" wizard steps.
-- Created automatically by the handle_new_user() trigger below whenever
-- someone signs up through Supabase Auth.

create table public.profiles (
  id              uuid primary key references auth.users (id) on delete cascade,
  role            public.user_role not null default 'buyer',
  status          public.approval_status not null default 'pending',

  last_name       text,
  first_name      text,
  middle_initial  text,
  sex             public.sex_type,
  contact_no      text,
  birthday        date,

  -- denormalized for convenience / search; source of truth is auth.users.email
  email           text,

  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

comment on table public.profiles is 'One row per auth user. Holds role, approval status, and personal info shared by every role.';

-- -------------------------------------------------------------------------
-- 3. addresses  (polymorphic: belongs to a profile OR a logistics company)
-- -------------------------------------------------------------------------
-- house_no is nullable, per the requirement. Province/municipality/barangay
-- names are stored alongside their PSGC codes since the codes are resolved
-- against a third-party API (rootscratch PSGC) that isn't stored locally.

create table public.addresses (
  id                    uuid primary key default gen_random_uuid(),

  owner_kind            public.owner_kind not null,
  profile_id            uuid references public.profiles (id) on delete cascade,
  logistics_company_id  uuid, -- FK added after logistics_companies is created below

  province_code         text not null,
  province_name         text not null,
  municipality_code      text not null,
  municipality_name     text not null,
  barangay              text not null,
  street                text not null,
  house_no              text, -- nullable: unit/house number is optional

  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now(),

  constraint addresses_owner_shape check (
    (owner_kind = 'profile'            and profile_id is not null and logistics_company_id is null) or
    (owner_kind = 'logistics_company'  and logistics_company_id is not null and profile_id is null)
  )
);

comment on table public.addresses is 'Shipping/registration address for a person or a logistics company. house_no may be null.';

-- -------------------------------------------------------------------------
-- 4. seller_details  (extra fields for role = seller)
-- -------------------------------------------------------------------------

create table public.seller_details (
  profile_id        uuid primary key references public.profiles (id) on delete cascade,
  business_name     text not null,
  line_of_business  text not null,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);

-- -------------------------------------------------------------------------
-- 5. courier_details  (extra fields for role = courier, independent courier)
-- -------------------------------------------------------------------------

create table public.courier_details (
  profile_id     uuid primary key references public.profiles (id) on delete cascade,
  vehicle        public.vehicle_type not null,
  plate_number   text not null,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);

-- -------------------------------------------------------------------------
-- 6. logistics_companies  (role = logistics owns exactly one company)
-- -------------------------------------------------------------------------

create table public.logistics_companies (
  id                uuid primary key default gen_random_uuid(),
  owner_profile_id  uuid not null unique references public.profiles (id) on delete cascade,

  company_name      text not null,
  company_email     text not null,
  company_contact_no text not null,
  tin               text not null,
  sec_registration  text,

  status            public.approval_status not null default 'pending',

  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);

comment on table public.logistics_companies is 'A logistics company registered by a user with role = logistics. Has its own approval status separate from the owner profile.';

-- now that logistics_companies exists, wire up the FK on addresses
alter table public.addresses
  add constraint addresses_logistics_company_fkey
  foreign key (logistics_company_id) references public.logistics_companies (id) on delete cascade;

-- -------------------------------------------------------------------------
-- 7. driver_details  (role = driver, employed under a logistics company)
-- -------------------------------------------------------------------------

create table public.driver_details (
  profile_id            uuid primary key references public.profiles (id) on delete cascade,
  logistics_company_id  uuid not null references public.logistics_companies (id) on delete cascade,
  vehicle               public.vehicle_type,
  plate_number          text,
  license_number        text,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now()
);

comment on table public.driver_details is 'Drivers are employees of a logistics company (as opposed to independent couriers).';

-- -------------------------------------------------------------------------
-- 8. logistics_admins  (role = logistics_admin, staff of a logistics company)
-- -------------------------------------------------------------------------

create table public.logistics_admin_details (
  profile_id            uuid primary key references public.profiles (id) on delete cascade,
  logistics_company_id  uuid not null references public.logistics_companies (id) on delete cascade,
  created_at            timestamptz not null default now()
);

comment on table public.logistics_admin_details is 'Staff accounts that manage a specific logistics company (drivers, assignments, etc.) on the platform.';

-- -------------------------------------------------------------------------
-- 9. documents  (polymorphic uploads: ID, permits, OR/CR, etc.)
-- -------------------------------------------------------------------------
-- Actual files live in Storage (bucket "documents"); this table just tracks
-- metadata + review status per file.

create table public.documents (
  id                    uuid primary key default gen_random_uuid(),

  owner_kind            public.owner_kind not null,
  profile_id            uuid references public.profiles (id) on delete cascade,
  logistics_company_id  uuid references public.logistics_companies (id) on delete cascade,

  doc_type              public.document_type not null,
  storage_path          text not null, -- e.g. 'profile/<uid>/valid_id.jpg'
  status                public.approval_status not null default 'pending',
  reviewed_by           uuid references public.profiles (id),
  reviewed_at           timestamptz,

  created_at            timestamptz not null default now(),

  constraint documents_owner_shape check (
    (owner_kind = 'profile'            and profile_id is not null and logistics_company_id is null) or
    (owner_kind = 'logistics_company'  and logistics_company_id is not null and profile_id is null)
  )
);

-- -------------------------------------------------------------------------
-- 10. Helpful indexes
-- -------------------------------------------------------------------------

create index idx_profiles_role on public.profiles (role);
create index idx_profiles_status on public.profiles (status);
create index idx_addresses_profile on public.addresses (profile_id);
create index idx_addresses_logistics_company on public.addresses (logistics_company_id);
create index idx_documents_profile on public.documents (profile_id);
create index idx_documents_logistics_company on public.documents (logistics_company_id);
create index idx_driver_details_company on public.driver_details (logistics_company_id);
create index idx_logistics_admin_company on public.logistics_admin_details (logistics_company_id);

-- -------------------------------------------------------------------------
-- 11. updated_at trigger helper
-- -------------------------------------------------------------------------

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger trg_profiles_updated_at            before update on public.profiles            for each row execute function public.set_updated_at();
create trigger trg_addresses_updated_at           before update on public.addresses           for each row execute function public.set_updated_at();
create trigger trg_seller_details_updated_at      before update on public.seller_details       for each row execute function public.set_updated_at();
create trigger trg_courier_details_updated_at     before update on public.courier_details      for each row execute function public.set_updated_at();
create trigger trg_logistics_companies_updated_at before update on public.logistics_companies  for each row execute function public.set_updated_at();
create trigger trg_driver_details_updated_at      before update on public.driver_details       for each row execute function public.set_updated_at();

-- -------------------------------------------------------------------------
-- 12. Auto-create a profile row when someone signs up via Supabase Auth
-- -------------------------------------------------------------------------
-- Pass role + names as user metadata when calling supabase.auth.signUp():
--
--   supabase.auth.signUp({
--     email, password,
--     options: { data: { role: 'seller', first_name: 'Juan', last_name: 'Dela Cruz', ... } }
--   })

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, role, status, email, first_name, last_name, middle_initial, sex, contact_no, birthday)
  values (
    new.id,
    coalesce((new.raw_user_meta_data ->> 'role')::public.user_role, 'buyer'),
    'pending',
    new.email,
    new.raw_user_meta_data ->> 'first_name',
    new.raw_user_meta_data ->> 'last_name',
    new.raw_user_meta_data ->> 'middle_initial',
    nullif(new.raw_user_meta_data ->> 'sex', '')::public.sex_type,
    new.raw_user_meta_data ->> 'contact_no',
    nullif(new.raw_user_meta_data ->> 'birthday', '')::date
  );
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- -------------------------------------------------------------------------
-- 13. Role helper functions (used by RLS policies)
-- -------------------------------------------------------------------------

create or replace function public.current_role()
returns public.user_role
language sql
stable
security definer set search_path = public
as $$
  select role from public.profiles where id = auth.uid();
$$;

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer set search_path = public
as $$
  select coalesce((select role = 'admin' from public.profiles where id = auth.uid()), false);
$$;

create or replace function public.is_logistics_staff_of(company_id uuid)
returns boolean
language sql
stable
security definer set search_path = public
as $$
  -- true if the current user owns, or is a logistics_admin for, the given company
  select exists (
    select 1 from public.logistics_companies lc
    where lc.id = company_id and lc.owner_profile_id = auth.uid()
  ) or exists (
    select 1 from public.logistics_admin_details lad
    where lad.logistics_company_id = company_id and lad.profile_id = auth.uid()
  );
$$;

-- -------------------------------------------------------------------------
-- 14. Row Level Security
-- -------------------------------------------------------------------------

alter table public.profiles              enable row level security;
alter table public.addresses             enable row level security;
alter table public.seller_details        enable row level security;
alter table public.courier_details       enable row level security;
alter table public.logistics_companies   enable row level security;
alter table public.driver_details        enable row level security;
alter table public.logistics_admin_details enable row level security;
alter table public.documents             enable row level security;

-- profiles ----------------------------------------------------------------
create policy "profiles_select_own_or_admin"
  on public.profiles for select
  using (id = auth.uid() or public.is_admin());

create policy "profiles_update_own_or_admin"
  on public.profiles for update
  using (id = auth.uid() or public.is_admin());
-- no insert policy needed: rows are created only by the handle_new_user() trigger

-- addresses -----------------------------------------------------------------
create policy "addresses_select_own_or_admin"
  on public.addresses for select
  using (
    (owner_kind = 'profile' and profile_id = auth.uid())
    or (owner_kind = 'logistics_company' and public.is_logistics_staff_of(logistics_company_id))
    or public.is_admin()
  );

create policy "addresses_insert_own"
  on public.addresses for insert
  with check (
    (owner_kind = 'profile' and profile_id = auth.uid())
    or (owner_kind = 'logistics_company' and public.is_logistics_staff_of(logistics_company_id))
    or public.is_admin()
  );

create policy "addresses_update_own_or_admin"
  on public.addresses for update
  using (
    (owner_kind = 'profile' and profile_id = auth.uid())
    or (owner_kind = 'logistics_company' and public.is_logistics_staff_of(logistics_company_id))
    or public.is_admin()
  );

-- seller_details ------------------------------------------------------------
create policy "seller_details_select_own_or_admin"
  on public.seller_details for select
  using (profile_id = auth.uid() or public.is_admin());
create policy "seller_details_insert_own"
  on public.seller_details for insert
  with check (profile_id = auth.uid());
create policy "seller_details_update_own_or_admin"
  on public.seller_details for update
  using (profile_id = auth.uid() or public.is_admin());

-- courier_details -------------------------------------------------------------
create policy "courier_details_select_own_or_admin"
  on public.courier_details for select
  using (profile_id = auth.uid() or public.is_admin());
create policy "courier_details_insert_own"
  on public.courier_details for insert
  with check (profile_id = auth.uid());
create policy "courier_details_update_own_or_admin"
  on public.courier_details for update
  using (profile_id = auth.uid() or public.is_admin());

-- logistics_companies ---------------------------------------------------------
create policy "logistics_companies_select"
  on public.logistics_companies for select
  using (
    owner_profile_id = auth.uid()
    or public.is_logistics_staff_of(id)
    or public.is_admin()
  );
create policy "logistics_companies_insert_own"
  on public.logistics_companies for insert
  with check (owner_profile_id = auth.uid());
create policy "logistics_companies_update"
  on public.logistics_companies for update
  using (owner_profile_id = auth.uid() or public.is_admin());

-- driver_details ----------------------------------------------------------
create policy "driver_details_select"
  on public.driver_details for select
  using (
    profile_id = auth.uid()
    or public.is_logistics_staff_of(logistics_company_id)
    or public.is_admin()
  );
create policy "driver_details_insert"
  on public.driver_details for insert
  with check (
    profile_id = auth.uid()
    or public.is_logistics_staff_of(logistics_company_id)
    or public.is_admin()
  );
create policy "driver_details_update"
  on public.driver_details for update
  using (
    profile_id = auth.uid()
    or public.is_logistics_staff_of(logistics_company_id)
    or public.is_admin()
  );

-- logistics_admin_details --------------------------------------------------
create policy "logistics_admin_details_select"
  on public.logistics_admin_details for select
  using (
    profile_id = auth.uid()
    or public.is_logistics_staff_of(logistics_company_id)
    or public.is_admin()
  );
create policy "logistics_admin_details_insert"
  on public.logistics_admin_details for insert
  with check (
    -- only the company owner (or a platform admin) can appoint a logistics_admin
    exists (
      select 1 from public.logistics_companies lc
      where lc.id = logistics_company_id and lc.owner_profile_id = auth.uid()
    )
    or public.is_admin()
  );

-- documents -----------------------------------------------------------------
create policy "documents_select_own_or_admin"
  on public.documents for select
  using (
    (owner_kind = 'profile' and profile_id = auth.uid())
    or (owner_kind = 'logistics_company' and public.is_logistics_staff_of(logistics_company_id))
    or public.is_admin()
  );
create policy "documents_insert_own"
  on public.documents for insert
  with check (
    (owner_kind = 'profile' and profile_id = auth.uid())
    or (owner_kind = 'logistics_company' and public.is_logistics_staff_of(logistics_company_id))
    or public.is_admin()
  );
-- only admins change document status (approve/reject)
create policy "documents_update_admin_only"
  on public.documents for update
  using (public.is_admin());

-- -------------------------------------------------------------------------
-- 15. Storage bucket for uploaded documents
-- -------------------------------------------------------------------------
-- Files are expected to be uploaded under a path prefix that matches the
-- owner, e.g.:
--   profile/<auth.uid()>/valid_id.jpg
--   logistics_company/<company_id>/mayors_permit.pdf

insert into storage.buckets (id, name, public)
values ('documents', 'documents', false)
on conflict (id) do nothing;

create policy "documents_bucket_select_own_or_admin"
  on storage.objects for select
  using (
    bucket_id = 'documents'
    and (
      (storage.foldername(name))[1] = 'profile'
      and (storage.foldername(name))[2] = auth.uid()::text
    )
    or public.is_admin()
  );

create policy "documents_bucket_insert_own"
  on storage.objects for insert
  with check (
    bucket_id = 'documents'
    and (storage.foldername(name))[1] = 'profile'
    and (storage.foldername(name))[2] = auth.uid()::text
  );

-- =========================================================================
-- End of schema
-- =========================================================================

-- Admin Account
-- 1. Create the admin user in auth
-- This will automatically create a profile via the handle_new_user() trigger
INSERT INTO auth.users (
    instance_id,
    id,
    aud,
    role,
    email,
    encrypted_password,
    email_confirmed_at,
    confirmation_sent_at,
    raw_app_meta_data,
    raw_user_meta_data,
    created_at,
    updated_at,
    confirmation_token,
    email_change,
    email_change_token_new,
    recovery_token
) VALUES (
    '00000000-0000-0000-0000-000000000000',
    gen_random_uuid(),
    'authenticated',
    'authenticated',
    'admin@buytheway.com',
    crypt('Admin@123456', gen_salt('bf')),
    NOW(),
    NOW(),
    jsonb_build_object('provider', 'email', 'providers', array['email']),
    jsonb_build_object(
        'role', 'admin',
        'first_name', 'Super',
        'last_name', 'Admin'
    ),
    NOW(),
    NOW(),
    '',
    '',
    '',
    ''
);

-- 2. Update the profile that was created by the trigger
UPDATE profiles 
SET role = 'admin', 
    status = 'approved',
    first_name = 'Super',
    last_name = 'Admin'
WHERE email = 'admin@buytheway.com';

-- 3. Verify the admin was created
SELECT id, email, role, status, first_name, last_name 
FROM profiles 
WHERE email = 'admin@buytheway.com';

-- Added status for accounts
-- ============================================================
-- RECOMMENDED: Account Status System for BuyTheWay
-- ============================================================

-- 1. Create account status enum
create type public.account_status as enum (
  'active',        -- Fully functional account
  'suspended',     -- Temporarily blocked (can be reinstated)
  'deactivated',   -- Permanently closed (user requested or violation)
  'pending'        -- Waiting for email verification or admin approval
);

-- 2. Add to profiles table (all users)
alter table public.profiles 
add column if not exists account_status public.account_status not null default 'pending';

-- 3. Add to logistics_companies (companies can be suspended separately)
alter table public.logistics_companies 
add column if not exists account_status public.account_status not null default 'pending';

-- 4. Simple audit log for status changes (lightweight)
create table if not exists public.status_audit_log (
  id uuid primary key default gen_random_uuid(),
  entity_type text not null check (entity_type in ('profile', 'logistics_company')),
  entity_id uuid not null,
  old_status public.account_status,
  new_status public.account_status not null,
  reason text,
  changed_by uuid references public.profiles(id),
  created_at timestamptz not null default now()
);

-- 5. Update existing users (important!)
update public.profiles 
set account_status = 'active' 
where status = 'approved' 
  and account_status = 'pending';

update public.profiles 
set account_status = 'pending' 
where status != 'approved';

-- 6. Add indexes
create index idx_profiles_account_status on public.profiles (account_status);
create index idx_logistics_account_status on public.logistics_companies (account_status);
create index idx_status_audit_entity on public.status_audit_log (entity_id, entity_type);

-- 7. Create simple function to log status changes
create or replace function public.log_status_change()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  -- For profiles
  if tg_table_name = 'profiles' and old.account_status is distinct from new.account_status then
    insert into public.status_audit_log (
      entity_type, entity_id, old_status, new_status, changed_by
    ) values (
      'profile', new.id, old.account_status, new.account_status, auth.uid()
    );
  end if;
  
  -- For logistics_companies
  if tg_table_name = 'logistics_companies' and old.account_status is distinct from new.account_status then
    insert into public.status_audit_log (
      entity_type, entity_id, old_status, new_status, changed_by
    ) values (
      'logistics_company', new.id, old.account_status, new.account_status, auth.uid()
    );
  end if;
  
  return new;
end;
$$;

-- 8. Create triggers
drop trigger if exists trg_status_log_profiles on public.profiles;
create trigger trg_status_log_profiles
  after update of account_status on public.profiles
  for each row
  execute function public.log_status_change();

drop trigger if exists trg_status_log_logistics on public.logistics_companies;
create trigger trg_status_log_logistics
  after update of account_status on public.logistics_companies
  for each row
  execute function public.log_status_change();

-- 9. Helper functions for admins
create or replace function public.suspend_user(user_id uuid, reason text default null)
returns text
language plpgsql
security definer set search_path = public
as $$
declare
  user_email text;
begin
  if not public.is_admin() then
    return 'Error: Only admins can suspend users';
  end if;
  
  select email into user_email from profiles where id = user_id;
  if user_email is null then
    return 'Error: User not found';
  end if;
  
  update public.profiles set account_status = 'suspended' where id = user_id;
  return 'User ' || user_email || ' suspended successfully';
end;
$$;

create or replace function public.activate_user(user_id uuid)
returns text
language plpgsql
security definer set search_path = public
as $$
declare
  user_email text;
begin
  if not public.is_admin() then
    return 'Error: Only admins can activate users';
  end if;
  
  select email into user_email from profiles where id = user_id;
  if user_email is null then
    return 'Error: User not found';
  end if;
  
  update public.profiles set account_status = 'active' where id = user_id;
  return 'User ' || user_email || ' activated successfully';
end;
$$;

-- 10. Add to RLS policies (add this to existing policies)
-- Only active users can access data
create or replace function public.is_active_user()
returns boolean
language sql
stable
security definer set search_path = public
as $$
  select exists (
    select 1 from profiles 
    where id = auth.uid() 
    and account_status = 'active'
  );
$$;



BEGIN;

-- 1. Remove any existing admin profile
DELETE FROM profiles
WHERE email = 'admin@buytheway.com';


-- 2. Remove any existing admin Auth account
DELETE FROM auth.users
WHERE email = 'admin@buytheway.com';


-- 3. Create the Auth account
DO $$
DECLARE
    new_id UUID := gen_random_uuid();
BEGIN

    INSERT INTO auth.users (
        id,
        email,
        encrypted_password,
        email_confirmed_at,
        raw_user_meta_data,
        created_at,
        updated_at
    )
    VALUES (
        new_id,
        'admin@buytheway.com',
        crypt('Admin123!', gen_salt('bf')),
        NOW(),
        jsonb_build_object(
            'role', 'admin'
        ),
        NOW(),
        NOW()
    );


    -- 4. The Auth trigger may have already created the profile.
    --    Update it if it exists, otherwise create it.
    INSERT INTO profiles (
        id,
        role,
        status,
        account_status,
        email,
        first_name,
        last_name,
        created_at,
        updated_at
    )
    VALUES (
        new_id,
        'admin',
        'approved',
        'active',
        'admin@buytheway.com',
        'Admin',
        'User',
        NOW(),
        NOW()
    )
    ON CONFLICT (id)
    DO UPDATE SET
        role = 'admin',
        status = 'approved',
        account_status = 'active',
        email = 'admin@buytheway.com',
        first_name = 'Admin',
        last_name = 'User',
        updated_at = NOW();

END $$;


-- 5. Verify everything
SELECT
    p.id,
    p.email,
    p.role,
    p.status,
    p.account_status,
    p.first_name,
    p.last_name,
    u.email_confirmed_at
FROM profiles p
JOIN auth.users u
    ON p.id = u.id
WHERE p.email = 'admin@buytheway.com';

COMMIT;

-- Add CHECK constraint to ensure line_of_business is one of the allowed values
ALTER TABLE public.seller_details 
ADD CONSTRAINT seller_details_line_of_business_check 
CHECK (line_of_business IN (
  'Pet Supplies',
  'Kids and Baby',
  'Electronics and Gadgets',
  'House and Garden',
  'Woman''s Apparel',
  'Men''s Apparel',
  'Sports and Outdoors',
  'Health and Beauty'
));

-- Add a comment to document the allowed values
COMMENT ON COLUMN public.seller_details.line_of_business IS 
'Allowed values: Pet Supplies, Kids and Baby, Electronics and Gadgets, House and Garden, Woman''s Apparel, Men''s Apparel, Sports and Outdoors, Health and Beauty';

-- Add rejection_reason column to profiles table
ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS rejection_reason TEXT;

-- Add comment for documentation
COMMENT ON COLUMN public.profiles.rejection_reason IS 'Reason for rejection when status is rejected';

-- Remove the NOT NULL constraint
ALTER TABLE public.driver_details 
ALTER COLUMN logistics_company_id DROP NOT NULL;

-- Add a check constraint to ensure either logistics_company_id is set or it's an independent driver
-- This is optional but recommended
ALTER TABLE public.driver_details 
ADD CONSTRAINT driver_details_company_check 
CHECK (
  logistics_company_id IS NOT NULL 
  OR (vehicle IS NOT NULL AND plate_number IS NOT NULL)
);
