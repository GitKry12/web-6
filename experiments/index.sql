-- Reproducible index experiment. Refuse to rebuild the main database.
\set ON_ERROR_STOP on
SELECT current_database() = 'idx_demo' AS is_demo \gset
\if :is_demo
\else
    \echo ERROR: run this script with -d idx_demo only.
    -- Force a nonzero exit with ON_ERROR_STOP.
    SELECT 1 / 0;
\endif
\ir ../schema.sql
-- The final schema includes this index; remove it only in the demo baseline.
DROP INDEX IF EXISTS enrollments_student_id_idx;
\ir idx_data.sql

SELECT (SELECT count(*) FROM courses) AS courses,
       (SELECT count(*) FROM students) AS students,
       (SELECT count(*) FROM enrollments) AS enrollments;
\echo EMAIL LOOKUP
EXPLAIN SELECT * FROM students WHERE email = 'student777@example.com';
\echo COURSE LOOKUP
EXPLAIN SELECT * FROM enrollments WHERE course_id = 'course-7';
\echo BEFORE INDEX
EXPLAIN SELECT * FROM enrollments WHERE student_id = 777;
EXPLAIN ANALYZE SELECT * FROM enrollments WHERE student_id = 777;
EXPLAIN ANALYZE SELECT * FROM enrollments WHERE student_id = 777;
EXPLAIN ANALYZE SELECT * FROM enrollments WHERE student_id = 777;

CREATE INDEX enrollments_student_id_idx ON enrollments (student_id);
\echo AFTER INDEX
EXPLAIN SELECT * FROM enrollments WHERE student_id = 777;
EXPLAIN ANALYZE SELECT * FROM enrollments WHERE student_id = 777;
EXPLAIN ANALYZE SELECT * FROM enrollments WHERE student_id = 777;
EXPLAIN ANALYZE SELECT * FROM enrollments WHERE student_id = 777;
SELECT pg_size_pretty(pg_relation_size('enrollments')) AS table_size,
       pg_size_pretty(pg_relation_size('enrollments_student_id_idx')) AS index_size;
