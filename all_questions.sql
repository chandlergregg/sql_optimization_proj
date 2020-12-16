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

-- WITHOUT OPTIMIZATION:
explain analyze
SELECT name FROM Student WHERE id = @v1;
/*
-> Filter: (student.id = <cache>((@v1)))  (cost=41.00 rows=40) (actual time=0.104..0.386 rows=1 loops=1)
    -> Table scan on Student  (cost=41.00 rows=400) (actual time=0.028..0.331 rows=400 loops=1)
*/

-- ADD PRIMARY KEY
alter table student add primary key (id);

-- WITH OPTIMIZATION:
explain analyze
SELECT name FROM Student WHERE id = @v1;
/*
-> Rows fetched before execution  (cost=0.00 rows=1) (actual time=0.000..0.000 rows=1 loops=1)
*/


-- 2. List the names of students with id in the range of v2 (id) to v3 (inclusive).
SELECT name FROM Student WHERE id BETWEEN @v2 AND @v3;

-- WITH OPTIMIZATION:
explain analyze
SELECT name FROM Student WHERE id BETWEEN @v2 AND @v3;
/*
-> Filter: (student.id between <cache>((@v2)) and <cache>((@v3)))  (cost=56.47 rows=278) (actual time=0.163..0.306 rows=278 loops=1)
    -> Index range scan on Student using PRIMARY  (cost=56.47 rows=278) (actual time=0.158..0.260 rows=278 loops=1)
*/


-- 3. List the names of students who have taken course v4 (crsCode).
SELECT name FROM Student WHERE id IN (SELECT studId FROM Transcript WHERE crsCode = @v4);

-- WITHOUT OPTIMIZATION:
explain analyze
SELECT name FROM Student WHERE id IN (SELECT studId FROM Transcript WHERE crsCode = @v4);
/*
-> Nested loop inner join  (cost=3.63 rows=10) (actual time=0.159..0.169 rows=2 loops=1)
    -> Filter: (`<subquery2>`.studId is not null)  (cost=2.00 rows=10) (actual time=0.143..0.144 rows=2 loops=1)
        -> Table scan on <subquery2>  (cost=2.00 rows=10) (actual time=0.001..0.001 rows=2 loops=1)
            -> Materialize with deduplication  (cost=10.25 rows=10) (actual time=0.142..0.143 rows=2 loops=1)
                -> Filter: (transcript.studId is not null)  (cost=10.25 rows=10) (actual time=0.060..0.134 rows=2 loops=1)
                    -> Filter: (transcript.crsCode = <cache>((@v4)))  (cost=10.25 rows=10) (actual time=0.060..0.133 rows=2 loops=1)
                        -> Table scan on Transcript  (cost=10.25 rows=100) (actual time=0.025..0.103 rows=100 loops=1)
    -> Single-row index lookup on Student using PRIMARY (id=`<subquery2>`.studId)  (cost=0.72 rows=1) (actual time=0.011..0.011 rows=1 loops=2)
*/

-- ADD INDEXES:
create index crscode_idx on transcript (crscode);
create index studid_idx on transcript (studid);

-- WITH INDEXES ADDED:
explain analyze
SELECT name FROM Student WHERE id IN (SELECT studId FROM Transcript WHERE crsCode = @v4);
/*
-> Nested loop inner join  (cost=1.22 rows=2) (actual time=0.051..0.056 rows=2 loops=1)
    -> Filter: (`<subquery2>`.studId is not null)  (cost=0.40 rows=2) (actual time=0.040..0.041 rows=2 loops=1)
        -> Table scan on <subquery2>  (cost=0.40 rows=2) (actual time=0.001..0.001 rows=2 loops=1)
            -> Materialize with deduplication  (cost=0.70 rows=2) (actual time=0.039..0.040 rows=2 loops=1)
                -> Filter: (transcript.studId is not null)  (cost=0.70 rows=2) (actual time=0.024..0.032 rows=2 loops=1)
                    -> Index lookup on Transcript using crscode_idx (crsCode=(@v4))  (cost=0.70 rows=2) (actual time=0.023..0.031 rows=2 loops=1)
    -> Single-row index lookup on Student using PRIMARY (id=`<subquery2>`.studId)  (cost=0.72 rows=1) (actual time=0.007..0.007 rows=1 loops=2)
*/

-- WITH SUBQUERY TURNED INTO JOIN:
EXPLAIN ANALYZE
SELECT stu.name 
FROM Student stu
INNER JOIN Transcript tra
	ON stu.id = tra.studID
