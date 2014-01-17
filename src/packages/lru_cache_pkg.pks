CREATE OR REPLACE PACKAGE lru_cache_pkg IS

  SUBTYPE t_cache_key IS VARCHAR2(1000);

  PROCEDURE set_cache_size(an_cache_size NUMBER);
  PROCEDURE clear_cache;
  FUNCTION get_hit_ratio RETURN NUMBER;

  FUNCTION get(as_key t_cache_key) RETURN sys.anydata; 
  PROCEDURE put(as_key t_cache_key, as_value sys.anydata);
END lru_cache_pkg;
/
