-- Blitz Bowl · team chat, gated by a shared room code
-- Run in the Supabase SQL editor, or: supabase db push

create table if not exists public.bb_messages (
  id         bigserial primary key,
  room       text not null,
  author     text not null,
  body       text not null,
  client_id  text,
  created_at timestamptz not null default now()
);

create index if not exists bb_messages_room_idx on public.bb_messages (room, id desc);
create index if not exists bb_messages_flood_idx on public.bb_messages (client_id, created_at desc);

-- RLS on with NO policies: the anon key cannot read or write this table at all.
-- Both functions below are security definer, so knowing the room code is the
-- only way in. That is what makes the code worth something -- without this the
-- code would just be a filter anyone with the anon key could ignore.
alter table public.bb_messages enable row level security;

revoke all on public.bb_messages from anon, authenticated;

-- ---------------------------------------------------------------- read
create or replace function public.bb_history(p_room text, p_limit int default 80)
returns table (id bigint, author text, body text, client_id text, created_at timestamptz)
language sql
security definer
set search_path = public
as $$
  select m.id, m.author, m.body, m.client_id, m.created_at
    from public.bb_messages m
   where m.room = upper(btrim(p_room))
     and length(btrim(p_room)) between 4 and 24
   order by m.id desc
   limit least(greatest(coalesce(p_limit, 80), 1), 200);
$$;

-- --------------------------------------------------------------- write
create or replace function public.bb_post(p_room text, p_author text, p_body text, p_client text)
returns bigint
language plpgsql
security definer
set search_path = public
as $$
declare
  v_room   text := upper(btrim(p_room));
  v_body   text := btrim(p_body);
  v_recent integer;
  v_id     bigint;
  v_cut    bigint;
begin
  if length(v_room) not between 4 and 24 then
    raise exception 'room code must be 4-24 characters';
  end if;
  if length(v_body) = 0 then
    raise exception 'message is empty';
  end if;

  -- flood guard: 12 messages a minute per device
  select count(*) into v_recent
    from public.bb_messages
   where client_id = p_client
     and created_at > now() - interval '1 minute';
  if v_recent >= 12 then
    raise exception 'slow down';
  end if;

  insert into public.bb_messages (room, author, body, client_id)
  values (v_room,
          left(coalesce(nullif(btrim(p_author), ''), 'COACH'), 16),
          left(v_body, 400),
          p_client)
  returning id into v_id;

  -- keep each room to its last 300 messages
  select id into v_cut
    from public.bb_messages
   where room = v_room
   order by id desc
   offset 300 limit 1;
  if v_cut is not null then
    delete from public.bb_messages where room = v_room and id <= v_cut;
  end if;

  return v_id;
end
$$;

grant execute on function public.bb_history(text, int)          to anon, authenticated;
grant execute on function public.bb_post(text, text, text, text) to anon, authenticated;