WHERE tra.crsCode = @v4;


-- 4. List the names of students who have taken a course taught by professor v5 (name).
SELECT name FROM Student,
	(SELECT studId FROM Transcript,
		(SELECT crsCode, semester FROM Professor
			JOIN Teaching
			WHERE Professor.name = @v5 AND Professor.id = Teaching.profId) as alias1
	WHERE Transcript.crsCode = alias1.crsCode AND Transcript.semester = alias1.semester) as alias2
WHERE Student.id = alias2.studId;

-- WITHOUT OPTIMIZATION:
explain analyze
SELECT name FROM Student,
	(SELECT studId FROM Transcript,
		(SELECT crsCode, semester FROM Professor
			JOIN Teaching
			WHERE Professor.name = @v5 AND Professor.id = Teaching.profId) as alias1
	WHERE Transcript.crsCode = alias1.crsCode AND Transcript.semester = alias1.semester) as alias2
WHERE Student.id = alias2.studId;
/*
-> Inner hash join (professor.id = teaching.profId)  (cost=102.09 rows=0) (actual time=0.953..0.953 rows=0 loops=1)
    -> Filter: (professor.`name` = <cache>((@v5)))  (cost=4.32 rows=4) (never executed)
        -> Table scan on Professor  (cost=4.32 rows=400) (never executed)
    -> Hash
        -> Nested loop inner join  (cost=53.81 rows=10) (actual time=0.944..0.944 rows=0 loops=1)
            -> Nested loop inner join  (cost=46.33 rows=10) (actual time=0.943..0.943 rows=0 loops=1)
                -> Filter: (teaching.crsCode is not null)  (cost=10.25 rows=100) (actual time=0.028..0.162 rows=100 loops=1)
                    -> Table scan on Teaching  (cost=10.25 rows=100) (actual time=0.026..0.135 rows=100 loops=1)
                -> Filter: ((transcript.semester = teaching.semester) and (transcript.studId is not null))  (cost=0.26 rows=0) (actual time=0.008..0.008 rows=0 loops=100)
                    -> Index lookup on Transcript using crscode_idx (crsCode=teaching.crsCode)  (cost=0.26 rows=1) (actual time=0.005..0.007 rows=1 loops=100)
            -> Single-row index lookup on Student using PRIMARY (id=transcript.studId)  (cost=0.63 rows=1) (never executed)
*/

-- BREAK INTO CTEs:
EXPLAIN ANALYZE
with cte_course_semester as (
	SELECT
		  crsCode
		, semester 
	FROM Professor pro
	inner JOIN Teaching tea
		on pro.id = tea.profId
	WHERE pro.name = @v5
), 
cte_student_id as (
	select
		  studid
	from cte_course_semester ccs
	inner join transcript tra
		on ccs.crscode = tra.crsCode 
		and ccs.semester = tra.semester
)
select
	  stu.name
from cte_student_id csi
inner join student stu	
	on csi.studid = stu.id;

-- ADD INDEXES:
alter table professor add primary key (id);
create index name_idx on professor (name);
create index profid_idx on teaching (profid);

-- WITH OPTIMIZATION:
EXPLAIN ANALYZE
with cte_course_semester as (
	SELECT
		  crsCode
		, semester 
	FROM Professor pro
	inner JOIN Teaching tea
		on pro.id = tea.profId
	WHERE pro.name = @v5
), 
cte_student_id as (
	select
		  studid
	from cte_course_semester ccs
	inner join transcript tra
		on ccs.crscode = tra.crsCode 
		and ccs.semester = tra.semester
)
select
	  stu.name
from cte_student_id csi
inner join student stu	
	on csi.studid = stu.id;
/*
-> Nested loop inner join  (cost=1.14 rows=0) (actual time=0.065..0.065 rows=0 loops=1)
    -> Nested loop inner join  (cost=1.06 rows=0) (actual time=0.064..0.064 rows=0 loops=1)
        -> Nested loop inner join  (cost=0.70 rows=1) (actual time=0.038..0.041 rows=1 loops=1)
            -> Index lookup on pro using name_idx (name=(@v5))  (cost=0.35 rows=1) (actual time=0.023..0.024 rows=1 loops=1)
            -> Filter: (tea.crsCode is not null)  (cost=0.35 rows=1) (actual time=0.014..0.015 rows=1 loops=1)
                -> Index lookup on tea using profid_idx (profId=pro.id)  (cost=0.35 rows=1) (actual time=0.013..0.014 rows=1 loops=1)
        -> Filter: ((tra.semester = tea.semester) and (tra.studId is not null))  (cost=0.27 rows=0) (actual time=0.023..0.023 rows=0 loops=1)
            -> Index lookup on tra using crscode_idx (crsCode=tea.crsCode)  (cost=0.27 rows=1) (actual time=0.013..0.020 rows=2 loops=1)
    -> Single-row index lookup on stu using PRIMARY (id=tra.studId)  (cost=1.60 rows=1) (never executed)
*/


