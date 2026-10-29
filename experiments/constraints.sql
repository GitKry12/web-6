-- Intentional errors: keep going to collect all ten verbose diagnostics.
\set ON_ERROR_STOP off
\set VERBOSITY verbose
\echo 1. NULL title
INSERT INTO courses (id, title, description, credits) VALUES ('x-test', NULL, 'Test', 3);
\echo 2. Zero credits
INSERT INTO courses (id, title, description, credits) VALUES ('x-test', 'Test', 'Test', 0);
\echo 3. Negative likes
UPDATE courses SET likes = -1 WHERE id = 'api-design';
\echo 4. One-character name
INSERT INTO students (name, email) VALUES ('A', 'a@example.com');
\echo 5. Duplicate email
INSERT INTO students (name, email) VALUES ('Dup Student', 'aigerim@example.com');
\echo 6. Duplicate course ID
INSERT INTO courses (id, title, description, credits) VALUES ('api-design', 'x', 'y', 1);
\echo 7. Duplicate enrollment
INSERT INTO enrollments (course_id, student_id) VALUES ('modern-frontend', 1);
\echo 8. Missing course
INSERT INTO enrollments (course_id, student_id) VALUES ('no-such-course', 1);
\echo 9. Missing student
INSERT INTO enrollments (course_id, student_id) VALUES ('web-security', 999);
\echo 10. RESTRICT course deletion
DELETE FROM courses WHERE id = 'modern-frontend';
\set ON_ERROR_STOP on
\echo 11. Cascading delete and rollback
BEGIN;
SELECT count(*) AS before_delete FROM enrollments;
DELETE FROM students WHERE email = 'daniyar@example.com';
SELECT count(*) AS after_delete FROM enrollments;
ROLLBACK;
SELECT count(*) AS after_rollback FROM enrollments;
\set VERBOSITY default
