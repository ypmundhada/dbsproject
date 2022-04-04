CREATE DEFINER=`root`@`localhost` PROCEDURE `booking`(
	cust_id INT,
    loc_id INT,
    carid INT,
    pickupDt DATETIME,
    dropDt DATETIME,
    rental_cost DECIMAL(9,2),
    payment_amount DECIMAL(9,2),
    trxnid INT
)
BEGIN
	DECLARE zeroornot INTEGER;
    DECLARE rent_id INTEGER;
    select exists(select 1 from rent) into zeroornot;
    IF zeroornot = 0 THEN
		INSERT INTO rent
        VALUES(10000,cust_id,loc_id,carid,pickupDt,dropDt);
        SET @rent_id = 10000;
	ELSE
		INSERT INTO rent(customer_id,location_id,car_id,pickupDate,dropDate)
        VALUES(cust_id,loc_id,carid,pickupDt,dropDt);
        SELECT last_insert_id() INTO rent_id;
	END IF;
    if trxnid is null then
		INSERT INTO waitList
        VALUES(rent_id,"No");
        INSERT INTO rentDetails(rent_id,statusid,total_rental_cost,total_payment)
        VALUES(rent_id,3,rental_cost,payment_amount);
	else
		INSERT INTO rentDetails
		VALUES(rent_id,4,rental_cost,payment_amount,trxnid);
    end if;
END


CREATE DEFINER=`root`@`localhost` PROCEDURE `display_car_details`(
	car_ID INT
)
BEGIN
	SELECT car_ID,c.name,fuel_type,ct.name as carType,transmission,base_price,seats
    FROM car c
    JOIN cartype ct ON(c.carType = ct.carTypeId)
    WHERE c.car_ID = car_ID;
END



CREATE DEFINER=`root`@`localhost` PROCEDURE `putCustomer`(
	f_name VARCHAR(50),
    l_name VARCHAR(50),
    emailId VARCHAR(255),
    city_p VARCHAR(45),
    mobile INTEGER
)
BEGIN
	INSERT INTO customer (first_name,last_name,email,city,mobileNo)
	SELECT * FROM (SELECT f_name,l_name,emailId,city_p,mobile) AS temp
	WHERE NOT EXISTS (
		SELECT email,mobileNo 
        FROM customer 
        WHERE email = emailId OR mobile = mobileNo
	) LIMIT 1;
END



CREATE DEFINER=`root`@`localhost` PROCEDURE `rental_cost`(
	carID INTEGER,
    pickupDt datetime,
    dropDt datetime,
    OUT weekdays_charges DECIMAL(9,2),
    OUT weekends_charges DECIMAL(9,2),
    OUT cost DECIMAL (9,2)
)
BEGIN
    DECLARE total_num_of_days INTEGER;
    DECLARE num_of_weekdays INTEGER;
    DECLARE num_of_weekends INTEGER;
    DECLARE base_p DECIMAL(6,2);
    DECLARE temp INTEGER;
    DECLARE tempdt DATETIME;
    DECLARE midnight INTEGER;
    SET midnight = 24;
    SET num_of_weekends = 0;
    SET num_of_weekdays = 0;
    SET tempdt = pickupDt;
    SELECT base_price INTO base_p
    FROM car WHERE car_ID = carID;
    SET total_num_of_days = DATEDIFF(dropDt,pickupDt);
    if total_num_of_days=0 THEN 
		if EXTRACT(day from pickupDt)=EXTRACT(day from dropDt) THEN
			SET temp = DAYOFWEEK(pickupDt); 
			IF temp = 1 OR temp=7 
				THEN SET num_of_weekends = num_of_weekends + 1;
			ELSE SET num_of_weekdays = num_of_weekdays+1;
			END IF;
		else 
			if midnight-EXTRACT(HOUR FROM pickupDt)>EXTRACT(HOUR FROM dropDt) THEN
				SET temp = DAYOFWEEK(pickupDt); 
				IF temp = 1 OR temp=7 
					THEN SET num_of_weekends = num_of_weekends + 1;
				ELSE SET num_of_weekdays = num_of_weekdays+1;
				END IF;
			else
				SET temp = DAYOFWEEK(dropDt); 
				IF temp = 1 OR temp=7 
					THEN SET num_of_weekends = num_of_weekends + 1;
				ELSE SET num_of_weekdays = num_of_weekdays+1;
				END IF;
			end if;
		end if;
	else
		calc_weekdays: LOOP
			SET temp = DAYOFWEEK(tempdt); 
			IF temp = 1 OR temp=7 
				THEN SET num_of_weekends = num_of_weekends + 1;
			ELSE SET num_of_weekdays = num_of_weekdays+1;
			END IF;
			SET tempdt = DATE_ADD(tempdt, INTERVAL 1 DAY);
			SET total_num_of_days = total_num_of_days-1;
			IF total_num_of_days = 0
				THEN LEAVE calc_weekdays;
			END IF;
		END LOOP calc_weekdays;
	end if;
    SET weekdays_charges = num_of_weekdays*base_p;
    SET weekends_charges = num_of_weekends*base_p*1.5;
    SET cost = weekdays_charges+weekends_charges;
END


CREATE DEFINER=`root`@`localhost` PROCEDURE `search_car`(
	car_type VARCHAR(45),
    fuel_type VARCHAR(45),
    transmission VARCHAR(45),
    seats TINYINT,
    location VARCHAR(45)
)
BEGIN
	DECLARE locId INTEGER;
    SELECT location_id INTO locId 
    FROM location WHERE location_name = location;
	IF car_type IS NOT NULL THEN
    SELECT *
    FROM caravl
    WHERE car_ID IN (
		SELECT car_ID
        FROM car c
        JOIN cartype ct ON (c.carType = ct.carTypeId)
        WHERE ct.name = car_type AND
        c.fuel_type = IFNULL(fuel_type,c.fuel_type) AND
		c.transmission = IFNULL(transmission,c.transmission) AND
		c.seats = IFNULL(seats,c.seats)
       ) AND location_id=locId;
	ELSE
    SELECT *
    FROM caravl
    WHERE car_ID IN (
		SELECT car_ID
		FROM car c
		WHERE c.fuel_type = IFNULL(fuel_type,c.fuel_type) AND
		c.transmission = IFNULL(transmission,c.transmission) AND
		c.seats = IFNULL(seats,c.seats)
        ) AND location_id=locId;
	END IF;
END


CREATE DEFINER=`root`@`localhost` FUNCTION `car_available_at_location`(
	locationid INTEGER,
    carid INTEGER
) RETURNS int
    READS SQL DATA
BEGIN
	DECLARE num_of_cars_curAvl INTEGER;
	SELECT currentAvl INTO num_of_cars_curAvl
    FROM caravl ca
    WHERE ca.location_id = locationid AND
		ca.car_id = carid;
	RETURN num_of_cars_curAvl;
END