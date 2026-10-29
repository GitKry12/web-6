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

## Index: EXPLAIN before and after

Запрос: `SELECT * FROM enrollments WHERE student_id = 777;`.
В `idx_demo` загружено **500 курсов, 20 000 студентов, 50 000 записей**.
Полный вывод трёх начальных планов и шести измерений: [index.txt](experiments/results/index.txt).

| Показатель | До индекса | После индекса |
|---|---|---|
| Метод | Seq Scan | Bitmap Heap Scan + Bitmap Index Scan |
| cost | 0.00..1042.00 | 4.31..15.59 |
| Найдено строк | 3 | 3 |
| Rows Removed by Filter | 49 997 | Не выводится: фильтрация последовательного сканирования не нужна |
| Execution Time, минимум из 3 запусков | 3.488 ms | 0.029 ms |
| Все три измерения | 3.500 / 6.405 / 3.488 ms | 0.125 / 0.029 / 0.033 ms |

До индекса:

```text
Seq Scan on enrollments  (cost=0.00..1042.00 rows=3 width=34)
  Filter: (student_id = 777)
```

После `CREATE INDEX enrollments_student_id_idx ON enrollments (student_id);`:

```text
Bitmap Heap Scan on enrollments  (cost=4.31..15.59 rows=3 width=34)
  Recheck Cond: (student_id = 777)
  -> Bitmap Index Scan on enrollments_student_id_idx  (cost=0.00..4.31 rows=3 width=0)
       Index Cond: (student_id = 777)
```

В этом запуске минимальное время сократилось примерно в **120 раз**; результат зависит от компьютера и кеша. Таблица занимает **3336 kB**, новый индекс — **896 kB**. Индекс расходует место и требует обновления при изменении индексируемых данных.

1. `PRIMARY KEY` и `UNIQUE` создают индексы автоматически, внешний ключ на ссылающейся стороне — нет. Поиск email использует `students_email_key`, а поиск course_id использует первый столбец составного уникального индекса `enrollments_course_id_student_id_key`. Для поиска только по student_id на этих данных PostgreSQL 17 выбрал полный просмотр; отдельный индекс сделал поиск дешевле.
2. Шесть курсов помещаются на одной странице: последовательное чтение дешевле обхода индекса и обращения к таблице. Для трёх совпадений среди 50 000 записей индекс позволяет не читать остальные строки. Планировщик выбирает план по стоимости, а не по факту существования индекса.
3. Индекс student_id ускоряет получение записей одного студента и поиск его дочерних записей при `ON DELETE CASCADE`.

Повторить эксперимент можно командой:

```bash
psql -h localhost -U catalog_app -d idx_demo -v ON_ERROR_STOP=1 -f experiments/index.sql
```

Скрипт проверяет имя базы, пересоздаёт только демонстрационные таблицы, удаляет индекс из базового варианта и затем создаёт его заново. Так эксперимент воспроизводится и после добавления индекса в итоговый schema.sql.
