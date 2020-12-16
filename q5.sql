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

-- 5. List the names of students who have taken a course from department v6 (deptId), but not v7.
SELECT * FROM Student, 
	(SELECT studId FROM Transcript, Course WHERE deptId = @v6 AND Course.crsCode = Transcript.crsCode
	AND studId NOT IN
	(SELECT studId FROM Transcript, Course WHERE deptId = @v7 AND Course.crsCode = Transcript.crsCode)) as alias
WHERE Student.id = alias.studId;

-- ------------------------

-- Before optimization
EXPLAIN ANALYZE
SELECT * FROM Student, 
	(SELECT studId FROM Transcript, Course WHERE deptId = @v6 AND Course.crsCode = Transcript.crsCode
	AND studId NOT IN
	(SELECT studId FROM Transcript, Course WHERE deptId = @v7 AND Course.crsCode = Transcript.crsCode)) as alias
WHERE Student.id = alias.studId;
/*
 * -> Nested loop inner join  (cost=21.33 rows=10) (actual time=0.299..7.232 rows=30 loops=1)
    -> Nested loop inner join  (cost=13.86 rows=10) (actual time=0.048..0.261 rows=30 loops=1)
        -> Filter: ((course.deptId = <cache>((@v6))) and (course.crsCode is not null))  (cost=10.25 rows=10) (actual time=0.028..0.114 rows=26 loops=1)
            -> Table scan on Course  (cost=10.25 rows=100) (actual time=0.022..0.085 rows=100 loops=1)
        -> Filter: (transcript.studId is not null)  (cost=0.27 rows=1) (actual time=0.004..0.005 rows=1 loops=26)
            -> Index lookup on Transcript using crsCode_idx (crsCode=course.crsCode)  (cost=0.27 rows=1) (actual time=0.004..0.005 rows=1 loops=26)
    -> Filter: <in_optimizer>(transcript.studId,<exists>(select #3) is false)  (cost=0.63 rows=1) (actual time=0.232..0.232 rows=1 loops=30)
        -> Single-row index lookup on Student using PRIMARY (id=transcript.studId)  (cost=0.63 rows=1) (actual time=0.004..0.004 rows=1 loops=30)
        -> Select #3 (subquery in condition; dependent)
            -> Limit: 1 row(s)  (actual time=0.226..0.226 rows=0 loops=30)
                -> Filter: <if>(outer_field_is_not_null, <is_not_null_test>(transcript.studId), true)  (actual time=0.226..0.226 rows=0 loops=30)
                    -> Nested loop inner join  (cost=13.86 rows=10) (actual time=0.226..0.226 rows=0 loops=30)
                        -> Filter: ((course.deptId = <cache>((@v7))) and (course.crsCode is not null))  (cost=10.25 rows=10) (actual time=0.006..0.089 rows=32 loops=30)
                            -> Table scan on Course  (cost=10.25 rows=100) (actual time=0.002..0.066 rows=100 loops=30)
                        -> Filter: <if>(outer_field_is_not_null, ((<cache>(transcript.studId) = transcript.studId) or (transcript.studId is null)), true)  (cost=0.27 rows=1) (actual time=0.004..0.004 rows=0 loops=960)
                            -> Index lookup on Transcript using crsCode_idx (crsCode=course.crsCode)  (cost=0.27 rows=1) (actual time=0.003..0.004 rows=1 loops=960)
 */

explain analyze
select distinct
	  tra.studId
from transcript tra
inner join course crs
	on tra.crsCode = crs.crsCode
where crs.deptId = @v6;

/*
 * -> Nested loop inner join  (cost=12.73 rows=27) (actual time=0.040..0.219 rows=30 loops=1)
    -> Filter: (crs.crsCode is not null)  (cost=3.35 rows=26) (actual time=0.026..0.081 rows=26 loops=1)
        -> Index lookup on crs using deptid_idx (deptId=(@v6))  (cost=3.35 rows=26) (actual time=0.026..0.076 rows=26 loops=1)
    -> Index lookup on tra using crscode_idx (crsCode=crs.crsCode)  (cost=0.26 rows=1) (actual time=0.004..0.005 rows=1 loops=26)
 */

