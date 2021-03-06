/*1:
Þróið nýja útgáfu af bókunarferlinu, þannig að hægt sé að bóka í flug til ákveðins staðar, bæði fram og til baka.
Gera skal ráð fyrir að allir sem bókaðir eru á einhvern áfangastað komi til baka með.*/

-- start by working on a copy of the procedure from project 2—assuming that is what he means by "bókunarferli" --
DELIMITER $$
DROP PROCEDURE IF EXISTS BookBothFlights $$
CREATE PROCEDURE BookBothFlights(flight_code       INT(11), flight_date DATETIME, return_code INT(11),
                                 card_issued_by    VARCHAR(35),
                                 card_holders_name VARCHAR(55),
                                 passengers_array  TEXT) -- added return variable to specify the flight they wish to take back
    this_proc: BEGIN
    DECLARE outerPosition INT;
    DECLARE innerPosition INT;
    DECLARE workingArray TEXT;
    DECLARE currentPassanger VARCHAR(255);

    DECLARE booking_number INT(11);
    DECLARE price_id INT(11);
    DECLARE seat_id INT(11);
    DECLARE person_id VARCHAR(35);
    DECLARE person_name VARCHAR(75);

    -- declare orig/dest variables for both trips to check if they match—may be unnecessary
    DECLARE departure_orig CHAR(3);
    DECLARE departure_dest CHAR(3);
    DECLARE return_orig CHAR(3);
    DECLARE return_dest CHAR(3);

    -- declare bool for loop
    DECLARE exit_loop BOOL;
    SET exit_loop = FALSE;

    -- departure --
    SELECT originatingAirport
    INTO departure_orig
    FROM flightschedules
      JOIN flights ON flightschedules.flightNumber = flights.flightNumber
    WHERE flightCode = flight_code;

    SELECT destinationAirport
    INTO departure_dest
    FROM flightschedules
      JOIN flights ON flightschedules.flightNumber = flights.flightNumber
    WHERE flightCode = flight_code;

    -- return --
    SELECT originatingAirport
    INTO return_orig
    FROM flightschedules
      JOIN flights ON flightschedules.flightNumber = flights.flightNumber
    WHERE flightCode = return_code;

    SELECT destinationAirport
    INTO return_dest
    FROM flightschedules
      JOIN flights ON flightschedules.flightNumber = flights.flightNumber
    WHERE flightCode = return_code;

    -- checks whether the origins and destinations match up, if they do not, leave the procedure
    IF (departure_orig = return_dest AND return_orig = departure_dest) IS NOT TRUE
    THEN LEAVE this_proc;
    END IF;

    SET workingArray = passengers_array;
    SET outerPosition = 1;
    SET innerPosition = 1;

    -- books the paying costumer into the flight
    INSERT INTO bookings (flightCode, timeOfBooking, cardIssuedBy, cardholdersName)
    VALUES (flight_code, flight_date, card_issued_by, card_holders_name);

    -- books the return flight
    INSERT INTO bookings (flightCode, timeOfBooking, cardIssuedBy, cardholdersName)
    VALUES (return_code, flight_date, card_issued_by, card_holders_name);

    -- loops the fake array twice, but changes the flight_code for the second iteration, making the booking_number change as
    -- well, adding the passengers to the return flight as well
    WHILE exit_loop IS FALSE DO

      -- selects the bookingNumber into a variable to avoid repetitition—which would slow the procedure down
      SELECT bookingNumber
      FROM bookings
      WHERE flightCode = flight_code AND timeOfBooking = flight_date AND cardIssuedBy = card_issued_by AND
            cardholdersName = card_holders_name
      INTO booking_number;

      WHILE char_length(workingarray) > 0 AND outerposition > 0 DO
        SET outerposition = instr(workingarray, '|');
        IF outerposition = 0
        THEN
          SET currentpassanger = workingarray;
        ELSE
          SET currentpassanger = left(workingarray, outerposition - 1);
        END IF;

        IF trim(workingarray) != ''
        THEN
          SET innerposition = instr(currentpassanger, ',');
          SET person_name = left(currentpassanger, innerposition - 1);
          SET currentpassanger = substring(currentpassanger, innerposition + 1);

          SET innerposition = instr(currentpassanger, ',');
          SET person_id = left(currentpassanger, innerposition - 1);
          SET currentpassanger = substring(currentpassanger, innerposition + 1);

          SET innerposition = instr(currentpassanger, ',');
          SET seat_id = left(currentpassanger, innerposition - 1);
          SET currentpassanger = substring(currentpassanger, innerposition + 1);

          SET price_id = currentpassanger;

          INSERT INTO passengers (personname, personid, seatid, priceid, bookingnumber)
          VALUES (person_name, person_id, seat_id, price_id, booking_number);
        END IF;

        SET workingarray = substring(workingarray, outerposition + 1);
      END WHILE;

      -- checks whether to leave the loop or change the flight code
      IF (flight_code != return_code)
      THEN SET flight_code = return_code;
      ELSE SET exit_loop = TRUE;
      END IF;

    END WHILE;
  END $$
