-- Supabase 프로젝트 game-planner 에 적용된 스키마 (참고/재생성용)

-- 일정/게임 레코드를 사용자별로 저장. 기기 간 병합은 updated_at 기준 최신 우선.
create table public.items (
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  id text not null,
  kind text not null check (kind in ('schedule', 'game', 'task', 'maple', 'mark', 'ai')),
  data jsonb,
  deleted boolean not null default false,
  updated_at timestamptz not null,
  primary key (user_id, id)
);

alter table public.items enable row level security;

create policy "own items select" on public.items
  for select to authenticated using (user_id = (select auth.uid()));
create policy "own items insert" on public.items
  for insert to authenticated with check (user_id = (select auth.uid()));
create policy "own items update" on public.items
  for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));
create policy "own items delete" on public.items
  for delete to authenticated using (user_id = (select auth.uid()));

alter publication supabase_realtime add table public.items;

-- 늦게 도착한 오래된 변경이 더 최신 데이터를 덮어쓰지 못하게 막는다.
create function public.items_keep_newer() returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.updated_at < old.updated_at then
    return null;
  end if;
  return new;
end;
$$;

create trigger items_keep_newer
  before update on public.items
  for each row execute function public.items_keep_newer();

-- AI 답 음성 파일 ('내 목소리'): 경로 <user_id>/<파일>, 본인 폴더만 접근
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('voice', 'voice', false, 5242880, array['audio/mpeg', 'audio/wav'])
on conflict (id) do nothing;

create policy "voice own read" on storage.objects for select to authenticated
  using (bucket_id = 'voice' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy "voice own insert" on storage.objects for insert to authenticated
  with check (bucket_id = 'voice' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy "voice own update" on storage.objects for update to authenticated
  using (bucket_id = 'voice' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy "voice own delete" on storage.objects for delete to authenticated
  using (bucket_id = 'voice' and (storage.foldername(name))[1] = (select auth.uid())::text);
