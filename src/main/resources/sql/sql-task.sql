-- 1. Вывести к каждому самолету класс обслуживания и количество мест этого класса
SELECT ad.model->>'ru' AS model, ad.aircraft_code, s.fare_conditions, count(fare_conditions ) AS quantity
FROM aircrafts_data ad
JOIN seats s
ON ad.aircraft_code = s.aircraft_code
GROUP BY ad.model, ad.aircraft_code, s.fare_conditions
ORDER BY ad.model;

-- 2. Найти 3 самых вместительных самолета (модель + кол-во мест)
SELECT ad.model->>'ru' AS model, count(seat_no) AS seat_quantity
FROM aircrafts_data ad
JOIN seats s
ON ad.aircraft_code = s.aircraft_code
GROUP BY ad.model
ORDER BY count(seat_no) DESC
LIMIT 3;

-- 3. Найти все рейсы, которые задерживались более 2 часов
SELECT * FROM flights f
WHERE (actual_arrival - scheduled_arrival) > INTERVAL '2 hours'
AND f.status = 'Arrived';

-- 4. Найти последние 10 билетов, купленные в бизнес-классе (fare_conditions = 'Business'),
-- с указанием имени пассажира и контактных данных
SELECT t.passenger_name, t.contact_data
FROM tickets t
JOIN ticket_flights tf ON t.ticket_no = tf.ticket_no
JOIN bookings b ON t.book_ref = b.book_ref
WHERE tf.fare_conditions = 'Business'
ORDER BY b.book_date DESC
LIMIT 10;

-- 5. Найти все рейсы, у которых нет забронированных мест в бизнес-классе (fare_conditions = 'Business')
SELECT
    f.flight_id,
    f.flight_no
FROM
    flights f
WHERE
    EXISTS ( -- рейсы, на которые есть места в бизнес-класс в принципе
        SELECT 1
        FROM
            seats s
        WHERE
            s.aircraft_code = f.aircraft_code AND
            s.fare_conditions = 'Business'
    ) AND NOT EXISTS ( -- и нет забронированных мест в бизнес-класс
        SELECT 1
        FROM
            ticket_flights tf
        JOIN
            boarding_passes bp ON tf.ticket_no = bp.ticket_no AND tf.flight_id = bp.flight_id
        JOIN
            seats s ON bp.seat_no = s.seat_no AND f.aircraft_code = s.aircraft_code
        WHERE
            tf.flight_id = f.flight_id AND
            s.fare_conditions = 'Business'
    );

-- 6. Получить список аэропортов (airport_name) и городов (city), в которых есть рейсы с задержкой
SELECT
    ad.airport_name->>'ru' AS airport_name,
    ad.city->>'ru' AS city
FROM airports_data ad
WHERE
    EXISTS (
        SELECT 1 FROM flights f
        WHERE
            (f.departure_airport = ad.airport_code OR f.arrival_airport = ad.airport_code) AND
            (f.actual_departure > f.scheduled_departure OR f.actual_arrival > f.scheduled_arrival)
    );

-- 7. Получить список аэропортов (airport_name) и количество рейсов,
--вылетающих из каждого аэропорта, отсортированный по убыванию количества рейсов
SELECT
    ad.airport_name->>'ru' AS airport_name,
    COUNT(f.flight_id) AS flight_count
FROM airports_data ad
JOIN flights f ON ad.airport_code = f.departure_airport
GROUP BY ad.airport_name
ORDER BY flight_count DESC;

--8. Найти все рейсы, у которых запланированное время прибытия (scheduled_arrival)
--было изменено и новое время прибытия (actual_arrival) не совпадает с запланированным
SELECT * FROM flights f
WHERE
    f.actual_arrival IS NOT NULL AND
    f.actual_arrival != f.scheduled_arrival;

--9. Вывести код,модель самолета и места не эконом класса для самолета 'Аэробус A321-200' с сортировкой по местам
SELECT ad.aircraft_code, ad.model->>'ru' AS model , s.seat_no, s.fare_conditions
FROM aircrafts_data ad
JOIN seats s
ON ad.aircraft_code = s.aircraft_code
WHERE ad.model @> '{"ru":"Аэробус A321-200"}'
AND s.fare_conditions NOT LIKE 'Economy'
ORDER BY s.seat_no;

--10. Вывести города в которых больше 1 аэропорта ( код аэропорта, аэропорт, город)
SELECT ad.airport_code, ad.airport_name->'ru' AS airport_name, ad.city->>'ru' AS city
FROM airports_data ad
WHERE ad.city IN (
	SELECT ad.city
	FROM airports_data ad
	GROUP BY ad.city
	HAVING count(ad.city) > 1);