DELIMITER ;

/*2:
Þegar gerð hefur verið flugáætlun(FlightSchedule) þá þarf að huga að nákvæmari útfærslum.
Flugáætlun er skráð á einhverja ákveðna vikudaga og það þýðir að setja verður ýmsar aðrar upplýsingar
til að hægt sé að fljúga eftir henni.

Skrifið Stored Procedure sem "gengur frá" flugi á ákveðin áfangastað. 
Atuga þarf með:
 Flugnúmer,
 Flugdag,
 Flugvél,
 Áætlaðan flugtíma.

Passa þarf uppá að flug sé ekki sett á vitlausan vikudag og að komutími sé ekki á undan brottfarartíma.(allir tímar eru UTC/Monrovia).  
Þetta merkir að sé flugáætlun sett á miðvikudaga þá þarf að kanna hvort sá flugdagur sem verið er að skrá sé á miðvikudegi.*/

-- strange that the assignment description says to make SP, when it should be trigger? --
-- start by working on the trigger from the first project --

-- TODO: somehow make certain the flight cannot land before it takes off
-- there does not seem to be any scheduled landing time, other than what you'd infer from the 
-- ETA, so how could you possibly schedule it to land before it takes off?
DELIMITER $$
DROP TRIGGER IF EXISTS before_flight_insert $$
CREATE TRIGGER before_flight_insert
BEFORE INSERT ON flights
FOR EACH ROW
  BEGIN
    DECLARE msg VARCHAR(255);
    DECLARE week_day INT(11);

    SELECT weekday
    INTO week_day
    FROM ScheduleWeekdays
    WHERE flightNumber = new.flightNumber;

    -- apparently mysql decided that sunday is the first day of the week, making monday = 2
    -- adjusting with the if block to compensate
    IF week_day = 7
    THEN
      SET week_day = 1;
    ELSE
      SET week_day = week_day + 1;
    END IF;

    IF (new.flightDate < NOW())
    THEN
      SET msg = concat('Cannot register flight with past date ', cast(new.flightDate AS CHAR));
      SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = msg;
    END IF;

    IF (DAYOFWEEK(new.flightDate) != week_day) -- compares the date entered with the scheduled day
    THEN
      SET msg = concat('Cannot register flight with incorrect weekday ', cast(new.flightDate AS CHAR));
      SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = msg;
    END IF;
  END $$
DELIMITER ;

INSERT INTO flights (flightDate, flightNumber, aircraftID, flightTime) VALUES ('2016-08-16', 'FA803', 'TF-LUR', '8:00');
INSERT INTO flights (flightDate, flightNumber, aircraftID, flightTime) VALUES ('2016-08-17', 'FA804', 'TF-LUR', '7:30');


/*3:
Í núverandi kerfi FreshAir er hægt að finna öll sætispör(tvö sæti hlið við hlið)sem eru laus í ákveðnu flugi.
Séu sæti sitt hvoru megin við gang er það túlkað sem "hlið við hlið".
Gerið breytingar á þessu þannig að hægt sé að velja hvort túlka eigi málið á þennan hátt eða engöngu sæti
sem virkilega eru hlið við hlið.*/