-- 5. List the names of students who have taken a course from department v6 (deptId), but not v7.
SELECT * FROM Student, 
	(SELECT studId FROM Transcript, Course WHERE deptId = @v6 AND Course.crsCode = Transcript.crsCode
	AND studId NOT IN
	(SELECT studId FROM Transcript, Course WHERE deptId = @v7 AND Course.crsCode = Transcript.crsCode)) as alias
WHERE Student.id = alias.studId;

-- BEFORE OPTIMIZATION:
explain analyze
SELECT * FROM Student, 
	(SELECT studId FROM Transcript, Course WHERE deptId = @v6 AND Course.crsCode = Transcript.crsCode
	AND studId NOT IN
	(SELECT studId FROM Transcript, Course WHERE deptId = @v7 AND Course.crsCode = Transcript.crsCode)) as alias
WHERE Student.id = alias.studId;
/*
-> Nested loop inner join  (cost=32.16 rows=27) (actual time=0.175..1.537 rows=30 loops=1)
    -> Nested loop inner join  (cost=12.73 rows=27) (actual time=0.093..0.445 rows=30 loops=1)
        -> Filter: (course.crsCode is not null)  (cost=3.35 rows=26) (actual time=0.042..0.144 rows=26 loops=1)
            -> Index lookup on Course using deptid_idx (deptId=(@v6))  (cost=3.35 rows=26) (actual time=0.040..0.134 rows=26 loops=1)
        -> Filter: (transcript.studId is not null)  (cost=0.26 rows=1) (actual time=0.008..0.011 rows=1 loops=26)
            -> Index lookup on Transcript using crscode_idx (crsCode=course.crsCode)  (cost=0.26 rows=1) (actual time=0.008..0.010 rows=1 loops=26)
    -> Filter: <in_optimizer>(transcript.studId,<exists>(select #3) is false)  (cost=0.63 rows=1) (actual time=0.036..0.036 rows=1 loops=30)
        -> Single-row index lookup on Student using PRIMARY (id=transcript.studId)  (cost=0.63 rows=1) (actual time=0.004..0.005 rows=1 loops=30)
        -> Select #3 (subquery in condition; dependent)
            -> Limit: 1 row(s)  (actual time=0.028..0.028 rows=0 loops=30)
                -> Filter: <if>(outer_field_is_not_null, <is_not_null_test>(transcript.studId), true)  (actual time=0.028..0.028 rows=0 loops=30)
                    -> Nested loop inner join  (cost=1.42 rows=1) (actual time=0.027..0.027 rows=0 loops=30)
                        -> Filter: (<if>(outer_field_is_not_null, ((<cache>(transcript.studId) = transcript.studId) or (transcript.studId is null)), true) and (transcript.crsCode is not null))  (cost=0.70 rows=2) (actual time=0.010..0.014 rows=1 loops=30)
                            -> Alternative plans for IN subquery: Index lookup unless studId IS NULL  (cost=0.70 rows=2) (actual time=0.008..0.012 rows=1 loops=30)
                                -> Index lookup on Transcript using studid_idx (studId=<cache>(transcript.studId) or NULL)  (actual time=0.008..0.012 rows=1 loops=30)
                                -> Table scan on Transcript  (never executed)
                        -> Filter: (course.deptId = <cache>((@v7)))  (cost=0.27 rows=0) (actual time=0.012..0.012 rows=0 loops=30)
                            -> Index lookup on Course using crscode_idx (crsCode=transcript.crsCode)  (cost=0.27 rows=1) (actual time=0.009..0.011 rows=1 loops=30)
*/

-- ADD INDEXES
create index deptid_idx on course (deptid);
create index crscode_idx on course (crscode);

-- BREAK INTO TEMP TABLES:
drop table if exists v6_students;
create temporary table v6_students
select distinct
	  tra.studId
