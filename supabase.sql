-- Wider: global daily results + private leagues.
-- Run once in Supabase → SQL Editor (the free tier is plenty). Safe to re-run.
-- Stores only: puzzle number, a random anonymous player id, the zoom they solved at (7 = not solved),
-- and, for leagues, the league name and the display name each player chose.

-- ───────────── Daily results ─────────────
create table if not exists public.plays (
  day     int      not null check (day > 0 and day < 100000),
  player  uuid     not null,
  zoom    smallint not null check (zoom between 1 and 7),
  created_at timestamptz not null default now(),
  primary key (day, player)
);
alter table public.plays enable row level security;

-- Anyone can submit a result (one per player per day, thanks to the primary key)…
drop policy if exists "anyone can submit" on public.plays;
create policy "anyone can submit" on public.plays for insert to anon with check (true);
-- …but nobody can read individual rows. Only the aggregates below are public.

create or replace function public.day_stats(d int)
returns table (zoom smallint, n bigint)
language sql stable security definer set search_path = public as $$
  select p.zoom, count(*)::bigint from public.plays p where p.day = d group by p.zoom order by p.zoom;
$$;

-- ───────────── Leagues ─────────────
create table if not exists public.leagues (
  code text primary key check (code ~ '^[A-Z2-9]{6}$'),
  name text not null check (char_length(name) between 1 and 30),
  created_at timestamptz not null default now()
);
create table if not exists public.league_members (
  code   text not null references public.leagues(code) on delete cascade,
  player uuid not null,
  name   text not null check (char_length(name) between 1 and 20),
  joined_at timestamptz not null default now(),
  primary key (code, player)
);
-- No policies: the tables are only reachable through the functions below.
alter table public.leagues enable row level security;
alter table public.league_members enable row level security;

create or replace function public.create_league(n text, p uuid, pn text)
returns text language plpgsql security definer set search_path = public as $$
declare c text; tries int := 0;
begin
  if char_length(trim(n)) < 1 or char_length(trim(pn)) < 1 then raise exception 'name required'; end if;
  if (select count(*) from league_members where player = p) >= 10 then raise exception 'too many leagues'; end if;
  loop
    select string_agg(substr('ABCDEFGHJKLMNPQRSTUVWXYZ23456789', 1 + floor(random() * 32)::int, 1), '')
      into c from generate_series(1, 6);
    exit when not exists (select 1 from leagues where code = c);
    tries := tries + 1;
    if tries > 20 then raise exception 'could not allocate a code'; end if;
  end loop;
  insert into leagues (code, name) values (c, left(trim(n), 30));
  insert into league_members (code, player, name) values (c, p, left(trim(pn), 20));
  return c;
end $$;

-- Returns the league's name, or null if the code doesn't exist.
create or replace function public.join_league(c text, p uuid, pn text)
returns text language plpgsql security definer set search_path = public as $$
declare ln text;
begin
  if char_length(trim(pn)) < 1 then raise exception 'name required'; end if;
  select name into ln from leagues where code = upper(trim(c));
  if ln is null then return null; end if;
  if not exists (select 1 from league_members where code = upper(trim(c)) and player = p)
     and (select count(*) from league_members where code = upper(trim(c))) >= 100 then
    raise exception 'league full';
  end if;
  insert into league_members (code, player, name) values (upper(trim(c)), p, left(trim(pn), 20))
    on conflict (code, player) do update set name = excluded.name;
  return ln;
end $$;

create or replace function public.leave_league(c text, p uuid)
returns void language sql security definer set search_path = public as $$
  delete from league_members where code = upper(trim(c)) and player = p;
$$;

-- One row per member per played day in [d0, d1] (day/zoom null if they haven't played in that window).
-- Only members of the league can read it; player ids are never returned.
create or replace function public.league_board(c text, me uuid, d0 int, d1 int)
returns table (league text, k text, member text, is_me boolean, day int, zoom smallint)
language sql stable security definer set search_path = public as $$
  select l.name, left(md5(m.player::text || l.code), 10), m.name, m.player = me, p.day, p.zoom
  from leagues l
  join league_members m on m.code = l.code
  left join plays p on p.player = m.player and p.day between d0 and d1
  where l.code = upper(trim(c))
    and exists (select 1 from league_members x where x.code = l.code and x.player = me);
$$;

grant execute on function public.day_stats(int) to anon;
grant execute on function public.create_league(text, uuid, text) to anon;
grant execute on function public.join_league(text, uuid, text) to anon;
grant execute on function public.leave_league(text, uuid) to anon;
grant execute on function public.league_board(text, uuid, int, int) to anon;
