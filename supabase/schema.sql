-- Run in Supabase SQL Editor on a NEW project.
create extension if not exists pgcrypto;
create table public.admins(user_id uuid primary key references auth.users(id) on delete cascade);
create table public.site_settings(key text primary key,value text not null default '');
create table public.classes(id uuid primary key default gen_random_uuid(),kind text not null check(kind in ('private','group','online')),title text not null,description text not null default '',price numeric(10,2) not null check(price>=0),capacity int not null default 1 check(capacity between 1 and 6),active boolean not null default true,sort_order int not null default 0);
create table public.services(id uuid primary key default gen_random_uuid(),kind text not null default 'service' check(kind='service'),title text not null,description text not null default '',price numeric(10,2) not null default 0 check(price>=0),active boolean not null default true,sort_order int not null default 0);
create table public.sessions(id uuid primary key default gen_random_uuid(),class_id uuid not null references public.classes(id),start_at timestamptz not null,end_at timestamptz not null,capacity int not null check(capacity between 1 and 6),status text not null default 'open' check(status in ('open','closed')),check(end_at>start_at));
create table public.bookings(id uuid primary key default gen_random_uuid(),customer_id uuid not null references auth.users(id),class_id uuid references public.classes(id),service_id uuid references public.services(id),session_id uuid references public.sessions(id),requested_at timestamptz not null,quantity int not null default 1 check(quantity between 1 and 5),location_type text not null default 'studio' check(location_type in ('studio','bangkok','greater','other')),notes text not null default '',quoted_price numeric(10,2) check(quoted_price>=0),status text not null default 'pending' check(status in ('pending','confirmed','declined','cancelled')),created_at timestamptz not null default now(),check((class_id is not null)::int+(service_id is not null)::int=1));
create table public.reviews(id uuid primary key default gen_random_uuid(),customer_id uuid not null references auth.users(id),rating int not null check(rating between 1 and 5),body text not null check(length(body) between 1 and 10000),status text not null default 'pending' check(status in ('pending','approved','rejected')),created_at timestamptz not null default now());
create index on public.bookings(requested_at,status);create index on public.bookings(session_id,status);
create or replace function public.is_admin() returns boolean language sql stable security definer set search_path='' as $$select exists(select 1 from public.admins where user_id=(select auth.uid()))$$;
revoke all on function public.is_admin() from public;grant execute on function public.is_admin() to authenticated,anon;
alter table public.admins enable row level security;
alter table public.site_settings enable row level security;
alter table public.classes enable row level security;
alter table public.services enable row level security;
alter table public.sessions enable row level security;
alter table public.bookings enable row level security;
alter table public.reviews enable row level security;
create policy admins_read on public.admins for select to authenticated using(user_id=(select auth.uid()));
create policy settings_read on public.site_settings for select to anon,authenticated using(true);
create policy settings_admin on public.site_settings for all to authenticated using(public.is_admin()) with check(public.is_admin());
create policy classes_read on public.classes for select to anon,authenticated using(active or public.is_admin());
create policy classes_admin on public.classes for all to authenticated using(public.is_admin()) with check(public.is_admin());
create policy services_read on public.services for select to anon,authenticated using(active or public.is_admin());
create policy services_admin on public.services for all to authenticated using(public.is_admin()) with check(public.is_admin());
create policy sessions_read on public.sessions for select to anon,authenticated using(status='open' or public.is_admin());
create policy sessions_admin on public.sessions for all to authenticated using(public.is_admin()) with check(public.is_admin());
create policy bookings_read on public.bookings for select to authenticated using(customer_id=(select auth.uid()) or public.is_admin());
create policy bookings_create on public.bookings for insert to authenticated with check(customer_id=(select auth.uid()) and status='pending' and requested_at>now() and quantity between 1 and 5 and (session_id is null or exists(select 1 from public.sessions s where s.id=session_id and s.class_id=bookings.class_id and s.status='open' and s.start_at=bookings.requested_at)));
-- Booking updates are ONLY through the transactional RPC below.
create policy reviews_read on public.reviews for select to anon,authenticated using(status='approved' or public.is_admin() or customer_id=(select auth.uid()));
create policy reviews_create on public.reviews for insert to authenticated with check(customer_id=(select auth.uid()) and status='pending' and array_length(regexp_split_to_array(trim(body),'\s+'),1)<=1000 and exists(select 1 from public.bookings b where b.customer_id=(select auth.uid()) and b.status='confirmed'));
create policy reviews_admin on public.reviews for update to authenticated using(public.is_admin()) with check(public.is_admin());
-- Restrict direct modification of bookings; use one database transaction for confirmation.
create or replace function public.admin_set_booking_status(p_booking_id uuid,p_status text) returns void language plpgsql security definer set search_path='' as $$
declare b public.bookings%rowtype; s public.sessions%rowtype; c public.classes%rowtype; booked int;
begin
 if not public.is_admin() then raise exception 'Not authorized';end if;
 if p_status not in ('confirmed','declined','cancelled') then raise exception 'Invalid status';end if;
 -- Serialize confirmations for the artist. Protects capacity and overlapping times.
 perform pg_advisory_xact_lock(982341);
 select * into b from public.bookings where id=p_booking_id for update;
 if not found then raise exception 'Booking not found';end if;
 if p_status='confirmed' then
  if b.requested_at<=now() then raise exception 'Booking time is in the past';end if;
  if b.class_id is not null then select * into c from public.classes where id=b.class_id; if not c.active then raise exception 'Class is closed';end if;end if;
  if b.service_id is not null and not exists(select 1 from public.services where id=b.service_id and active) then raise exception 'Service is closed';end if;
  if b.session_id is not null then
   select * into s from public.sessions where id=b.session_id for update;
   if not found or s.status<>'open' or s.class_id is distinct from b.class_id or s.start_at<>b.requested_at then raise exception 'Session unavailable';end if;
   select coalesce(sum(quantity),0) into booked from public.bookings where session_id=b.session_id and status='confirmed' and id<>b.id;
   if booked+b.quantity>s.capacity then raise exception 'Session full';end if;
   -- A session may share its time with members of the SAME session, but not other appointments.
   if exists(select 1 from public.bookings x where x.status='confirmed' and x.id<>b.id and x.session_id is distinct from b.session_id and x.requested_at < s.end_at and x.requested_at+interval '2 hours'>s.start_at) then raise exception 'Time conflict';end if;
  else
   if exists(select 1 from public.bookings x where x.status='confirmed' and x.id<>b.id and x.requested_at < b.requested_at+interval '2 hours' and (case when x.session_id is not null then (select ss.end_at from public.sessions ss where ss.id=x.session_id) else x.requested_at+interval '2 hours' end)>b.requested_at) then raise exception 'Time conflict';end if;
  end if;
 end if;
 update public.bookings set status=p_status where id=p_booking_id;
