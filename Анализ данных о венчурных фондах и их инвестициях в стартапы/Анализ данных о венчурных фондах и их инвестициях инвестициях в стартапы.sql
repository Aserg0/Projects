/*Анализ данных о венчурных фондах и их инвестициях инвестициях в стартапы 
на основе базы данных https://www.kaggle.com/datasets/justinas/startup-investments в СУБД PostgreSQL и ER-диаграммы*/

     /* Посчитаем, сколько компаний закрылось. */
SELECT COUNT(STATUS)
FROM company
WHERE STATUS = 'closed'

     /* Отобразим количество привлечённых средств для новостных компаний США. Используем данные из таблицы company. 
	 Отсортируем таблицу по убыванию значений в поле funding_total. */
SELECT funding_total
FROM company
WHERE category_code = 'news'
     AND country_code = 'USA'
ORDER BY funding_total DESC

    /* Найдем общую сумму сделок по покупке одних компаний другими в долларах. Отберем сделки, которые осуществлялись только за наличные с 2011 по 2013 год включительно. */
SELECT SUM(price_amount)
FROM acquisition
WHERE EXTRACT(YEAR FROM CAST(acquired_at AS DATE)) in (2011, 2012, 2013)
      AND term_code = 'cash'

    /* Отобразим имя, фамилию и названия аккаунтов людей в поле network_username, у которых названия аккаунтов начинаются на 'Silver'. */
SELECT first_name, last_name, twitter_username
FROM people
WHERE twitter_username LIKE 'Silver%'

    /* Выведем на экран всю информацию о людях, у которых названия аккаунтов в поле network_username содержат подстроку 'money', а фамилия начинается на 'K'. */
SELECT *
FROM people
WHERE twitter_username LIKE '%money%'
      AND last_name LIKE 'K%'

    /* Для каждой страны отобразим общую сумму привлечённых инвестиций, которые получили компании, зарегистрированные в этой стране. Страну, в которой 
    зарегистрирована компания, определяем по коду страны. Отсортируем данные по убыванию суммы. */
SELECT country_code, SUM(funding_total)
FROM company
GROUP BY country_code
ORDER BY SUM(funding_total) DESC

    /* Составим таблицу, в которую войдёт дата проведения раунда, а также минимальное и максимальное значения суммы инвестиций, привлечённых в эту дату. 
    Оставим в итоговой таблице только те записи, в которых минимальное значение суммы инвестиций не равно нулю и не равно максимальному значению.*/
SELECT funded_at, MIN(raised_amount), MAX(raised_amount)  
FROM funding_round
GROUP BY funded_at
HAVING MIN(raised_amount) <> 0 
       AND MIN(raised_amount) <> MAX(raised_amount) 

    /* Создадим поле с категориями: 
    1.	Для фондов, которые инвестируют в 100 и более компаний, назначим категорию high_activity.
    2.	Для фондов, которые инвестируют в 20 и более компаний до 100, назначим  категорию middle_activity.
    3.	Если количество инвестируемых компаний фонда не достигает 20, назначим категорию low_activity.
    Отобразим все поля таблицы fund и новое поле с категориями. */
SELECT *,
       CASE
         WHEN  invested_companies>= 100 THEN 'high_activity'
         WHEN  invested_companies BETWEEN 20 AND 99 THEN 'middle_activity'
         WHEN  invested_companies < 20 THEN 'low_activity'
       END
FROM fund

    /* Для каждой из категорий, назначенных в предудущем блоке, посчитаем округлённое до ближайшего целого числа среднее количество инвестиционных раундов, 
    в которых фонд принимал участие. Выведем на экран категории и среднее число инвестиционных раундов. Отсортируем таблицу по возрастанию среднего. */
SELECT CASE
           WHEN invested_companies>=100 THEN 'high_activity'
           WHEN invested_companies>=20 THEN 'middle_activity'
           ELSE 'low_activity'
       END AS activity,
       ROUND(AVG(investment_rounds) ,0)
