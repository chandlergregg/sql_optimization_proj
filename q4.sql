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

-- 4. List the names of students who have taken a course taught by professor v5 (name).
SELECT name FROM Student,
	(SELECT studId FROM Transcript,
		(SELECT crsCode, semester FROM Professor
			JOIN Teaching
			WHERE Professor.name = @v5 AND Professor.id = Teaching.profId) as alias1
	WHERE Transcript.crsCode = alias1.crsCode AND Transcript.semester = alias1.semester) as alias2
WHERE Student.id = alias2.studId;

-- -------------------------------------------------------------------

EXPLAIN ANALYZE
SELECT name FROM Student,
	(SELECT studId FROM Transcript,
		(SELECT crsCode, semester FROM Professor
			JOIN Teaching
			WHERE Professor.name = @v5 AND Professor.id = Teaching.profId) as alias1
	WHERE Transcript.crsCode = alias1.crsCode AND Transcript.semester = alias1.semester) as alias2
WHERE Student.id = alias2.studId;
/*
-> -> Nested loop inner join  (cost=1.12 rows=0) (actual time=0.052..0.052 rows=0 loops=1)
    -> Nested loop inner join  (cost=1.05 rows=0) (actual time=0.051..0.051 rows=0 loops=1)
        -> Nested loop inner join  (cost=0.70 rows=1) (actual time=0.031..0.033 rows=1 loops=1)
            -> Index lookup on Professor using name_idx (name=(@v5))  (cost=0.35 rows=1) (actual time=0.019..0.020 rows=1 loops=1)
            -> Filter: (teaching.crsCode is not null)  (cost=0.35 rows=1) (actual time=0.011..0.012 rows=1 loops=1)
                -> Index lookup on Teaching using profid_idx (profId=professor.id)  (cost=0.35 rows=1) (actual time=0.011..0.011 rows=1 loops=1)
        -> Filter: ((transcript.semester = teaching.semester) and (transcript.studId is not null))  (cost=0.26 rows=0) (actual time=0.018..0.018 rows=0 loops=1)
            -> Index lookup on Transcript using crsCode_idx (crsCode=teaching.crsCode)  (cost=0.26 rows=1) (actual time=0.011..0.016 rows=2 loops=1)
    -> Single-row index lookup on Student using PRIMARY (id=transcript.studId)  (cost=1.62 rows=1) (never executed)
 */

-- -------------------------------------------
-- Try breaking into CTEs

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
 * -> Nested loop inner join  (cost=1.12 rows=0) (actual time=0.062..0.062 rows=0 loops=1)
    -> Nested loop inner join  (cost=1.05 rows=0) (actual time=0.062..0.062 rows=0 loops=1)
        -> Nested loop inner join  (cost=0.70 rows=1) (actual time=0.037..0.039 rows=1 loops=1)
            -> Index lookup on pro using name_idx (name=(@v5))  (cost=0.35 rows=1) (actual time=0.023..0.024 rows=1 loops=1)
            -> Filter: (tea.crsCode is not null)  (cost=0.35 rows=1) (actual time=0.013..0.014 rows=1 loops=1)
                -> Index lookup on tea using profid_idx (profId=pro.id)  (cost=0.35 rows=1) (actual time=0.012..0.013 rows=1 loops=1)
        -> Filter: ((tra.semester = tea.semester) and (tra.studId is not null))  (cost=0.26 rows=0) (actual time=0.022..0.022 rows=0 loops=1)
            -> Index lookup on tra using crsCode_idx (crsCode=tea.crsCode)  (cost=0.26 rows=1) (actual time=0.013..0.020 rows=2 loops=1)
    -> Single-row index lookup on stu using PRIMARY (id=tra.studId)  (cost=1.62 rows=1) (never executed)
 */

EXPLAIN ANALYZE
with cte_course_semester as (
	SELECT
		  crsCode
		, semester 
	FROM Professor pro
	inner JOIN Teaching tea
		on pro.id = tea.profId
	WHERE pro.name = @v5
)
select
	  stu.name
from cte_course_semester ccs
inner join transcript tra
	on ccs.crscode = tra.crsCode 
	and ccs.semester = tra.semester