-- 11. Найти пассажиров, у которых суммарная стоимость бронирований превышает среднюю сумму всех бронирований
WITH avg_cost AS (
    SELECT AVG(total_amount) AS average_cost
    FROM bookings
)
SELECT
    t.passenger_id,
    t.passenger_name,
    SUM(b.total_amount) AS total_booking_cost
FROM
    tickets t
JOIN
    bookings b ON t.book_ref = b.book_ref
GROUP BY
    t.passenger_id,
    t.passenger_name
HAVING
    SUM(b.total_amount) > (SELECT average_cost FROM avg_cost);

-- 12. Найти ближайший вылетающий рейс из Екатеринбурга в Москву, на который еще не завершилась регистрация
SELECT
	f.flight_id,
	f.flight_no,
	f.scheduled_departure,
	f.scheduled_arrival,
	f.departure_airport,
	f.arrival_airport,
	f.status,
	f.aircraft_code,
	f.actual_departure,
	f.actual_arrival
FROM
	flights f
WHERE
	f.departure_airport IN (
		SELECT ad.airport_code
		FROM airports_data ad
		WHERE ad.city @> '{"ru":"Екатеринбург"}'
	)
	AND f.arrival_airport IN (
		SELECT ad.airport_code
		FROM airports_data ad
		WHERE ad.city @> '{"ru":"Москва"}'
	)
	AND (f.status LIKE 'Scheduled' OR f.status LIKE 'On Time' OR f.status LIKE 'Delayed')
ORDER BY
	f.scheduled_departure
LIMIT 1;

-- 13. Вывести самый дешевый и дорогой билет и стоимость (в одном результирующем ответе)
SELECT ticket_no, flight_id, fare_conditions, amount, note
	FROM
		(
		SELECT tf.ticket_no, tf.flight_id, tf.fare_conditions, tf.amount, 'min price' AS note
		FROM ticket_flights tf
		ORDER BY tf.amount
		LIMIT 1
		) AS cheapest
UNION
SELECT ticket_no, flight_id, fare_conditions, amount, note
	FROM
		(
		SELECT tf.ticket_no, tf.flight_id, tf.fare_conditions, tf.amount, 'max price' AS note
		FROM ticket_flights tf
		ORDER BY tf.amount DESC
		LIMIT 1
		) AS "most expensive";

-- 14. Написать DDL таблицы Customers, должны быть поля id , firstName, LastName, email, phone.
-- Добавить ограничения на поля (constraints).
CREATE TABLE IF NOT EXISTS customers (
	customer_id BIGSERIAL PRIMARY KEY,
	first_name VARCHAR (30),
	last_name VARCHAR (30),
	email VARCHAR (40) UNIQUE NOT NULL,
	phone CHAR (9)
);

ALTER TABLE customers
	ADD CONSTRAINT email_regex
		CHECK (email ~* '^[A-Za-z0-9._+%-]+@[A-Za-z0-9.-]+[.][A-Za-z]+$'),
	ADD CONSTRAINT phone_unq UNIQUE (phone);

-- 15. Написать DDL таблицы Orders, должен быть id, customerId, quantity.
-- Должен быть внешний ключ на таблицу customers + ограничения
CREATE TABLE IF NOT EXISTS orders (
	order_id BIGSERIAL PRIMARY KEY,
	customer_id BIGINT NOT NULL REFERENCES customers,
	quantity SMALLINT,
	CONSTRAINT quantity CHECK (quantity > 0));

-- 16. Написать 5 insert в эти таблицы
INSERT INTO customers (first_name, last_name, email, phone)
VALUES
	('Nick', 'Johnson', 'nick@gmail.com', '291234567'),
	('Mike', 'November', 'mike@gmail.com', '331234567'),
	('Ivan', 'Ivanov', 'ivan@gmail.com', '152134567'),
	('Peter', 'Ferdinand', 'peter@gmail.com', '441234567'),
	('Alex', 'Gor', 'gor@gmail.com', '171234567');

INSERT INTO orders (customer_id, quantity)
VALUES
	((SELECT c.customer_id FROM customers c WHERE c.email = 'nick@gmail.com'), 2),
	((SELECT c.customer_id FROM customers c WHERE c.email = 'mike@gmail.com'), 1),
	((SELECT c.customer_id FROM customers c WHERE c.email = 'ivan@gmail.com'), 5),
	((SELECT c.customer_id FROM customers c WHERE c.email = 'peter@gmail.com'), 2),
	((SELECT c.customer_id FROM customers c WHERE c.email = 'gor@gmail.com'), 12);

-- 17. Удалить таблицы
DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS customers;