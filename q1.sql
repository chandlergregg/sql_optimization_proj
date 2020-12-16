USE springboardopt;

-- -------------------------------------
SET @v1 = 1612521;
SET @v2 = 1145072;
SET @v3 = 1828467;
SET @v4 = 'MGT382';
SET @v5 = 'Amber Hill';
SET @v6 = 'MGT';
SET @v7 = 'EE';			  
SET @v8 = 'MAT';

-- 1. List the name of the student with id equal to v1 (id).
SELECT name FROM Student WHERE id = @v1;

-- 
DESCRIBE student;

EXPLAIN SELECT name FROM Student WHERE id = @v1;
EXPLAIN ANALYZE SELECT name FROM Student WHERE id = @v1;
/* EXPLAIN plan before optimization: 
 * -> Filter: (student.id = <cache>((@v1)))  (cost=41.00 rows=40) (actual time=0.081..0.266 rows=1 loops=1)
    -> Table scan on Student  (cost=41.00 rows=400) (actual time=0.027..0.231 rows=400 loops=1)
 */

drop index id_idx on student;
CREATE unique INDEX id_idx ON Student (id);
EXPLAIN ANALYZE SELECT name FROM Student WHERE id = @v1;
/*
 * EXPLAIN plan after optimization:
 * -> Index lookup on Student using id_idx (id=(@v1))  (cost=0.35 rows=1) (actual time=0.039..0.042 rows=1 loops=1)
 */

/*
 * NOTES:
 * By adding an index on id, we only need to do an index lookup using the id_idx, which is much faster than a filter on id.
 */

describe student;
alter table student add primary key (id);

describe course;

describe professor;
alter table professor add primary key (id);

describe transcript;

describe teaching;