FROM fund
GROUP BY activity
ORDER BY ROUND(AVG(investment_rounds) ,0)

    /* Проанализируем, в каких странах находятся фонды, которые чаще всего инвестируют в стартапы. 
    Для каждой страны посчитаем минимальное, максимальное и среднее число компаний, в которые инвестировали фонды этой страны, основанные с 2010 по 2012 год включительно. 
    Исключим страны с фондами, у которых минимальное число компаний, получивших инвестиции, равно нулю. Выгрузим десять самых активных стран-инвесторов: отсортируем 
    таблицу по среднему количеству компаний от большего к меньшему. Затем добавим сортировку по коду страны в лексикографическом порядке. */
SELECT country_code, MIN(invested_companies), MAX(invested_companies), AVG(invested_companies)
FROM fund
WHERE EXTRACT(YEAR FROM CAST(founded_at AS DATE)) BETWEEN 2010 AND 2012
GROUP BY country_code
HAVING MIN(invested_companies) <> 0
ORDER BY AVG(invested_companies) DESC, country_code
LIMIT 10;

    /* Отобразим имя и фамилию всех сотрудников стартапов. Добавим поле с названием учебного заведения, которое окончил сотрудник, если эта информация известна. */
SELECT pe.first_name, pe.last_name, ed.instituition
FROM people as pe
LEFT OUTER JOIN education AS ed ON pe.id= ed.person_id

    /* Для каждой компании найдем количество учебных заведений, которые окончили её сотрудники. Выведем название компании и число уникальных названий учебных заведений. 
    Составим топ-5 компаний по количеству университетов. */
SELECT co.name, 
       COUNT(DISTINCT ed.instituition)
FROM company AS co
JOIN people AS pe ON co.id = pe.company_id
JOIN education AS ed ON pe.id = ed.person_id
GROUP BY co.name
ORDER BY COUNT(DISTINCT ed.instituition) DESC
LIMIT 5;

    /* Составим список с уникальными названиями закрытых компаний, для которых первый раунд финансирования оказался последним. */
SELECT DISTINCT co.name
FROM company AS co
LEFT OUTER JOIN funding_round AS fu ON co.id = fu.company_id
WHERE co.status = 'closed'
      AND fu.is_first_round = 1
      AND fu.is_last_round =  1
GROUP BY co.name;

    /* Составим список уникальных номеров сотрудников, которые работают в компаниях, отобранных в предыдущем блоке. */
SELECT DISTINCT pe.id
FROM people AS pe
WHERE pe.company_id in (SELECT DISTINCT co.id
                 FROM company AS co
                 LEFT OUTER JOIN funding_round AS fu ON co.id = fu.company_id
                 WHERE co.status = 'closed'
                 AND fu.is_first_round = 1
                 AND fu.is_last_round =  1
                 GROUP BY co.id);

    /* Составим таблицу, куда войдут уникальные пары с номерами сотрудников из предыдущего блока и учебным заведением, которое окончил сотрудник. */
SELECT pe.id,
       ed.instituition
FROM people AS pe
LEFT OUTER JOIN education AS ed ON pe.id = ed.person_id
WHERE pe.company_id in (SELECT DISTINCT co.id
                 FROM company AS co
                 LEFT OUTER JOIN funding_round AS fu ON co.id = fu.company_id
                 WHERE co.status = 'closed'
                 AND fu.is_first_round = 1
                 AND fu.is_last_round =  1
                 GROUP BY co.id)
GROUP BY pe.id, ed.instituition    
HAVING ed.instituition IS NOT NULL;

    /* Посчитаем количество учебных заведений для каждого сотрудника из предыдущего блока. При этом некоторые сотрудники могут окончить одно и то же заведение не один раз. */
SELECT pe.id,
       count(ed.instituition)
FROM people AS pe
LEFT OUTER JOIN education AS ed ON pe.id = ed.person_id
WHERE pe.company_id in (SELECT DISTINCT co.id
                 FROM company AS co
                 LEFT OUTER JOIN funding_round AS fu ON co.id = fu.company_id
                 WHERE co.status = 'closed'
                 AND fu.is_first_round = 1
                 AND fu.is_last_round =  1
                 GROUP BY co.id)
