"""Run Lab 6 with two independent psql sessions (Python standard library only).

Use a freshly seeded course_catalog. Connection settings come from PGHOST,
PGPORT, PGUSER, PGPASSWORD / pgpass. PSQL optionally selects the psql executable.
The successful scenario commits Madina and her enrollment, as the lab requires.
"""
import os
from pathlib import Path
from queue import Queue
import subprocess
from threading import Thread
import uuid

TRANSCRIPT = []


class Session:
    def __init__(self, name):
        self.name = name
        self.lines = Queue()
        self.proc = subprocess.Popen(
            [os.environ.get('PSQL', 'psql'), '-X', '-q', '-A', '-t',
             '-d', 'course_catalog', '-v', 'ON_ERROR_STOP=0',
             '-v', 'VERBOSITY=verbose', '-P', 'pager=off'],
            stdin=subprocess.PIPE, stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT, text=True, encoding='utf-8', bufsize=1)
        Thread(target=self._read, daemon=True).start()

    def _read(self):
        for line in self.proc.stdout:
            self.lines.put(line.rstrip('\n'))
        self.lines.put(None)

    def sql(self, command):
        marker = 'done_' + uuid.uuid4().hex
        self.proc.stdin.write(command + '\n\\echo ' + marker + '\n')
        self.proc.stdin.flush()
        result = []
        while True:
            line = self.lines.get(timeout=20)
            if line is None:
                raise RuntimeError('psql closed: ' + '\n'.join(result))
            if line == marker:
                break
            result.append(line)
        output = '\n'.join(result).strip()
        TRANSCRIPT.append(f'[{self.name}]\n{command}\n{output}\n')
        return output

    def close(self):
        if self.proc.poll() is None:
            try:
                self.proc.stdin.write('ROLLBACK;\n\\q\n')
                self.proc.stdin.flush()
                self.proc.wait(timeout=5)
            except (BrokenPipeError, subprocess.TimeoutExpired):
                self.proc.kill()
                self.proc.wait()
        self.proc.stdin.close()
        self.proc.stdout.close()


def expect(session, sql, expected):
    actual = session.sql(sql)
    if actual != expected:
        raise AssertionError(f'{sql}: expected {expected!r}, got {actual!r}')


def main():
    a, b = Session('A'), Session('B')
    try:
        counts = 'SELECT (SELECT count(*) FROM courses), (SELECT count(*) FROM students), (SELECT count(*) FROM enrollments);'
        student_count = "SELECT count(*) FROM students WHERE email='madina@example.com';"
        enrollment_count = "SELECT count(*) FROM enrollments e JOIN students s ON s.id=e.student_id WHERE s.email='madina@example.com';"
        insert_student = "INSERT INTO students(name,email) VALUES ('Madina Ospanova','madina@example.com');"
        expect(a, counts, '6|3|6')
        expect(a, student_count, '0')
        expect(b, 'SHOW default_transaction_isolation;', 'read committed')

        expect(a, 'BEGIN;', '')
        expect(a, insert_student, '')
        error = a.sql("INSERT INTO enrollments(course_id,student_id) SELECT 'no-such-course',id FROM students WHERE email='madina@example.com';")
        assert '23503' in error and 'enrollments_course_id_fkey' in error
        assert '25P02' in a.sql('SELECT count(*) FROM students;')
        expect(a, 'ROLLBACK;', '')
        expect(a, student_count, '0')
        expect(b, enrollment_count, '0')
        expect(a, counts, '6|3|6')

        expect(a, 'BEGIN;', '')
        expect(a, insert_student, '')
        expect(a, "INSERT INTO enrollments(course_id,student_id) SELECT 'web-security',id FROM students WHERE email='madina@example.com';", '')
        expect(a, student_count, '1')
        expect(a, enrollment_count, '1')
        expect(b, student_count, '0')
        expect(b, enrollment_count, '0')
        expect(a, 'COMMIT;', '')
        expect(b, student_count, '1')
        expect(b, enrollment_count, '1')
        expect(b, counts, '6|4|7')
        expect(b, "SELECT s.name,c.title FROM enrollments e JOIN students s ON s.id=e.student_id JOIN courses c ON c.id=e.course_id WHERE s.email='madina@example.com';", 'Madina Ospanova|Web Security Essentials')
    finally:
        a.close()
        b.close()
        output = Path(__file__).parent / 'results' / 'transactions.txt'
        output.parent.mkdir(exist_ok=True)
        output.write_text('\n'.join(TRANSCRIPT), encoding='utf-8')
    print('PASS: failed transaction rolled back; B sees 0/0 before COMMIT and 1/1 after COMMIT.')


if __name__ == '__main__':
    main()