inner join student stu	
	on tra.studid = stu.id;
/*
 * -> Nested loop inner join  (cost=1.12 rows=0) (actual time=0.066..0.066 rows=0 loops=1)
    -> Nested loop inner join  (cost=1.05 rows=0) (actual time=0.065..0.065 rows=0 loops=1)
        -> Nested loop inner join  (cost=0.70 rows=1) (actual time=0.038..0.041 rows=1 loops=1)
            -> Index lookup on pro using name_idx (name=(@v5))  (cost=0.35 rows=1) (actual time=0.023..0.024 rows=1 loops=1)
            -> Filter: (tea.crsCode is not null)  (cost=0.35 rows=1) (actual time=0.014..0.015 rows=1 loops=1)
                -> Index lookup on tea using profid_idx (profId=pro.id)  (cost=0.35 rows=1) (actual time=0.013..0.014 rows=1 loops=1)
        -> Filter: ((tra.semester = tea.semester) and (tra.studId is not null))  (cost=0.26 rows=0) (actual time=0.024..0.024 rows=0 loops=1)
            -> Index lookup on tra using crsCode_idx (crsCode=tea.crsCode)  (cost=0.26 rows=1) (actual time=0.014..0.021 rows=2 loops=1)
    -> Single-row index lookup on stu using PRIMARY (id=tra.studId)  (cost=1.62 rows=1) (never executed)
 */

-- -------------------------------------------------------------------
-- Try temporary tables

create index profid_idx on teaching (profid);
create index name_idx on professor (name);

explain analyze
-- create temporary table course_semester as
SELECT
	  crsCode
	, semester 
FROM Professor pro
inner JOIN Teaching tea
	on pro.id = tea.profId
WHERE pro.name = @v5;
/*
 * -> Nested loop inner join  (cost=0.70 rows=1) (actual time=0.042..0.048 rows=1 loops=1)
    -> Index lookup on pro using name_idx (name=(@v5))  (cost=0.35 rows=1) (actual time=0.027..0.029 rows=1 loops=1)
    -> Index lookup on tea using profid_idx (profId=pro.id)  (cost=0.35 rows=1) (actual time=0.012..0.016 rows=1 loops=1)
 */

explain analyze
-- create temporary table student_id as 
select
	  studid
from course_semester ccs
inner join transcript tra
	on ccs.crscode = tra.crsCode 
	and ccs.semester = tra.semester;
/*
 * -> Nested loop inner join  (cost=0.70 rows=0) (actual time=0.050..0.050 rows=0 loops=1)
    -> Filter: (ccs.crsCode is not null)  (cost=0.35 rows=1) (actual time=0.021..0.022 rows=1 loops=1)
        -> Table scan on ccs  (cost=0.35 rows=1) (actual time=0.020..0.021 rows=1 loops=1)
    -> Filter: (tra.semester = ccs.semester)  (cost=0.26 rows=0) (actual time=0.026..0.026 rows=0 loops=1)
        -> Index lookup on tra using crsCode_idx (crsCode=ccs.crsCode)  (cost=0.26 rows=1) (actual time=0.019..0.025 rows=2 loops=1)
 */

EXPLAIN analyze
select
	  stu.name
from student_id sid
inner join student stu	
	on sid.studid = stu.id;
/*
 * -> Nested loop inner join  (cost=1.07 rows=1) (actual time=0.021..0.021 rows=0 loops=1)
    -> Filter: (sid.studid is not null)  (cost=0.35 rows=1) (actual time=0.021..0.021 rows=0 loops=1)
        -> Table scan on sid  (cost=0.35 rows=1) (actual time=0.020..0.020 rows=0 loops=1)
    -> Single-row index lookup on stu using PRIMARY (id=sid.studid)  (cost=0.72 rows=1) (never executed)
 */

/* OPTIMIZATIONS:
 * Add index to teaching.profid
 * Add index to professor.name
 * Add index to transcript.crscode, semester
 */


EXPLAIN analyze
SELECT
	  crsCode
	, semester 
