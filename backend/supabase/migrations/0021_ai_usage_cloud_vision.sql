-- Contador dedicado para el análisis del físico por foto (visión en la nube): es más caro
-- que el texto y tiene su propio cupo diario. Antes se contabilizaba en `cloud`, lo que hacía
-- que el chat de texto agotara el cupo de la visión (y viceversa).
alter table public.ai_usage
  add column if not exists cloud_vision int not null default 0;

-- El RPC pasa a distinguir p_kind = 'cloud_vision'. Firma intacta (no hace falta re-grant).
create or replace function public.bump_ai_usage(p_kind text, p_in int default 0, p_out int default 0)
returns void language plpgsql security definer set search_path = public as $$
begin
  insert into ai_usage as u (user_id, day, on_device, cloud, cloud_vision, in_tokens, out_tokens)
  values (auth.uid(), current_date,
          case when p_kind = 'device' then 1 else 0 end,
          case when p_kind = 'cloud' then 1 else 0 end,
          case when p_kind = 'cloud_vision' then 1 else 0 end,
          greatest(0, p_in), greatest(0, p_out))
  on conflict (user_id, day) do update set
    on_device    = u.on_device    + (case when p_kind = 'device'       then 1 else 0 end),
    cloud        = u.cloud        + (case when p_kind = 'cloud'        then 1 else 0 end),
    cloud_vision = u.cloud_vision + (case when p_kind = 'cloud_vision' then 1 else 0 end),
    in_tokens  = u.in_tokens  + greatest(0, excluded.in_tokens),
    out_tokens = u.out_tokens + greatest(0, excluded.out_tokens);
end;
$$;
