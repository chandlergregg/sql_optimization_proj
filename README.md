# Springboard SQL optimization project
## Overview
This project contains all the sql files needed to replicate the SQL optimization project, part of the Springboard Data Engineering curriculum. The SQL optimization project is an exercise in using various techniques (mostly indexes and breaking up queries into smaller bits) to reduce the runtime and cost of SQL queries.

In order to run locally, connect to a MySQL database and run the `populate_data.sql` file. The individual numbered question files contain scratchwork used to come up with the appropriate optimizations that are implemented in the `all_questions.sql` file. You can follow along with the optimizations in the `all_questions.sql` file by running the commands in order.

For more information on Springboard, visit [springboard.com](https://www.springboard.com).

### Q1
Optimizations:
- To avoid table scan, add primary key to student table on id. This results in a much faster single-value index lookup.
Notes:
- The query plan sometimes shows a "Rows fetched before execution" instead of an index lookup. However, the query is fully optimized after adding the primary key.

### Q2
Optimizations:
- This query is already optimized with the addition of the primary key to the table from the previous question.

### Q3
Optimizations:
- Add index on transcript.crscode to allow for index lookup of crscode in subquery
- Add index on transcript.studid to make joining with student.id easier
Notes:
- Turning the transcript subquery into a join in the main query results in a faster query but at higher cost. There's a cost/speed tradeoff with each query, with the subquery being lower cost and join query being faster.

### Q4:
Optimizations:
- Add primary key to professor table for joins
- Add name index to professor table to make name lookup easier
- Add index to teaching.profid for joins
Notes:
- Adding an index on transcript.crscode and transcript.semester actually slows the query down, so it's not used

### Q5:
Optimizations:
- Break into temp tables to make query simpler
- Add deptid index on course to make dept lookup easier
- Add crscode index on course to make join easier

### Q6:
Optimizations:
- Turn the course count for dept v8 into a single variable
- Break into temp table with count for reach student and then join at end
