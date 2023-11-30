/* Расчет бизнес-метрик активности пользователей по постам за 2008 год на основе базы данных
 StackOverflow в СУБД PostgreSQL и ER-диаграммы*/
 
    /*Определим количество вопросов, которые набрали больше 300 очков или как минимум 100 раз были добавлены в «Закладки». */
SELECT COUNT (DISTINCT ID)
FROM stackoverflow.posts
WHERE (score>300 OR favorites_count>=100) AND post_type_id = 1


    /*Определим сколько в среднем в день задавали вопросов с 1 по 18 ноября 2008 включительно? Результат округлим до целого числа. */
SELECT ROUND (AVG(count.count), 0)
FROM  (SELECT count(ID), DATE_TRUNC('day', creation_date)::date
FROM stackoverflow.posts
WHERE post_type_id = 1 AND DATE_TRUNC('day', creation_date)::date BETWEEN '2008-11-01' AND '2008-11-18'
GROUP BY DATE_TRUNC('day', creation_date)::date) AS count


    /*Определим сколько пользователей получили значки сразу в день регистрации? Выведем количество уникальных пользователей. */
SELECT COUNT (DISTINCT u.ID)
FROM stackoverflow.users AS u
JOIN stackoverflow.badges AS b ON u.id=b.user_id
WHERE DATE_TRUNC('day', b.creation_date)::date=DATE_TRUNC('day', u.creation_date)::date


    /*Определим сколько уникальных постов пользователя с именем Joel Coehoorn получили хотя бы один голос?*/
SELECT COUNT (DISTINCT p.id)
FROM stackoverflow.users AS u
JOIN stackoverflow.posts AS p ON u.id=p.user_id
JOIN stackoverflow.votes AS v ON p.id=v.post_id
WHERE u.display_name = 'Joel Coehoorn' AND v.id>0


    /*Выгрузим все поля таблицы vote_types. Добавим к таблице поле rank, в которое войдут номера записей в обратном порядке. Таблицу отсортируем по полю id. */
SELECT *, ROW_NUMBER() OVER (ORDER BY id DESC) AS rank
FROM stackoverflow.vote_types 
ORDER BY id


    /*Отберем 10 пользователей, которые поставили больше всего голосов типа Close. Отобразим таблицу из двух полей: идентификатором пользователя 
    и количеством голосов. Отсортируем данные сначала по убыванию количества голосов, потом по убыванию значения идентификатора пользователя. */
SELECT u.id, COUNT (DISTINCT v.id)
FROM stackoverflow.vote_types AS vt
JOIN stackoverflow.votes AS v ON v.vote_type_id=vt.id
JOIN stackoverflow.users AS u ON v.user_id=u.id
WHERE vt.name = 'Close'
GROUP BY u.id
ORDER BY count DESC, u.id DESC
LIMIT 10



    /*Отберем 10 пользователей по количеству значков, полученных в период с 15 ноября по 15 декабря 2008 года включительно. Отобразим несколько полей:
    1.	идентификатор пользователя;
    2.	число значков;
    3.  место в рейтинге — чем больше значков, тем выше рейтинг.
    Пользователям, которые набрали одинаковое количество значков, присвоим одно и то же место в рейтинге.
    Отсортируем записи по количеству значков по убыванию, а затем по возрастанию значения идентификатора пользователя. */
SELECT *, DENSE_RANK() OVER (ORDER BY count DESC)
FROM (SELECT u.id, COUNT (DISTINCT b.id) AS count
FROM stackoverflow.badges AS b
JOIN stackoverflow.users AS u ON b.user_id=u.id
WHERE DATE_TRUNC('day', b.creation_date)::date BETWEEN '2008-11-15' AND '2008-12-15'
GROUP BY u.id
ORDER BY count DESC, u.id
LIMIT 10) AS count



    /*Определим сколько в среднем очков получает пост каждого пользователя?
    Сформируем таблицу из следующих полей:
    1	заголовок поста;
    2	идентификатор пользователя;
    3	число очков поста;
    4	среднее число очков пользователя за пост, округлённое до целого числа.
    Не будем учитывать посты без заголовка, а также те, что набрали ноль очков. */
SELECT p.title, u.id, p.score, 
   ROUND(AVG(p.score) OVER (PARTITION BY u.id), 0) AS avg_user
FROM stackoverflow.posts AS p
JOIN stackoverflow.users AS u ON u.id=p.user_id       
WHERE p.title IS NOT NULL AND p.score<>0


    /*Отобразим заголовки постов, которые были написаны пользователями, получившими более 1000 значков. Посты без заголовков не включаем в список. */
