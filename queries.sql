-- Nine SQL examples for the API. Run with psql -v ON_ERROR_STOP=1.
-- Fixed values are demonstration inputs; application code must bind parameters.
-- Mutations roll back; identity sequence values can still have gaps.

-- 1. GET /courses?is_elective=false&sort=popular&page=1&page_size=3
SELECT id, title, credits, likes
FROM courses
WHERE is_elective = false
ORDER BY likes DESC, id
LIMIT 3 OFFSET 0;

-- 1b. Same filter, second page: OFFSET = (2 - 1) * 3.
SELECT id, title, credits, likes
FROM courses
WHERE is_elective = false
ORDER BY likes DESC, id
LIMIT 3 OFFSET 3;

-- 2. GET /courses/{course_id}
SELECT id, title, credits, is_elective, likes
FROM courses WHERE id = 'api-design';

-- 2b. Zero rows: the API returns 404.
SELECT id, title, credits, is_elective, likes
FROM courses WHERE id = 'no-such-course';

-- 3. POST /courses/{course_id}/like: increment in one atomic statement.
BEGIN;
UPDATE courses SET likes = likes + 1
WHERE id = 'api-design' RETURNING id, likes;

-- 3b. UPDATE 0 is not a SQL error; the API returns 404.
UPDATE courses SET likes = likes + 1
WHERE id = 'no-such-course' RETURNING id, likes;
ROLLBACK;

-- 4. POST /enrollments
BEGIN;
INSERT INTO enrollments (course_id, student_id)
VALUES ('web-security', 3)
RETURNING id, course_id, student_id;
ROLLBACK;

-- 5. GET /enrollments
SELECT e.id, s.name AS student, c.title AS course
FROM enrollments e
JOIN students s ON s.id = e.student_id
JOIN courses c ON c.id = e.course_id
ORDER BY e.id;

-- 6. Statistics, including courses without enrollments.
-- count(e.id) ignores NULL from LEFT JOIN; count(*) would incorrectly give 1.
SELECT c.id, count(e.id) AS enrolled
FROM courses c
LEFT JOIN enrollments e ON e.course_id = c.id
GROUP BY c.id
ORDER BY enrolled DESC, c.id;
