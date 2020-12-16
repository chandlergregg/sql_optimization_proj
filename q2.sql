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

-- 2. List the names of students with id in the range of v2 (id) to v3 (inclusive).
SELECT name FROM Student WHERE id BETWEEN @v2 AND @v3;

--

EXPLAIN ANALYZE
SELECT name FROM Student WHERE id BETWEEN @v2 AND @v3;
/* EXPLAIN plan before optimization: 
 * -> Filter: (student.id between <cache>((@v2)) and <cache>((@v3)))  (cost=56.47 rows=278) (actual time=0.090..0.271 rows=278 loops=1)
    -> Index range scan on Student using PRIMARY  (cost=56.47 rows=278) (actual time=0.086..0.229 rows=278 loops=1)
 */

EXPLAIN ANALYZE
SELECT name FROM Student WHERE id >= @v2 AND id <= @v3;
/*
-> Filter: ((student.id >= <cache>((@v2))) and (student.id <= <cache>((@v3))))  (cost=41.00 rows=278) (actual time=0.023..0.390 rows=278 loops=1)
    -> Table scan on Student  (cost=41.00 rows=400) (actual time=0.021..0.312 rows=400 loops=1)
*/

show index from student;

EXPLAIN ANALYZE
SELECT name 
FROM Student 
FORCE INDEX (id)
WHERE id BETWEEN @v2 AND @v3;
/*
 * -> Index range scan on Student using id_idx, with index condition: (student.id between <cache>((@v2)) and <cache>((@v3)))  
 * (cost=125.36 rows=278) 
 * (actual time=0.027..0.538 rows=278 loops=1)
 */

select count(distinct id), count(*) from student;

select * from student limit 100;