show indexes from transcript;
drop index crscode_idx on transcript;
create index crscode_idx on transcript (crscode);

show indexes from course;
drop index crscode_idx on course;
drop index deptid_idx on course;
create index crscode_idx on course (crscode);
create index deptid_idx on course (deptid);

drop table if exists v6_students;
create temporary table v6_students
select distinct
	  tra.studId
from transcript tra
inner join course crs
	on tra.crsCode = crs.crsCode
where crs.deptId = @v6;

drop table if exists v7_students;
create temporary table v7_students
select distinct
	  tra.studId
from transcript tra
inner join course crs
	on tra.crsCode = crs.crsCode
where crs.deptId = @v7;

explain analyze
select
	  v6.studid
from v6_students v6
left outer join v7_students v7
	on v6.studid = v7.studid
	and v7.studid is null;
/*
 * -> Left hash join (v7.studId = v6.studId), extra conditions: (v6.studId is null)  (cost=83.58 rows=832) (actual time=0.064..0.124 rows=26 loops=1)
    -> Table scan on v6  (cost=2.85 rows=26) (actual time=0.003..0.049 rows=26 loops=1)
    -> Hash
        -> Table scan on v7  (cost=0.13 rows=32) (actual time=0.023..0.042 rows=32 loops=1)
*/

explain analyze
select
	  v6.studid
from v6_students v6
left outer join v7_students v7
	on v6.studid = v7.studid
where v7.studid is null;
/*
 * -> Filter: (v7.studId is null)  (cost=86.46 rows=83) (actual time=0.080..0.123 rows=26 loops=1)
    -> Left hash join (v7.studId = v6.studId)  (cost=86.46 rows=83) (actual time=0.079..0.117 rows=26 loops=1)
        -> Table scan on v6  (cost=2.85 rows=26) (actual time=0.004..0.031 rows=26 loops=1)
        -> Hash
            -> Table scan on v7  (cost=0.13 rows=32) (actual time=0.027..0.052 rows=32 loops=1)
*/

create index studid_idx on v6_students (studid);
create index studid_idx on v7_students (studid);

-- Using LEFT JOIN
explain analyze
select
	  v6.studid
from v6_students v6
left join v7_students v7
	on v6.studid = v7.studid
where v7.studid is null;
/*
 * -> Filter: (v7.studId is null)  (cost=31.45 rows=26) (actual time=0.033..0.097 rows=26 loops=1)
    -> Nested loop left join  (cost=31.45 rows=26) (actual time=0.032..0.093 rows=26 loops=1)
        -> Index scan on v6 using studid_idx  (cost=2.85 rows=26) (actual time=0.021..0.041 rows=26 loops=1)
        -> Index lookup on v7 using studid_idx (studId=v6.studId)  (cost=1.00 rows=1) (actual time=0.002..0.002 rows=0 loops=26)
*/

-- Using IN
explain analyze
select 
	  v6.studid
from v6_students v6
where v6.studid not in (select studid from v7_students);
/*
 * -> Filter: <in_optimizer>(v6.studId,v6.studId in (select #2) is false)  (cost=2.85 rows=26) (actual time=0.099..0.194 rows=26 loops=1)
    -> Index scan on v6 using studid_idx  (cost=2.85 rows=26) (actual time=0.022..0.056 rows=26 loops=1)
    -> Select #2 (subquery in condition; run only once)
        -> Filter: ((v6.studId = `<materialized_subquery>`.studid))  (actual time=0.001..0.001 rows=0 loops=27)
            -> Limit: 1 row(s)  (actual time=0.001..0.001 rows=0 loops=27)
                -> Index lookup on <materialized_subquery> using <auto_distinct_key> (studid=v6.studId)  (actual time=0.001..0.001 rows=0 loops=27)
                    -> Materialize with deduplication  (cost=3.45 rows=32) (actual time=0.004..0.004 rows=0 loops=27)
                        -> Index scan on v7_students using studid_idx  (cost=3.45 rows=32) (actual time=0.006..0.044 rows=32 loops=1)
 */

-- Using EXISTS
explain analyze
select
	  v6.studid
