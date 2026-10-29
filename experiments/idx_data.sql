-- Run on a fresh schema in idx_demo only: 500 / 20000 / 50000 rows.
BEGIN;
INSERT INTO courses (id, title, description, credits)
SELECT 'course-' || g, 'Course ' || g, 'Test', 3
FROM generate_series(1, 500) AS g;

INSERT INTO students (name, email)
SELECT 'Student ' || g, 'student' || g || '@example.com'
FROM generate_series(1, 20000) AS g;

INSERT INTO enrollments (course_id, student_id)
SELECT 'course-' || (1 + (g + g / 20000) % 500), 1 + g % 20000
FROM generate_series(1, 50000) AS g;
COMMIT;

ANALYZE courses;
ANALYZE students;
ANALYZE enrollments;