from transcript tra
inner join course crs
	on tra.crsCode = crs.crsCode
where crs.deptId = @v6;
create unique index studid_idx on v6_students (studid);

drop table if exists v7_students;
create temporary table v7_students
select distinct
	  tra.studId
from transcript tra
inner join course crs
	on tra.crsCode = crs.crsCode
where crs.deptId = @v7;
create unique index studid_idx on v7_students (studid);

-- WITH OPTIMIZATION:
explain analyze
select name as student_name
from student
where id in (select studid from v6_students)
and id not in (select studid from v7_students);
/*
-> Nested loop inner join  (cost=21.70 rows=26) (actual time=0.084..0.226 rows=26 loops=1)
    -> Filter: (<in_optimizer>(v6_students.studId,v6_students.studId in (select #3) is false) and (v6_students.studId is not null))  (cost=2.85 rows=26) (actual time=0.068..0.135 rows=26 loops=1)
        -> Index scan on v6_students using studid_idx  (cost=2.85 rows=26) (actual time=0.021..0.040 rows=26 loops=1)
        -> Select #3 (subquery in condition; run only once)
            -> Filter: ((v6_students.studId = `<materialized_subquery>`.studid))  (actual time=0.001..0.001 rows=0 loops=27)
                -> Limit: 1 row(s)  (actual time=0.001..0.001 rows=0 loops=27)
                    -> Index lookup on <materialized_subquery> using <auto_distinct_key> (studid=v6_students.studId)  (actual time=0.001..0.001 rows=0 loops=27)
                        -> Materialize with deduplication  (cost=3.45 rows=32) (actual time=0.003..0.003 rows=0 loops=27)
                            -> Index scan on v7_students using studid_idx  (cost=3.45 rows=32) (actual time=0.003..0.024 rows=32 loops=1)
    -> Single-row index lookup on student using PRIMARY (id=v6_students.studId)  (cost=0.63 rows=1) (actual time=0.003..0.003 rows=1 loops=26)
*/


-- 6. List the names of students who have taken all courses offered by department v8 (deptId).
SELECT name FROM Student,
	(SELECT studId
	FROM Transcript
		WHERE crsCode IN
		(SELECT crsCode FROM Course WHERE deptId = @v8 AND crsCode IN (SELECT crsCode FROM Teaching))
		GROUP BY studId
		HAVING COUNT(*) = 
			(SELECT COUNT(*) FROM Course WHERE deptId = @v8 AND crsCode IN (SELECT crsCode FROM Teaching))) as alias
WHERE id = alias.studId;

-- BEFORE OPTIMIZATION:
explain analyze
SELECT name FROM Student,
	(SELECT studId
	FROM Transcript
		WHERE crsCode IN
		(SELECT crsCode FROM Course WHERE deptId = @v8 AND crsCode IN (SELECT crsCode FROM Teaching))
		GROUP BY studId
		HAVING COUNT(*) = 
			(SELECT COUNT(*) FROM Course WHERE deptId = @v8 AND crsCode IN (SELECT crsCode FROM Teaching))) as alias