from v6_students v6
where not exists (select 1 from v7_students v7 where v6.studid = v7.studid);
/*
 * -> Nested loop antijoin  (cost=88.65 rows=832) (actual time=0.096..0.128 rows=26 loops=1)
    -> Index scan on v6 using studid_idx  (cost=2.85 rows=26) (actual time=0.023..0.038 rows=26 loops=1)
    -> Single-row index lookup on <subquery2> using <auto_distinct_key> (studid=v6.studId)  (actual time=0.000..0.000 rows=0 loops=26)
        -> Materialize with deduplication  (cost=3.45 rows=32) (actual time=0.003..0.003 rows=0 loops=26)
            -> Filter: (v7.studId is not null)  (cost=3.45 rows=32) (actual time=0.004..0.049 rows=32 loops=1)
                -> Index scan on v7 using studid_idx  (cost=3.45 rows=32) (actual time=0.003..0.044 rows=32 loops=1)
 */

explain analyze
select 
	  stu.name as student_name
from v6_students v6
inner join student stu
	on v6.studid = stu.id
where v6.studid not in (select studid from v7_students);
/*
 * -> Nested loop inner join  (cost=21.70 rows=26) (actual time=0.080..0.280 rows=26 loops=1)
    -> Filter: (<in_optimizer>(v6.studId,v6.studId in (select #2) is false) and (v6.studId is not null))  (cost=2.85 rows=26) (actual time=0.068..0.182 rows=26 loops=1)
        -> Index scan on v6 using studid_idx  (cost=2.85 rows=26) (actual time=0.021..0.046 rows=26 loops=1)
        -> Select #2 (subquery in condition; run only once)
            -> Filter: ((v6.studId = `<materialized_subquery>`.studid))  (actual time=0.002..0.002 rows=0 loops=27)
                -> Limit: 1 row(s)  (actual time=0.001..0.001 rows=0 loops=27)
                    -> Index lookup on <materialized_subquery> using <auto_distinct_key> (studid=v6.studId)  (actual time=0.001..0.001 rows=0 loops=27)
                        -> Materialize with deduplication  (cost=3.45 rows=32) (actual time=0.003..0.003 rows=0 loops=27)
                            -> Index scan on v7_students using studid_idx  (cost=3.45 rows=32) (actual time=0.004..0.025 rows=32 loops=1)
    -> Single-row index lookup on stu using PRIMARY (id=v6.studId)  (cost=0.63 rows=1) (actual time=0.003..0.003 rows=1 loops=26)
*/

explain analyze
select name as student_name
from student
where id in (select studid from v6_students)
and id not in (select studid from v7_students);
/*
-> Nested loop inner join  (cost=22.48 rows=26) (actual time=0.082..0.205 rows=26 loops=1)
    -> Remove duplicates from input sorted on studid_idx  (cost=3.63 rows=26) (actual time=0.069..0.139 rows=26 loops=1)
        -> Filter: (<in_optimizer>(v6_students.studId,v6_students.studId in (select #3) is false) and (v6_students.studId is not null))  (cost=3.63 rows=26) (actual time=0.068..0.133 rows=26 loops=1)
            -> Index scan on v6_students using studid_idx  (cost=3.63 rows=26) (actual time=0.021..0.040 rows=26 loops=1)
            -> Select #3 (subquery in condition; run only once)
                -> Filter: ((v6_students.studId = `<materialized_subquery>`.studid))  (actual time=0.001..0.001 rows=0 loops=27)
                    -> Limit: 1 row(s)  (actual time=0.001..0.001 rows=0 loops=27)
                        -> Index lookup on <materialized_subquery> using <auto_distinct_key> (studid=v6_students.studId)  (actual time=0.001..0.001 rows=0 loops=27)
                            -> Materialize with deduplication  (cost=3.45 rows=32) (actual time=0.003..0.003 rows=0 loops=27)
                                -> Index scan on v7_students using studid_idx  (cost=3.45 rows=32) (actual time=0.003..0.024 rows=32 loops=1)
    -> Single-row index lookup on student using PRIMARY (id=v6_students.studId)  (cost=16.35 rows=1) (actual time=0.002..0.002 rows=1 loops=26)
*/

select name as student_name
from student
where id in (select studid from v6_students)
and id not in (select studid from v7_students);