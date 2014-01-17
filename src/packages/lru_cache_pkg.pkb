CREATE OR REPLACE PACKAGE BODY lru_cache_pkg IS

  TYPE t_cached_data IS RECORD(
    next_key     t_cache_key,
    prev_key     t_cache_key,
    cached_value sys.anydata);

  TYPE t_cache IS TABLE OF t_cached_data INDEX BY t_cache_key;

  gn_cache_size      NUMBER := 1000;
  gt_cache           t_cache;
  gt_cache_buffer    t_cache;
  gt_cache_empty     t_cache;
  gt_head_key        t_cache_key;
  gt_tail_key        t_cache_key;
  gn_cache_count     NUMBER := 0;
  gn_deleted_count   NUMBER := 0;
  gs_found_count     NUMBER := 0;
  gs_not_found_count NUMBER := 0;

  PROCEDURE clear_cache IS
  BEGIN
    gt_head_key        := NULL;
    gt_tail_key        := NULL;
    gn_cache_count     := 0;
    gn_deleted_count   := 0;
    gs_found_count     := 0;
    gs_not_found_count := 0;
    gt_cache           := gt_cache_empty;
  END clear_cache;

  PROCEDURE set_cache_size(an_cache_size NUMBER) IS
  BEGIN
    gn_cache_size := an_cache_size;
  END set_cache_size;

  FUNCTION get_hit_ratio RETURN NUMBER IS
  BEGIN
    IF (gs_found_count + gs_not_found_count -least(gs_not_found_count, gn_cache_size)) > 0 THEN
      RETURN gs_found_count /(gs_found_count + gs_not_found_count -least(gs_not_found_count, gn_cache_size));

    ELSE
      RETURN 0;
    END IF;
  END get_hit_ratio;

  PROCEDURE shift_to_head(as_key          t_cache_key,
                          at_cached_data  IN OUT NOCOPY t_cached_data,
                          ab_update_value BOOLEAN,
                          as_value        sys.anydata) IS
  BEGIN
    at_cached_data := gt_cache(as_key);
    IF as_key != gt_head_key THEN
      IF as_key != gt_tail_key THEN
        gt_cache(at_cached_data.prev_key).next_key := at_cached_data.next_key;
        gt_cache(at_cached_data.next_key).prev_key := at_cached_data.prev_key;
      ELSE
        gt_cache(at_cached_data.prev_key).next_key := NULL;
        gt_tail_key := at_cached_data.prev_key;
      END IF;
      at_cached_data.next_key := gt_head_key;
      at_cached_data.prev_key := NULL;
      IF ab_update_value THEN
        at_cached_data.cached_value := as_value;
      END IF;
      gt_cache(as_key) := at_cached_data;
      gt_cache(gt_head_key).prev_key := as_key;
      gt_head_key := as_key;
    END IF;
  END shift_to_head;

  FUNCTION get(as_key t_cache_key) RETURN sys.anydata IS
    lt_cached_data t_cached_data;
  BEGIN
    IF gt_cache.exists(as_key) THEN
      gs_found_count := gs_found_count + 1;
      shift_to_head(as_key,
                    lt_cached_data,
                    FALSE,
                    NULL);
      RETURN lt_cached_data.cached_value;
    END IF;
    gs_not_found_count := gs_not_found_count + 1;

    RETURN lt_cached_data.cached_value;
  END get;

  PROCEDURE put(as_key t_cache_key, as_value sys.anydata) IS
    lt_tail_key_new t_cache_key;
    lt_cached_data t_cached_data;
  BEGIN
    IF gt_cache.exists(as_key) THEN
      shift_to_head(as_key,
                    lt_cached_data,
                    TRUE,
                    as_value);
    ELSE
      IF gn_cache_count > 0 THEN
        IF gn_cache_count < gn_cache_size THEN
          gn_cache_count := gn_cache_count + 1;
          gt_cache(gt_head_key).prev_key := as_key;
        ELSE
          lt_tail_key_new := gt_cache(gt_tail_key).prev_key;
          gt_cache(lt_tail_key_new).next_key := NULL;
          gt_cache.delete(gt_tail_key);
          gn_deleted_count := gn_deleted_count + 1;
          IF gn_deleted_count > gn_cache_size THEN
            gt_cache_buffer  := gt_cache;
            gt_cache         := gt_cache_buffer;
            gt_cache_buffer  := gt_cache_empty;
            gn_deleted_count := 0;
          END IF;
          gt_cache(gt_head_key).prev_key := as_key;
          gt_tail_key := lt_tail_key_new;
        END IF;
      ELSE
        gn_cache_count := 1;
        gt_tail_key    := as_key;
      END IF;
      lt_cached_data.next_key := gt_head_key;
      lt_cached_data.prev_key := NULL;
      lt_cached_data.cached_value := as_value;
      gt_cache(as_key) := lt_cached_data;
      gt_head_key := as_key;
    END IF;
  END put;

END lru_cache_pkg;
/