end $$;
revoke all on function public.admin_set_booking_status(uuid,text) from public;
grant execute on function public.admin_set_booking_status(uuid,text) to authenticated;
-- Seed content
insert into public.classes(kind,title,description,price,capacity,sort_order) values
('private','Private Onsite Makeup Class','Learn with Ruth. Bring up to four friends (five people total).',3000,5,1),
('group','Promotional Group Class','Join a small group session; maximum six students.',1500,6,2),
('online','Online Makeup Class','One-to-one online lesson with Ruth.',2500,1,3);
insert into public.services(title,description,price,sort_order) values
('Bridal & Wedding Makeup','Makeup at the studio or your event location.',0,1),
('Graduation Makeup','Celebrate your graduation with a beautiful look.',0,2),
('Indian & Arabic Makeup','Indian bridal and Arabic-inspired glam.',0,3),
('Photoshoot & Events','Professional makeup for your special occasion.',0,4);
insert into public.site_settings(key,value) values
('bio','Rupar Htun is the makeup artist behind Ruth''s Makeup, based near Victory Monument in Bangkok.'),
('address','Near Victory Monument, Bangkok, Thailand'),('phone',''),('contact_email',''),('hero_image','https://images.unsplash.com/photo-1524504388940-b1c1722653e1?w=900'),('facebook',''),('instagram',''),('tiktok',''),('youtube',''),('travel_bangkok','0'),('travel_greater','0');
-- Public portfolio images, uploads limited to admin accounts.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('portfolio','portfolio',true,5242880,array['image/jpeg','image/png','image/webp']) on conflict(id) do nothing;
create policy portfolio_read on storage.objects for select to anon,authenticated using(bucket_id='portfolio');
create policy portfolio_admin_upload on storage.objects for insert to authenticated with check(bucket_id='portfolio' and public.is_admin());
create policy portfolio_admin_update on storage.objects for update to authenticated using(bucket_id='portfolio' and public.is_admin()) with check(bucket_id='portfolio' and public.is_admin());
create policy portfolio_admin_delete on storage.objects for delete to authenticated using(bucket_id='portfolio' and public.is_admin());
-- IMPORTANT: AFTER Ruth signs up, grant admin role manually in SQL editor:
-- insert into public.admins(user_id) values ('RUTH_AUTH_USER_UUID');
