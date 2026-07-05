
-- Uso de IA por usuario y día (persistente): base del futuro plan de pago.
create table if not exists public.ai_usage (
  user_id uuid not null references public.profiles(id) on delete cascade,
  day date not null default current_date,
  on_device int not null default 0,
  cloud int not null default 0,
  in_tokens int not null default 0,
  out_tokens int not null default 0,
  primary key (user_id, day)
);
alter table public.ai_usage enable row level security;
drop policy if exists ai_usage_select_own on public.ai_usage;
create policy ai_usage_select_own on public.ai_usage for select to authenticated using (auth.uid() = user_id);

-- Único camino de escritura (cliente on-device y edge function): incrementa el día actual.
create or replace function public.bump_ai_usage(p_kind text, p_in int default 0, p_out int default 0)
returns void language plpgsql security definer set search_path = public as $$
begin
  insert into ai_usage as u (user_id, day, on_device, cloud, in_tokens, out_tokens)
  values (auth.uid(), current_date,
          case when p_kind = 'device' then 1 else 0 end,
          case when p_kind = 'cloud' then 1 else 0 end,
          greatest(0, p_in), greatest(0, p_out))
  on conflict (user_id, day) do update set
    on_device = u.on_device + (case when p_kind = 'device' then 1 else 0 end),
    cloud     = u.cloud     + (case when p_kind = 'cloud'  then 1 else 0 end),
    in_tokens  = u.in_tokens  + greatest(0, excluded.in_tokens),
    out_tokens = u.out_tokens + greatest(0, excluded.out_tokens);
end;
$$;
revoke all on function public.bump_ai_usage(text, int, int) from public, anon;
grant execute on function public.bump_ai_usage(text, int, int) to authenticated;
