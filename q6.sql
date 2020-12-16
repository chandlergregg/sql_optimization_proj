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
 * -> Nested loop inner join  (actual time=2.631..2.631 rows=0 loops=1)
    -> Filter: (alias.studId is not null)  (actual time=2.622..2.622 rows=0 loops=1)
        -> Table scan on alias  (cost=2.73 rows=2) (actual time=0.001..0.001 rows=0 loops=1)
            -> Materialize  (actual time=2.622..2.622 rows=0 loops=1)
                -> Filter: (count(0) = (select #5))  (actual time=2.612..2.612 rows=0 loops=1)
                    -> Table scan on <temporary>  (actual time=0.001..0.002 rows=19 loops=1)
                        -> Aggregate using temporary table  (actual time=2.604..2.608 rows=19 loops=1)
                            -> Nested loop inner join  (cost=10.54 rows=20) (actual time=0.296..0.439 rows=19 loops=1)
                                -> Filter: (`<subquery3>`.crsCode is not null)  (cost=3.69 rows=19) (actual time=0.285..0.298 rows=19 loops=1)
                                    -> Table scan on <subquery3>  (cost=3.69 rows=19) (actual time=0.001..0.006 rows=19 loops=1)
                                        -> Materialize with deduplication  (cost=9.40 rows=20) (actual time=0.284..0.292 rows=19 loops=1)
                                            -> Filter: (course.crsCode is not null)  (cost=9.40 rows=20) (actual time=0.040..0.250 rows=19 loops=1)
                                                -> Nested loop inner join  (cost=9.40 rows=20) (actual time=0.040..0.234 rows=19 loops=1)
                                                    -> Filter: (course.crsCode is not null)  (cost=2.65 rows=19) (actual time=0.030..0.081 rows=19 loops=1)
                                                        -> Index lookup on Course using deptid_idx (deptId=(@v8))  (cost=2.65 rows=19) (actual time=0.029..0.076 rows=19 loops=1)
                                                    -> Index lookup on Teaching using crscode_semester_idx (crsCode=course.crsCode)  (cost=0.26 rows=1) (actual time=0.006..0.008 rows=1 loops=19)
                                -> Index lookup on Transcript using crscode_idx (crsCode=`<subquery3>`.crsCode)  (cost=5.00 rows=1) (actual time=0.005..0.007 rows=1 loops=19)
                    -> Select #5 (subquery in condition; uncacheable)
                        -> Aggregate: count(0)  (actual time=0.109..0.109 rows=1 loops=19)
                            -> Nested loop semijoin  (cost=9.40 rows=20) (actual time=0.011..0.105 rows=19 loops=19)
                                -> Filter: (course.crsCode is not null)  (cost=2.65 rows=19) (actual time=0.007..0.051 rows=19 loops=19)
                                    -> Index lookup on Course using deptid_idx (deptId=(@v8))  (cost=2.65 rows=19) (actual time=0.006..0.047 rows=19 loops=19)
                                -> Index lookup on Teaching using crscode_semester_idx (crsCode=course.crsCode)  (cost=0.27 rows=1) (actual time=0.003..0.003 rows=1 loops=361)
                -> Select #5 (subquery in projection; uncacheable)
                    -> Aggregate: count(0)  (actual time=0.109..0.109 rows=1 loops=19)
                        -> Nested loop semijoin  (cost=9.40 rows=20) (actual time=0.011..0.105 rows=19 loops=19)
                            -> Filter: (course.crsCode is not null)  (cost=2.65 rows=19) (actual time=0.007..0.051 rows=19 loops=19)
                                -> Index lookup on Course using deptid_idx (deptId=(@v8))  (cost=2.65 rows=19) (actual time=0.006..0.047 rows=19 loops=19)
                            -> Index lookup on Teaching using crscode_semester_idx (crsCode=course.crsCode)  (cost=0.27 rows=1) (actual time=0.003..0.003 rows=1 loops=361)
    -> Single-row index lookup on Student using PRIMARY (id=alias.studId)  (cost=0.68 rows=1) (never executed)
*/

SELECT name FROM Student,
	(SELECT studId
	FROM Transcript
		WHERE crsCode IN
		(SELECT crsCode FROM Course WHERE deptId = @v8 AND crsCode IN (SELECT crsCode FROM Teaching))
		GROUP BY studId
		HAVING COUNT(*) = 
			(SELECT COUNT(*) FROM Course WHERE deptId = @v8 AND crsCode IN (SELECT crsCode FROM Teaching))) as alias
WHERE id = alias.studId;


/* Simplify course count subquery to variable assignment */
SELECT COUNT(*) FROM Course WHERE deptId = @v8 AND crsCode IN (SELECT crsCode FROM Teaching);
SELECT * FROM Course WHERE deptId = @v8 AND crsCode IN (SELECT crsCode FROM Teaching);
select * from course where crscode not in (select crscode from teaching);
explain analyze SELECT count(*) FROM Course WHERE deptId = @v8;
set @course_count = (SELECT count(*) FROM Course WHERE deptId = @v8);

explain analyze
SELECT 
	  studid
	, count(distinct crsCode) as course_count
from transcript
group by studid;
/*
-> Group aggregate: count(distinct transcript.crsCode)  (actual time=0.062..0.280 rows=100 loops=1)
    -> Index scan on transcript using studid_idx  (cost=10.25 rows=100) (actual time=0.046..0.206 rows=100 loops=1)
*/

explain analyze
SELECT 
	  tra.studid
	, count(distinct tra.crsCode) as course_count
from transcript tra
inner join course crs
	on tra.crsCode = crs.crsCode
where crs.deptId = @v8
group by studid;
/*
-> Group aggregate: count(distinct transcript.crsCode)  (actual time=0.213..0.220 rows=19 loops=1)
    -> Sort: tra.studId  (actual time=0.203..0.205 rows=19 loops=1)
        -> Table scan on <temporary>  (actual time=0.001..0.011 rows=19 loops=1)
            -> Temporary table  (cost=9.51 rows=20) (actual time=0.176..0.188 rows=19 loops=1)
                -> Nested loop inner join  (cost=9.51 rows=20) (actual time=0.039..0.159 rows=19 loops=1)
                    -> Filter: (crs.crsCode is not null)  (cost=2.65 rows=19) (actual time=0.028..0.061 rows=19 loops=1)
                        -> Index lookup on crs using deptid_idx (deptId=(@v8))  (cost=2.65 rows=19) (actual time=0.027..0.057 rows=19 loops=1)
                    -> Index lookup on tra using crscode_idx (crsCode=crs.crsCode)  (cost=0.26 rows=1) (actual time=0.004..0.005 rows=1 loops=19)
*/

create temporary table student_course_count
SELECT 
	  tra.studid
	, count(distinct tra.crsCode) as course_count
from transcript tra
inner join course crs
	on tra.crsCode = crs.crsCode
where crs.deptId = @v8
group by studid;
create unique index studid_idx on student_course_count (studid);

explain analyze
select stu.name
from student_course_count scc
inner join student stu
	on scc.studid = stu.id
where scc.course_count = @course_count
/*
-> Nested loop inner join  (cost=4.24 rows=2) (actual time=0.078..0.078 rows=0 loops=1)
    -> Filter: ((scc.course_count = <cache>((@course_count))) and (scc.studid is not null))  (cost=2.15 rows=2) (actual time=0.077..0.077 rows=0 loops=1)
        -> Table scan on scc  (cost=2.15 rows=19) (actual time=0.028..0.065 rows=19 loops=1)
    -> Single-row index lookup on stu using PRIMARY (id=scc.studid)  (cost=1.05 rows=1) (never executed)
*/

select stu.name
from student_course_count scc
inner join student stu
	on scc.studid = stu.id
where scc.course_count = @course_count;

SELECT 
	  tra.studid
	, count(distinct tra.crsCode) as course_count
from transcript tra
inner join course crs
	on tra.crsCode = crs.crsCode
inner join student stu
	on stu.
where crs.deptId = @v8
group by studid;