WITH ch AS (SELECT b.user_id AS most_badges, COUNT (DISTINCT b.id) AS co
FROM stackoverflow.badges AS b
GROUP BY b.user_id
HAVING COUNT (DISTINCT b.id) > 1000)

SELECT p.title
FROM ch
JOIN stackoverflow.users AS u ON ch.most_badges=u.id
JOIN stackoverflow.posts AS p ON ch.most_badges=p.user_id
WHERE p.title IS NOT NULL


    /*Выгрузим данные о пользователях из США (United States). Разделим пользователей на три группы в зависимости от количества 
    просмотров их профилей:
    1	пользователям с числом просмотров больше либо равным 350 присвоим группу 1;
    2	пользователям с числом просмотров меньше 350, но больше либо равно 100 — группу 2;
    3	пользователям с числом просмотров меньше 100 — группу 3.
    Отобразим в итоговой таблице идентификатор пользователя, количество просмотров профиля и группу. Пользователи с нулевым количеством просмотров не 
    включаем в итоговую таблицу. */
SELECT u.id, u.views,
      CASE
           WHEN u.views < 100 THEN 3
           WHEN u.views < 350 THEN 2
           ELSE 1
       END
FROM stackoverflow.users AS u 
WHERE u.location LIKE '%United States%' AND u.views > 0


    /*Далее по блоку выше, отобразим лидеров каждой группы — пользователей, которые набрали максимальное число просмотров в своей группе. Выведем поля с 
    идентификатором пользователя, группой и количеством просмотров. Отсортируем таблицу по убыванию просмотров, а затем по возрастанию значения идентификатора.*/
WITH groups AS (SELECT u.id AS id, u.views AS views,
      CASE
           WHEN u.views < 100 THEN 3
           WHEN u.views < 350 THEN 2
           WHEN u.views >= 350 THEN 1
       END AS gr       
FROM stackoverflow.users AS u 
WHERE u.location LIKE '%United States%' AND u.views > 0)

SELECT gr2.id, gr2.gr, gr2.maxim
FROM (SELECT groups.id, groups.gr, groups.views, MAX (groups.views) OVER (PARTITION BY groups.gr) AS maxim
FROM groups
ORDER BY maxim DESC) AS gr2
WHERE gr2.maxim=gr2.views
ORDER BY gr2.maxim DESC, id


    /*Посчитаем ежедневный прирост новых пользователей в ноябре 2008 года. Сформируем таблицу с полями:
    1	номер дня;
    2	число пользователей, зарегистрированных в этот день;
    3	сумму пользователей с накоплением. */
SELECT tab.nday, tab.nusers, 
       SUM(tab.nusers) OVER (ORDER BY tab.nday) AS total_users
FROM (SELECT EXTRACT(DAY FROM creation_date) AS nday, 
       COUNT (DISTINCT id) AS nusers
FROM stackoverflow.users
WHERE DATE_TRUNC('day', creation_date)::date BETWEEN '2008-11-01' AND '2008-11-30'
GROUP BY EXTRACT(DAY FROM creation_date)) AS tab


    /*Для каждого пользователя, который написал хотя бы один пост, найдем интервал между регистрацией и временем создания первого поста. Отобразим:
    1	идентификатор пользователя;
    2	разницу во времени между регистрацией и первым постом. */
SELECT DISTINCT p.user_id,
                FIRST_VALUE(p.creation_date) OVER (PARTITION BY p.user_id ORDER BY p.creation_date) - u.creation_date As difference
FROM stackoverflow.posts AS p
JOIN stackoverflow.users AS u ON u.id=p.user_id    


    /*Выведем общую сумму просмотров постов за каждый месяц 2008 года. Если данных за какой-либо месяц в базе нет, такой месяц пропустим. 
    Результат отсортируем по убыванию общего количества просмотров. */
SELECT SUM(views_count), DATE_TRUNC('month', creation_date)::date
FROM stackoverflow.posts
WHERE creation_date::date BETWEEN '2008-01-01' AND '2008-12-31'
GROUP BY DATE_TRUNC('month', creation_date)::date
ORDER BY sum DESC


    /*Выведем имена самых активных пользователей, которые в первый месяц после регистрации (включая день регистрации) дали больше 100 ответов. 
    Вопросы, которые задавали пользователи, не учитываем. Для каждого имени пользователя выведем количество уникальных значений user_id. 
    Отсортируем результат по полю с именами в лексикографическом порядке. */