-- start by working on a copy of the procedure from project 2 --
DELIMITER $$
DROP PROCEDURE IF EXISTS TwoSideBySide $$
CREATE PROCEDURE TwoSideBySide(flight_number CHAR(5), flight_date DATE,
                               query_mode    TINYINT) -- added variable to determine mode; 0 for default, 1 for new functionality
  BEGIN

    -- variables holding the seats being investigated
    DECLARE first_seat INT;
    DECLARE first_seat_row TINYINT;
    DECLARE first_seat_place VARCHAR(15);
    DECLARE second_seat INT;
    DECLARE second_seat_row TINYINT;
    DECLARE second_seat_place VARCHAR(15);

    -- loop control variable
    DECLARE done INT DEFAULT FALSE;

    -- The cursor itself is declared containing the query code
    DECLARE vacantSeatsCursor CURSOR FOR
      SELECT seatID
      FROM AircraftSeats
      WHERE seatID NOT IN (SELECT AircraftSeats.seatid
                           FROM AircraftSeats
                             INNER JOIN Passengers ON AircraftSeats.seatID = Passengers.seatID
                             INNER JOIN Bookings ON Passengers.bookingNumber = Bookings.bookingNumber
                                                    AND Bookings.flightCode = FlightCode(flight_number, flight_date))
            AND aircraftID = Carrier(flight_number, flight_date)
      ORDER BY seatID;

    -- when the cursor reaches the end of it's data, the done variable is set to true
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;

    -- start by checking if mode is set to, 0 or 1, default to 0 if unclear
    IF query_mode != (0 OR 1)
    THEN SET query_mode = 0;
    END IF;

    SET first_seat = NULL;
    SET second_seat = NULL;

    OPEN vacantSeatsCursor;

    read_loop: LOOP
      IF first_seat IS NULL
      THEN
        FETCH vacantSeatsCursor
        INTO first_seat;
      ELSEIF second_seat IS NULL
        THEN
          FETCH vacantSeatsCursor
          INTO second_seat;

          -- adding the select statements into variables makes the code more concise and readable
          -- first seat --
          SELECT rowNumber
          INTO first_seat_row
          FROM aircraftseats
          WHERE seatID = first_seat;

          SELECT seatPlacement
          INTO first_seat_place
          FROM aircraftseats
          WHERE seatID = first_seat;

          -- second seat --
          SELECT rowNumber
          INTO second_seat_row
          FROM aircraftseats
          WHERE seatID = second_seat;

          SELECT seatPlacement
          INTO second_seat_place
          FROM aircraftseats
          WHERE seatID = second_seat;

          IF (first_seat + 1 = second_seat AND first_seat_row =
                                               second_seat_row) -- checks for side by side seats first, since it would have to do so regardless of query mode
          THEN
            IF (query_mode = 0)
            THEN SET done = TRUE;
            ELSE
              IF (('a' = first_seat_place AND second_seat_place) IS NOT
                  TRUE) -- checks whether the seats are both marked 'a' for aisle, and if so sets the seatsIDs back to null for another iteration
              THEN SET done = TRUE;
              ELSE
                SET first_seat = NULL;
                SET second_seat = NULL;
              END IF;
            END IF;
          ELSE
            SET first_seat = NULL;
            SET second_seat = NULL;
          END IF;
      END IF;

      -- Check to see the status og the done variable.
      IF done
      THEN
        LEAVE read_loop;
      END IF;
    END LOOP;
    CLOSE vacantSeatsCursor;

    SELECT
      first_seat        AS 'First seat',
      first_seat_place  AS 'First seat placement',
      second_seat       AS 'Second seat',
      second_seat_place AS 'Second seat placement';
  END $$
DELIMITER ;

/*4:
Bætið starfsmannatöflu í FreshAir gagnagrunninn ásamt töflu sem geymir áhöfn flugvélar í ákveðnu flugi.
Hægt þarf að vera að setja áhöfn á flug úr starfsmannalistanum.  Athugið að hver áhafnarmeðlimur getur
verið í mörgum flugum(þó ekki í einu).
Í áhöfninni á TF-LUR er einn flugstjóri(captain), einn flugmaður(first officer) og 10 flugþjónar(cabin crew)*/

CREATE TABLE Employees
(
  employeeID INT         NOT NULL AUTO_INCREMENT,
  firstName  VARCHAR(35) NOT NULL,
  lastName   VARCHAR(35) NOT NULL,
  salary     INT         NOT NULL,
  position   VARCHAR(45),
  CONSTRAINT employee_PK PRIMARY KEY (employeeID)
);

CREATE TABLE FlightCrews
(
  flightCrewID INT NOT NULL AUTO_INCREMENT,
  flightCode   INT NOT NULL,
  employeeID   INT NOT NULL,
  CONSTRAINT flightcrew_PK PRIMARY KEY (flightCrewID),
  CONSTRAINT flightcrew_data_UQ UNIQUE (flightCode, employeeID),
  CONSTRAINT flightcrew_flight_FK FOREIGN KEY (flightCode) REFERENCES Flights (flightCode),
  CONSTRAINT flightcrew_employee_FK FOREIGN KEY (employeeID) REFERENCES Employees (employeeID)
);

INSERT INTO Employees (firstName, lastName, salary, position) VALUES
  ('Jóhannes', 'Guðmundsson', 900000, 'Flugstjóri'),
  ('Gunnar', 'Einarsson', 825000, 'Flugmaður'),
  ('Alfreð', 'Baldvinsson', 400000, 'Flugþjónn'),
  ('Dagur', 'Jónsson', 400000, 'Flugþjónn'),
  ('Flóki', 'Daníelsson', 400000, 'Flugþjónn'),
  ('Hallgrímur', 'Kárason', 400000, 'Flugþjónn'),
  ('Álfdís', 'Kjartansdóttir', 400000, 'Flugfreyja'),
  ('Dögg', 'Áskelsdóttir', 400000, 'Flugfreyja'),
  ('Heiðrún', 'Gunnarsdóttir', 400000, 'Flugfreyja'),
  ('Hekla', 'Ingólfsdóttir', 400000, 'Flugfreyja'),
  ('Júlía', 'Atladóttir', 400000, 'Flugfreyja'),
  ('Margrét', 'Guðlaugsdóttir', 400000, 'Flugfreyja');

-- inserts the crew into flight nr. 73 AKA TF-LUR to LAX
INSERT INTO FlightCrews (flightCode, employeeID) VALUES
  (73, 1),
  (73, 2),
  (73, 3),
  (73, 4),
  (73, 5),
  (73, 6),
  (73, 7),
  (73, 8),
  (73, 9),
  (73, 10),
  (73, 11),
  (73, 12);
