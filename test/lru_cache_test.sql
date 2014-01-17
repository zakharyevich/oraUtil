/*
PL/SQL implementation of LRU cache using  associative array

Test steps -
1. we create a list of 100K db object ids with a repeat factor, 
   and then we sort this list using the dbms_random.random call;
2. in a loop we make queries to retrieve those objects through the cache;
3. we measure time and hit ratio;
4. we exit the loop when we meet the target ratio, otherwise we increase the cache size by 1K

*/
WHENEVER SQLERROR EXIT
SET SQLBLANKLINES ON
SET SERVEROUTPUT ON

DECLARE
  TYPE t_numbers IS TABLE OF NUMBER INDEX BY PLS_INTEGER;
  lt_id_list          t_numbers;
  lr_test_object      all_objects.OBJECT_NAME%TYPE;
  ln_usecase_size     NUMBER := 100000;
  ln_repeat_factor    NUMBER := 5;
  ln_cache_size       NUMBER := 10000;
  ln_hit_ratio        NUMBER := 0;
  ln_target_hit_ratio NUMBER := 0.6;
  lt_start            TIMESTAMP;

  FUNCTION get_object_lru(al_object_id NUMBER) RETURN  all_objects.OBJECT_NAME%TYPE IS
     lr_test_object all_objects.OBJECT_NAME%TYPE;
     lr_test_object_any sys.anydata;
     i NUMBER;
  BEGIN
    lr_test_object_any := lru_cache_pkg.get(al_object_id);
    IF lr_test_object_any IS NULL THEN
      BEGIN
        SELECT OBJECT_NAME INTO lr_test_object FROM all_objects WHERE object_id = al_object_id;
      
      EXCEPTION
        WHEN no_data_found THEN
          NULL;
      END;
      lru_cache_pkg.put(al_object_id,
                        sys.anyData.ConvertVarchar2(lr_test_object));
    ELSE
       i :=  lr_test_object_any.GetVarchar2(lr_test_object);
    END IF;
    RETURN  lr_test_object;
  END get_object_lru;

BEGIN
  SELECT * BULK COLLECT
    INTO lt_id_list
    FROM (SELECT t.*
            FROM (SELECT object_id FROM all_objects WHERE rownum < ln_usecase_size / ln_repeat_factor +1) t,
                 (SELECT * FROM dual CONNECT BY LEVEL < ln_repeat_factor + 1) l
           ORDER BY dbms_random.random);

  LOOP
    lru_cache_pkg.set_cache_size(ln_cache_size);
    lru_cache_pkg.clear_cache;
    lt_start := systimestamp;
    FOR i IN 1 .. lt_id_list.count LOOP
      lr_test_object := get_object_lru(al_object_id => lt_id_list(i));
    END LOOP;
    dbms_output.put_line('_____________________________________________________');
    dbms_output.put_line('cache size   : ' || ln_cache_size);	
    dbms_output.put_line('__et         : ' || to_char(systimestamp - lt_start));	
    dbms_output.put_line('__hit ratio  : ' || round(lru_cache_pkg.get_hit_ratio, 2));
    dbms_output.put_line('__requests   : ' || lt_id_list.count);
    dbms_output.put_line('__repeated   : ' || ln_repeat_factor);
    dbms_output.put_line('');
    EXIT WHEN lru_cache_pkg.get_hit_ratio >= ln_target_hit_ratio;
    ln_cache_size := ln_cache_size + 1000;
  END LOOP;
END;
/

