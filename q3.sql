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

-- 3. List the names of students who have taken course v4 (crsCode).
SELECT name FROM Student WHERE id IN (SELECT studId FROM Transcript WHERE crsCode = @v4);

--

EXPLAIN ANALYZE
SELECT name FROM Student WHERE id IN (SELECT studId FROM Transcript WHERE crsCode = @v4);
/* BEFORE TRANSCRIPT.CRSCODE INDEX:
 * -> Nested loop inner join  (cost=3.63 rows=10) (actual time=0.111..0.111 rows=0 loops=1)
    -> Filter: (`<subquery2>`.studId is not null)  (cost=2.00 rows=10) (actual time=0.111..0.111 rows=0 loops=1)
        -> Table scan on <subquery2>  (cost=2.00 rows=10) (actual time=0.000..0.000 rows=0 loops=1)
            -> Materialize with deduplication  (cost=10.25 rows=10) (actual time=0.110..0.110 rows=0 loops=1)
                -> Filter: (transcript.studId is not null)  (cost=10.25 rows=10) (actual time=0.107..0.107 rows=0 loops=1)
                    -> Filter: (transcript.crsCode = <cache>((@v4)))  (cost=10.25 rows=10) (actual time=0.106..0.106 rows=0 loops=1)
                        -> Table scan on Transcript  (cost=10.25 rows=100) (actual time=0.027..0.091 rows=100 loops=1)
    -> Single-row index lookup on Student using PRIMARY (id=`<subquery2>`.studId)  (cost=0.72 rows=1) (never executed)
 */

CREATE INDEX crsCode_idx on Transcript (crsCode);

EXPLAIN ANALYZE
SELECT name FROM Student WHERE id IN (SELECT studId FROM Transcript WHERE crsCode = @v4);
/* AFTER INDEX:
 * -> Nested loop inner join  (cost=1.10 rows=2) (actual time=0.048..0.055 rows=2 loops=1)
    -> Filter: (`<subquery2>`.studId is not null)  (cost=0.40 rows=2) (actual time=0.037..0.038 rows=2 loops=1)
        -> Table scan on <subquery2>  (cost=0.40 rows=2) (actual time=0.001..0.001 rows=2 loops=1)
            -> Materialize with deduplication  (cost=0.70 rows=2) (actual time=0.037..0.037 rows=2 loops=1)
                -> Filter: (transcript.studId is not null)  (cost=0.70 rows=2) (actual time=0.022..0.029 rows=2 loops=1)
                    -> Index lookup on Transcript using crsCode_idx (crsCode=(@v4))  (cost=0.70 rows=2) (actual time=0.021..0.028 rows=2 loops=1)
    -> Index lookup on Student using id_idx (id=`<subquery2>`.studId)  (cost=0.60 rows=1) (actual time=0.007..0.007 rows=1 loops=2)
 */

EXPLAIN ANALYZE
SELECT stu.name 
FROM Student stu
INNER JOIN Transcript tra
	ON stu.id = tra.studID
WHERE tra.crsCode = @v4;
/*
 * -> Nested loop inner join  (cost=1.40 rows=2) (actual time=0.042..0.057 rows=2 loops=1)
    -> Filter: (tra.studId is not null)  (cost=0.70 rows=2) (actual time=0.026..0.031 rows=2 loops=1)
        -> Index lookup on tra using crsCode_idx (crsCode=(@v4))  (cost=0.70 rows=2) (actual time=0.025..0.030 rows=2 loops=1)
    -> Index lookup on stu using id_idx (id=tra.studId)  (cost=0.30 rows=1) (actual time=0.009..0.012 rows=1 loops=2)
 */


/* OPTIMIZATIONS:
 * Add index to Transcript.crsCode
 * Turn subquery into inner join
 */