WHERE id = alias.studId;
/*
-> Nested loop inner join  (actual time=6.963..6.963 rows=0 loops=1)
    -> Filter: (alias.studId is not null)  (actual time=6.963..6.963 rows=0 loops=1)
        -> Table scan on alias  (cost=2.73 rows=2) (actual time=0.001..0.001 rows=0 loops=1)
            -> Materialize  (actual time=6.962..6.962 rows=0 loops=1)
                -> Filter: (count(0) = (select #5))  (actual time=6.953..6.953 rows=0 loops=1)
                    -> Table scan on <temporary>  (actual time=0.001..0.002 rows=19 loops=1)
                        -> Aggregate using temporary table  (actual time=6.946..6.950 rows=19 loops=1)
                            -> Nested loop inner join  (cost=10.54 rows=20) (actual time=0.850..0.989 rows=19 loops=1)
                                -> Filter: (`<subquery3>`.crsCode is not null)  (cost=3.69 rows=19) (actual time=0.838..0.852 rows=19 loops=1)
                                    -> Table scan on <subquery3>  (cost=3.69 rows=19) (actual time=0.001..0.006 rows=19 loops=1)
                                        -> Materialize with deduplication  (cost=46.33 rows=20) (actual time=0.838..0.846 rows=19 loops=1)
                                            -> Filter: (course.crsCode is not null)  (cost=46.33 rows=20) (actual time=0.057..0.806 rows=19 loops=1)
                                                -> Nested loop inner join  (cost=46.33 rows=20) (actual time=0.056..0.801 rows=19 loops=1)
                                                    -> Filter: (teaching.crsCode is not null)  (cost=10.25 rows=100) (actual time=0.021..0.146 rows=100 loops=1)
                                                        -> Table scan on Teaching  (cost=10.25 rows=100) (actual time=0.020..0.120 rows=100 loops=1)
                                                    -> Filter: (course.deptId = <cache>((@v8)))  (cost=0.26 rows=0) (actual time=0.006..0.006 rows=0 loops=100)
                                                        -> Index lookup on Course using crscode_idx (crsCode=teaching.crsCode)  (cost=0.26 rows=1) (actual time=0.004..0.006 rows=1 loops=100)
                                -> Index lookup on Transcript using crscode_idx (crsCode=`<subquery3>`.crsCode)  (cost=5.00 rows=1) (actual time=0.005..0.007 rows=1 loops=19)
                    -> Select #5 (subquery in condition; uncacheable)
                        -> Aggregate: count(0)  (actual time=0.304..0.304 rows=1 loops=19)
                            -> Nested loop inner join  (cost=194.55 rows=1900) (actual time=0.216..0.299 rows=19 loops=19)
                                -> Filter: (course.crsCode is not null)  (cost=2.65 rows=19) (actual time=0.008..0.059 rows=19 loops=19)
                                    -> Index lookup on Course using deptid_idx (deptId=(@v8))  (cost=2.65 rows=19) (actual time=0.008..0.055 rows=19 loops=19)
                                -> Single-row index lookup on <subquery6> using <auto_distinct_key> (crsCode=course.crsCode)  (actual time=0.001..0.001 rows=1 loops=361)
                                    -> Materialize with deduplication  (cost=10.25 rows=100) (actual time=0.012..0.012 rows=1 loops=361)
                                        -> Filter: (teaching.crsCode is not null)  (cost=10.25 rows=100) (actual time=0.003..0.123 rows=100 loops=19)
                                            -> Table scan on Teaching  (cost=10.25 rows=100) (actual time=0.003..0.103 rows=100 loops=19)
                -> Select #5 (subquery in projection; uncacheable)
                    -> Aggregate: count(0)  (actual time=0.304..0.304 rows=1 loops=19)
                        -> Nested loop inner join  (cost=194.55 rows=1900) (actual time=0.216..0.299 rows=19 loops=19)
                            -> Filter: (course.crsCode is not null)  (cost=2.65 rows=19) (actual time=0.008..0.059 rows=19 loops=19)
                                -> Index lookup on Course using deptid_idx (deptId=(@v8))  (cost=2.65 rows=19) (actual time=0.008..0.055 rows=19 loops=19)
                            -> Single-row index lookup on <subquery6> using <auto_distinct_key> (crsCode=course.crsCode)  (actual time=0.001..0.001 rows=1 loops=361)
                                -> Materialize with deduplication  (cost=10.25 rows=100) (actual time=0.012..0.012 rows=1 loops=361)
                                    -> Filter: (teaching.crsCode is not null)  (cost=10.25 rows=100) (actual time=0.003..0.123 rows=100 loops=19)
                                        -> Table scan on Teaching  (cost=10.25 rows=100) (actual time=0.003..0.103 rows=100 loops=19)
    -> Single-row index lookup on Student using PRIMARY (id=alias.studId)  (cost=0.68 rows=1) (never executed)
*/

-- SIMPLIFY DEPT @V8 COURSE COUNT LOOKUP:
set @course_count = (SELECT count(*) FROM Course WHERE deptId = @v8);

-- BREAK INTO TEMP TABLES:
drop table if exists student_course_count;
create temporary table student_course_count
SELECT 
	  tra.studid
	, count(distinct tra.crsCode) as course_count
from transcript tra
inner join course crs
	on tra.crsCode = crs.crsCode
where crs.deptId = @v8
group by studid;
alter table student_course_count add primary key (studid);
create index course_count_idx on student_course_count (course_count);

explain analyze
select stu.name
from student_course_count scc
inner join student stu
	on scc.studid = stu.id
where scc.course_count = @course_count
/*
-> Zero rows (no matching row in const table)  (actual time=0.000..0.000 rows=0 loops=1)
*/