SELECT u.display_name, COUNT(DISTINCT u.id)
FROM stackoverflow.users AS u
JOIN stackoverflow.posts AS p ON p.user_id = u.id
JOIN stackoverflow.post_types AS pt ON p.post_type_id=pt.id
WHERE (p.creation_date::date BETWEEN u.creation_date::date AND u.creation_date::date + INTERVAL '1 month') AND (pt.type = 'Answer')
GROUP BY (u.display_name)
HAVING (COUNT(p.id)>100)
ORDER BY u.display_name


    /*Выведем количество постов за 2008 год по месяцам. Отберем посты от пользователей, которые зарегистрировались в сентябре 2008 года и 
    сделали хотя бы один пост в декабре того же года. Отсортируем таблицу по значению месяца по убыванию. */
SELECT COUNT(p.id), DATE_TRUNC('month', p.creation_date)::date
FROM stackoverflow.posts AS p
WHERE p.user_id IN (SELECT u.id AS vid
FROM stackoverflow.users AS u
JOIN stackoverflow.posts AS p ON p.user_id = u.id
WHERE (u.creation_date::date BETWEEN '2008-09-01' AND '2008-09-30') AND (p.creation_date::date BETWEEN '2008-12-01' AND '2008-12-31')
GROUP BY u.id
HAVING COUNT(p.id) > 0)
GROUP BY DATE_TRUNC('month', p.creation_date)::date
ORDER BY DATE_TRUNC('month', p.creation_date)::date DESC


    /*Используя данные о постах, выведем несколько полей:
    1.	идентификатор пользователя, который написал пост;
    2.	дата создания поста;
    3.	количество просмотров у текущего поста;
    4.	сумму просмотров постов автора с накоплением.
    Далее отсортируем данные в таблице по возрастанию идентификаторов пользователей, а данные об одном и том же пользователе — по возрастанию даты создания поста. */
SELECT p.user_id, p.creation_date, p.views_count,
       SUM(p.views_count) OVER (PARTITION BY p.user_id ORDER BY p.creation_date ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
FROM stackoverflow.posts AS p
ORDER BY p.user_id, p.creation_date


    /*Определим сколько в среднем дней в период с 1 по 7 декабря 2008 года включительно пользователи взаимодействовали с платформой? Для каждого пользователя 
    отберем дни, в которые он или она опубликовали хотя бы один пост. Нужно получить одно целое число — если необходимо округлить результат.*/
WITH days AS (SELECT p.user_id, COUNT (DISTINCT p.creation_date::date) AS days
FROM stackoverflow.posts AS p
WHERE creation_date::date BETWEEN '2008-12-01' AND '2008-12-07'
GROUP BY p.user_id)

SELECT ROUND(AVG (days), 0)
FROM days


    /*Определим на сколько процентов менялось количество постов ежемесячно с 1 сентября по 31 декабря 2008 года? Отобразим таблицу со следующими полями:
    1.	номер месяца;
    2.	количество постов за месяц;
    3.	процент, который показывает, насколько изменилось количество постов в текущем месяце по сравнению с предыдущим.
    Если постов стало меньше, значение процента должно быть отрицательным, если больше — положительным. Округлим значение процента до двух знаков после запятой.
    Так как при делении одного целого числа на другое в PostgreSQL в результате получится целое число, округлённое до ближайшего целого вниз, то чтобы этого 
    избежать, переведем делимое в тип numeric. */
WITH numbers AS (SELECT EXTRACT(MONTH FROM creation_date::date) AS nmonth, 
       COUNT (DISTINCT id) AS nposts
FROM stackoverflow.posts
WHERE DATE_TRUNC('month', creation_date)::date BETWEEN '2008-09-01' AND '2008-12-01'
GROUP BY nmonth)

SELECT *, 
     ROUND ((((nposts::numeric/LAG(nposts) OVER (ORDER BY nmonth))-1)*100), 2) AS total_posts
FROM numbers



    /*Выгрузим данные активности пользователя, который опубликовал больше всего постов за всё время. Выведем данные за октябрь 2008 года в таком виде:
    1.	номер недели;
    2.	дата и время последнего поста, опубликованного на этой неделе. */
WITH max_user AS (SELECT user_id, 
       COUNT (DISTINCT id) 
FROM stackoverflow.posts
GROUP BY user_id
ORDER BY count DESC
LIMIT 1)

SELECT DISTINCT week, 
       MAX(creation_date) OVER (PARTITION BY week)
FROM (SELECT p.user_id, p.creation_date, EXTRACT(WEEK FROM creation_date) AS week
FROM stackoverflow.posts AS p
JOIN max_user AS jm ON jm.user_id=p.user_id
WHERE DATE_TRUNC('month', creation_date)::date = '2008-10-01') AS jj 



