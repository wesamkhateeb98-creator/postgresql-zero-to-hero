-- Run during a benchmark (second terminal):
--   docker compose exec pg psql -U app -d shop -f /repo/12-benchmarking/bench/monitor.sql
-- Live refresh: \watch يعيد آخر query فقط → انسخ query واحدة ثم  \watch 2

\echo '== Sessions by state / wait event =='
SELECT state, wait_event_type, wait_event, count(*)
FROM pg_stat_activity
WHERE backend_type = 'client backend'
GROUP BY 1, 2, 3 ORDER BY 4 DESC;

\echo '== Cache hit ratio (target > 99%) =='
SELECT datname,
       round(100.0 * blks_hit / nullif(blks_hit + blks_read, 0), 2) AS hit_pct
FROM pg_stat_database WHERE datname = current_database();

\echo '== Top 5 queries by total time =='
SELECT calls,
       round(mean_exec_time::numeric, 2)  AS avg_ms,
       round(total_exec_time::numeric)    AS total_ms,
       left(regexp_replace(query, '\s+', ' ', 'g'), 70) AS query
FROM pg_stat_statements
ORDER BY total_exec_time DESC LIMIT 5;

\echo '== Checkpoints (requested >> timed → raise max_wal_size) =='
SELECT num_timed, num_requested, write_time, sync_time
FROM pg_stat_checkpointer;

\echo '== Dead tuples =='
SELECT relname, n_live_tup, n_dead_tup, last_autovacuum
FROM pg_stat_user_tables ORDER BY n_dead_tup DESC LIMIT 5;

\echo '== Blocked sessions =='
SELECT pid, pg_blocking_pids(pid) AS blocked_by, left(query, 60) AS query
FROM pg_stat_activity
WHERE cardinality(pg_blocking_pids(pid)) > 0;
