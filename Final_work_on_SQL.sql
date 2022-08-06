-- Final work on SQL

-- ¹ 1: Which cities have more than one airport?

select 
a.city as title_city, 
count(a.airport_name) as count_airport
from airports a 
group by a.city
having count(a.airport_name) > 1

-- Answer: More than one airport in the cities of Moscow and Ulyanovsk

-- ¹ 2: Which airports have longest range flights?

select
a.airport_name
from airports a 
inner join flights f on f.departure_airport = a.airport_code 
inner join aircrafts air on air.aircraft_code = f.aircraft_code 
where "range" = (select max(a2."range" ) from aircrafts a2)
group by a.airport_name

-- Answer: there are flights at Vnukovo, Perm, Tolmachevo, Sheremetyevo, Koltsovo, Sochi and Domodedovo airports,
-- performed by aircraft with the maximum flight range.

-- ¹ 3: Display 10 flights with maximum departure delay time

select 
f.flight_no,
f.actual_departure,
f.scheduled_departure,
f.actual_departure - f.scheduled_departure as delay 
from flights f 
where actual_departure is not null
order by delay desc
limit 10

--  ¹ 4: Were there any bookings for which boarding passes were not received?

select
count(bookings.book_ref)
from bookings
full outer join tickets using(book_ref)
full outer join boarding_passes using(ticket_no)
where boarding_passes.boarding_no is null

-- Answer: 127,899 bookings without boarding passes.

-- # 5: Find the empty seats for each flight as a percentage of the total number of seats on the plane.
-- Add a column with a cumulative total - the total accumulation of the number of exported
-- passengers from each airport for every day.
-- Ie. this column should reflect the cumulative amount - how many people have already departed
-- from this airport on this or earlier flights of the day.

select f.flight_id, 
	f.departure_airport, 
	date(f.actual_departure) as date_departure,
	(s.count_seats - bord_pass.count_bp) as free_places,
	round((cast(bord_pass.count_bp as numeric) * 100 / s.count_seats), 2) as "% free places",
	bord_pass.count_bp as departing_passengers,
	sum(bord_pass.count_bp) over (partition by date(f.actual_departure), f.departure_airport order by f.actual_departure) as total	
from flights f
left join (
	select bord_pass.flight_id, count(bord_pass.seat_no) as count_bp
	from boarding_passes bord_pass
	group by bord_pass.flight_id
	order by bord_pass.flight_id) as bord_pass on bord_pass.flight_id = f.flight_id 
left join (
	select s.aircraft_code, count(*) as count_seats
	from seats s 
	group by s.aircraft_code) as s on f.aircraft_code = s.aircraft_code
where f.actual_departure is not null and bord_pass.count_bp is not null
order by date(f.actual_departure)

-- ¹ 6: Find the percentage of the total number of flights by aircraft type.

select 
model as title_plane,
count(flight_id)
from flights f
inner join aircrafts air using(aircraft_code)
group by model;

select count(flight_id) from flights f;

select 
model as title_plane,
round(count(f.flight_id)::numeric/(select count(flight_id)::numeric from flights)*100, 2) as percent_flight
from flights f
inner join aircrafts air using(aircraft_code)
group by model;

-- ¹ 7: Were there any cities where you can get business class cheaper than economy class as part of the flight?
select * from ticket_flights tf 

with econom_class as
	(select tf.flight_id, a.city as departure_city, aa.city as arrival_city, max(amount) as max
	from ticket_flights tf
	inner join flights f using(flight_id)
    inner join airports a on f.departure_airport=a.airport_code
    inner join airports aa on f.arrival_airport=aa.airport_code
	where fare_conditions = 'Economy'
	group by tf.flight_id, a.city, aa.city),
business_class as
	(select tf.flight_id, a.city as departure_city, aa.city as arrival_city, min(amount) as min
	from ticket_flights tf
	inner join flights f using(flight_id)
    inner join airports a on f.departure_airport=a.airport_code
    inner join airports aa on f.arrival_airport=aa.airport_code
	where fare_conditions = 'Business' group by tf.flight_id, a.city, aa.city)
select eco.flight_id, eco.departure_city, eco.arrival_city, min, max
from econom_class eco
join business_class bus on eco.flight_id = bus.flight_id
where max > min;

-- Answer: There are no such cities.

-- ¹ 8 There are no direct flights between which cities?

create view route as 
	select distinct a.city as departure_city , b.city as arrival_city, a.city||'-'||b.city as route 
	from airports as a, (select city from airports) as b
	where a.city != b.city
	order by route
	
create view direct_flight as 
	select distinct a.city as departure_city, aa.city as arrival_city, a.city||'-'|| aa.city as route  
	from flights as f
	inner join airports as a on f.departure_airport=a.airport_code
	inner join airports as aa on f.arrival_airport=aa.airport_code
	order by route
	
select r.* 
from route as r
except 
select df.* 
from direct_flight as df

-- ¹ 9 Calculate the distance between airports,
-- connected direct flights, compare with the permissible maximum range of flights in airplanes,
-- serving these flights

select distinct air1.airport_name , air2.airport_name, a.model,
round(acos(sind(air1.latitude)*sind(air2.latitude) + cosd(air1.latitude)*cosd(air2.latitude)*cosd(air1.longitude - air2.longitude))::numeric*6371) as distance,
a.range
from flights f
left join airports  air1 on f.departure_airport = air1.airport_code 
left join airports air2 on f.arrival_airport = air2.airport_code
left join aircrafts a using (aircraft_code);