GROUP BY pe.id    
HAVING  count(ed.instituition)<>0;

    /* Выведем среднее число учебных заведений (не только уникальных), которые окончили сотрудники разных компаний. */
SELECT AVG(first.count)
FROM 
(SELECT pe.id,
       count(ed.instituition)
FROM people AS pe
LEFT OUTER JOIN education AS ed ON pe.id = ed.person_id
WHERE pe.company_id in (SELECT DISTINCT co.id
                 FROM company AS co
                 LEFT OUTER JOIN funding_round AS fu ON co.id = fu.company_id
                 WHERE co.status = 'closed'
                 AND fu.is_first_round = 1
                 AND fu.is_last_round =  1
                 GROUP BY co.id)
GROUP BY pe.id    
HAVING  count(ed.instituition)<>0) AS first

    /* Выведем среднее число учебных заведений (не только уникальных), которые окончили сотрудники Facebook.*/
SELECT AVG(first.count)
FROM 
(SELECT pe.id,
       count(ed.instituition)
FROM people AS pe
LEFT OUTER JOIN education AS ed ON pe.id = ed.person_id
WHERE pe.company_id in (SELECT DISTINCT co.id
                 FROM company AS co
                 LEFT OUTER JOIN funding_round AS fu ON co.id = fu.company_id
                 WHERE co.name = 'Facebook'
                 GROUP BY co.id)
GROUP BY pe.id    
HAVING  count(ed.instituition)<>0) AS first

    /* Составим таблицу из полей:
    1.	name_of_fund — название фонда;
    2.	name_of_company — название компании;
    3.	amount — сумма инвестиций, которую привлекла компания в раунде.
    В таблицу войдут данные о компаниях, в истории которых было больше шести важных этапов, а раунды финансирования проходили с 2012 по 2013 год включительно. */
SELECT fd.name AS name_of_fund, co.name AS name_of_company, fr.raised_amount AS amount
FROM investment AS inv
LEFT OUTER JOIN funding_round AS fr ON inv.funding_round_id = fr.id
LEFT OUTER JOIN company AS co ON fr.company_id = co.id
LEFT OUTER JOIN fund AS fd ON inv.fund_id = fd.id
WHERE EXTRACT(YEAR FROM CAST(fr.funded_at AS DATE)) BETWEEN 2012 AND 2013
      AND co.milestones > 6
GROUP BY fd.name, co.name, fr.raised_amount;


    /* Выгрузим таблицу, в которой будут такие поля: 
    1.	название компании-покупателя;
    2.	сумма сделки;
    3.	название компании, которую купили;
    4.	сумма инвестиций, вложенных в купленную компанию;
    5.	доля, которая отображает, во сколько раз сумма покупки превысила сумму вложенных в компанию инвестиций, округлённая до ближайшего целого числа.
    Не берем те сделки, в которых сумма покупки равна нулю. Если сумма инвестиций в компанию равна нулю, исключим такую компанию из таблицы. Отсортируем 
	таблицу по сумме сделки от большей к меньшей, а затем по названию купленной компании в лексикографическом порядке. Выведем таблицу первыми десятью записями. */
WITH
t1 AS (SELECT co.name AS name1, aqi.price_amount AS price, aqi.id AS id
         FROM acquisition AS aqi
         LEFT OUTER JOIN company AS co ON aqi.acquiring_company_id = co.id
         WHERE aqi.price_amount > 0),
t2 AS (SELECT co.name AS name2, co.funding_total AS fund, aqi.id AS id
      FROM acquisition AS aqi
      LEFT OUTER JOIN company AS co ON aqi.acquired_company_id = co.id
      WHERE co.funding_total > 0)
      
