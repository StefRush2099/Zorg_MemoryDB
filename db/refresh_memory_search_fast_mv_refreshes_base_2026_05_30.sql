-- Ensure the public fast-search refresh path also refreshes its base view.
-- Without this, newly inserted recall hints/rules can remain absent from
-- zorg_memory_search_fast_mv even after calling the advertised refresh helper.

create or replace function public.refresh_zorg_memory_search_fast_mv()
returns void
language plpgsql
as $function$
begin
  refresh materialized view public.zorg_memory_search_mv;
  analyze public.zorg_memory_search_mv;
  refresh materialized view public.zorg_memory_search_fast_mv;
  analyze public.zorg_memory_search_fast_mv;
end;
$function$;
