# course-catalog-db

Лабораторная работа 6: схема PostgreSQL для каталога курсов.
Данные курсов совпадают с [data.py предыдущей лабораторной](https://github.com/GitKry12/fastapi/blob/main/data.py).
В этой работе SQL выполняется через `psql`; подключение FastAPI к БД относится к следующей лабораторной.

## Constraint violation log

Эксперименты действительно выполнены на PostgreSQL **17.4** с `\set VERBOSITY verbose`.
Команды: [experiments/constraints.sql](experiments/constraints.sql).
Полный вывод: [experiments/results/constraints.txt](experiments/results/constraints.txt).
HTTP-коды ниже — предлагаемый ответ будущего API, а не ответ сервера PostgreSQL.

| № | Нарушение | SQLSTATE | Ограничение или поле | Ответ API |
|---|---|---|---|---|
| 1 | NULL в courses.title | 23502 | колонка title; у NOT NULL в PG 17 нет отдельного имени | 422; если NULL пропущен обязательной проверкой Pydantic, ошибка реализации — 500 |
| 2 | courses.credits = 0 | 23514 | courses_credits_check | 422 Unprocessable Entity |
| 3 | courses.likes = -1 | 23514 | courses_likes_check | 500 Internal Server Error: счётчик изменяет код приложения |
| 4 | Имя из одного символа | 23514 | students_name_check | 422 Unprocessable Entity |
| 5 | Повтор email | 23505 | students_email_key | 409 Conflict |
| 6 | Повтор идентификатора курса | 23505 | courses_pkey | 409 Conflict |
| 7 | Повтор пары курс–студент | 23505 | enrollments_course_id_student_id_key | 409 Conflict |
| 8 | Несуществующий курс | 23503 | enrollments_course_id_fkey | 404 Not Found |
| 9 | Несуществующий студент | 23503 | enrollments_student_id_fkey | 404 Not Found: студент не найден |
| 10 | Удаление курса с записями | 23503 | enrollments_course_id_fkey | 409 Conflict |
| 11 | Удаление Данияра с CASCADE | Ошибки нет | enrollments_student_id_fkey | 204 No Content при успешном удалении; в эксперименте выполнен ROLLBACK |

В эксперименте 11 число записей изменилось **6 → 3 → 6**: три записи Данияра удалились вместе со студентом, затем откат восстановил всё. После десяти ошибок и каскадного эксперимента осталось **6 курсов, 3 студента, 6 записей**. В PostgreSQL 18 RESTRICT может возвращать `23001`; здесь зафиксирован фактически полученный `23503` версии 17.4.

Pydantic даёт клиенту понятную ошибку до обращения к базе, но данные могут записывать также SQL-скрипты, другие сервисы и администраторы. Ограничения БД защищают целостность независимо от того, кто выполняет запись, и обеспечивают UNIQUE даже при одновременных запросах. Поэтому проверки API и базы дополняют друг друга.

IDENTITY может пропускать числа: ошибка INSERT и ROLLBACK не возвращают выданный номер последовательности. Номера уникальны благодаря первичному ключу, но не обязаны идти подряд.