SELECT name1, price, name2, fund, ROUND(price / fund, 0) AS calc
FROM t1
INNER JOIN t2 ON t1.id = t2.id
ORDER BY price DESC, name2
LIMIT 10;

    /* Выгрузим таблицу, в которую войдут названия компаний из категории social, получившие финансирование с 2010 по 2013 год включительно. При этом 
	сумма инвестиций не должна быть равна нулю. Выведем также номер месяца, в котором проходил раунд финансирования. */
SElECT co.name, EXTRACT(MONTH FROM CAST(fr.funded_at AS DATE))
FROM company AS co
LEFT OUTER join funding_round AS fr ON co.id = fr.company_id
WHERE fr.raised_amount > 0
     AND co.category_code = 'social'
     AND EXTRACT(YEAR FROM CAST(fr.funded_at AS DATE)) BETWEEN 2010 AND 2013;

    /* Отберем данные по месяцам с 2010 по 2013 год, когда проходили инвестиционные раунды. Сгруппируем данные по номеру месяца и получим таблицу, в которой будут поля:
    1.	номер месяца, в котором проходили раунды;
    2.	количество уникальных названий фондов из США, которые инвестировали в этом месяце;
    3.	количество компаний, купленных за этот месяц;
    4.	общая сумма сделок по покупкам в этом месяце. */
WITH 
t1 AS (Select EXTRACT(MONTH FROM CAST(fr.funded_at AS DATE)) AS month_number,
            count(DISTINCT inv.fund_id) AS number_of_USA_funds
FROM funding_round AS fr 
LEFT OUTER JOIN investment AS inv ON fr.id = inv.funding_round_id
LEFT OUTER JOIN fund AS fd ON inv.fund_id = fd.id
WHERE EXTRACT(YEAR FROM CAST(fr.funded_at AS DATE)) BETWEEN 2010 AND 2013
      AND fd.country_code = 'USA'
GROUP BY month_number),
t2 AS (Select EXTRACT(MONTH FROM CAST(aq.acquired_at AS DATE)) AS month_number,
            COUNT(aq.acquired_company_id) AS number_of_co,
            SUM(aq.price_amount) AS total_purchases
FROM acquisition AS aq 
LEFT OUTER JOIN company AS co ON aq.acquired_company_id = co.id
WHERE EXTRACT(YEAR FROM CAST(aq.acquired_at AS DATE)) BETWEEN 2010 AND 2013
GROUP BY month_number)

SELECT t1.month_number, t1.number_of_usa_funds, t2.number_of_co, t2.total_purchases
FROM t1
LEFT OUTER JOIN t2 ON t1.month_number = t2.month_number

    /* Составим сводную таблицу и выведем среднюю сумму инвестиций для стран, в которых есть стартапы, зарегистрированные в 2011, 2012 и 2013 годах. 
    Данные за каждый год в отдельном поле. Отсортируем таблицу по среднему значению инвестиций за 2011 год от большего к меньшему. */
WITH
t1 AS (Select DISTINCT country_code AS ccode
From company
Where EXTRACT(YEAR FROM CAST(founded_at AS DATE)) BETWEEN 2011 AND 2013
GROUP BY country_code),

t2011 AS (Select DISTINCT country_code,  AVG(funding_total) AS avg2011
From company
Where EXTRACT(YEAR FROM CAST(founded_at AS DATE)) = 2011 
GROUP BY country_code), 

t2012 AS (Select DISTINCT country_code,  AVG(funding_total) AS avg2012
From company
Where EXTRACT(YEAR FROM CAST(founded_at AS DATE)) = 2012 
GROUP BY country_code), 

t2013 AS (Select DISTINCT country_code,  AVG(funding_total) AS avg2013
From company
Where EXTRACT(YEAR FROM CAST(founded_at AS DATE)) = 2013 
GROUP BY country_code)

SELECT t1.ccode, t2011.avg2011, t2012.avg2012, t2013.avg2013
FROM t1 
INNER JOIN t2011 ON t1.ccode = t2011.country_code
INNER JOIN t2012 ON t1.ccode = t2012.country_code
INNER JOIN t2013 ON t1.ccode = t2013.country_code
ORDER BY t2011.avg2011 DESC;