FROM Professor pro
inner JOIN Teaching tea
	on pro.id = tea.profId
WHERE pro.name = 'Dominik Bailey'

EXPLAIN analyze
with cte_prof_id as (
	select id
	FROM Professor pro
	where pro.name = 'Dominik Bailey'
)
select
	  crscode
	, semester
from teaching tea
where profid in (select id from cte_prof_id)

-> Nested loop inner join  (cost=0.70 rows=1) (actual time=0.061..0.066 rows=1 loops=1)
    -> Index lookup on pro using name_idx (name='Dominik Bailey')  (cost=0.35 rows=1) (actual time=0.025..0.027 rows=1 loops=1)
    -> Index lookup on tea using profid_idx (profId=pro.id)  (cost=0.35 rows=1) (actual time=0.034..0.038 rows=1 loops=1)

-> Nested loop inner join  (cost=0.70 rows=1) (actual time=0.030..0.035 rows=1 loops=1)
    -> Index lookup on pro using name_idx (name='Dominik Bailey')  (cost=0.35 rows=1) (actual time=0.019..0.020 rows=1 loops=1)
    -> Index lookup on tea using profid_idx (profId=pro.id)  (cost=0.35 rows=1) (actual time=0.010..0.013 rows=1 loops=1)
    

-> Zero rows (no matching row in const table)  (actual time=0.000..0.000 rows=0 loops=1)


select * from teaching limit 10;
select * from Professor p2  where id = 3343006;
describe course;
show indexes from transcript;

drop index crscode_semester_idx on transcript;
drop index studid_idx on transcript;
drop index crscode_semester_idx on teaching;
create index crscode_semester_idx on transcript (crscode, semester);
create index studid_idx on transcript (studid);
show indexes from transcript;
create index crscode_semester_idx on teaching (crscode, semester);
show indexes from teaching;

EXPLAIN ANALYZE
with cte_profid as (
	SELECT
		  id as profid
	FROM Professor
	WHERE name = @v5
), cte_crs_semester as (
	select
		  tea.crsCode 
		, tea.semester
	from cte_profid pid
	inner join teaching tea
		on pid.profid = tea.profId
), cte_studid as (
	select 
		  tra.studId
	from cte_crs_semester cs
	inner join transcript tra
		on cs.crscode = tra.crsCode 
		and cs.semester = tra.semester
)
select 
	  stu.name
from cte_studid sid
inner join Student stu
	on sid.studid = stu.id;
	
explain analyze
select
	  stu.name as student_name
from Professor pro
inner join teaching tea
	on pro.id = tea.profId 
inner join Transcript tra
	on tea.crsCode = tra.crsCode 
	and tea.semester = tra.semester
inner join Student stu
	on tra.studId = stu.id 
where pro.name = @v5


/*
 * -> Nested loop inner join  (cost=1.78 rows=1) (actual time=0.046..0.046 rows=0 loops=1)
    -> Nested loop inner join  (cost=1.05 rows=1) (actual time=0.046..0.046 rows=0 loops=1)
        -> Nested loop inner join  (cost=0.70 rows=1) (actual time=0.031..0.036 rows=1 loops=1)
            -> Index lookup on pro using name_idx (name=(@v5))  (cost=0.35 rows=1) (actual time=0.019..0.020 rows=1 loops=1)
            -> Filter: ((tea.crsCode is not null) and (tea.semester is not null))  (cost=0.35 rows=1) (actual time=0.011..0.014 rows=1 loops=1)
                -> Index lookup on tea using profid_idx (profId=pro.id)  (cost=0.35 rows=1) (actual time=0.010..0.013 rows=1 loops=1)
        -> Filter: (tra.studId is not null)  (cost=0.35 rows=1) (actual time=0.010..0.010 rows=0 loops=1)
            -> Index lookup on tra using crscode_semester_idx (crsCode=tea.crsCode, semester=tea.semester)  (cost=0.35 rows=1) (actual time=0.010..0.010 rows=0 loops=1)
    -> Single-row index lookup on stu using PRIMARY (id=tra.studId)  (cost=0.72 rows=1) (never executed)

*/
