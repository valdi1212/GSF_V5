-- Start by working on copy of the procedure from project 2 --

DELIMITER $$
DROP PROCEDURE IF EXISTS TwoSideBySide $$
CREATE PROCEDURE TwoSideBySide(flight_number CHAR(5), flight_date DATE,
                               query_mode    TINYINT) -- Added variable to determine mode; 0 for default, 1 for new functionality
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

          IF (first_seat + 1 = second_seat AND first_seat_row = second_seat_row) -- checks for side by side seats first, since it would have to do so regardless of query mode
          THEN
            IF (query_mode = 0)
            THEN SET done = TRUE;
            ELSE
              IF (('a' = first_seat_place AND second_seat_place) IS NOT TRUE) -- checks whether the seats are both marked 'a' for aisle, and if so sets the seatsIDs back to null for another iteration
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

    SELECT -- TODO: change to pivot view for readability, since there is only one resulting row
      first_seat  AS 'First seat',
      first_seat_place AS 'First seat placement',
      second_seat AS 'Second seat',
      second_seat_place as 'Second seat placement';
  END $$
DELIMITER ;
