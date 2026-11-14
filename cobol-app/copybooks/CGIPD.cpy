      *---------------------------------------------------------------
      * CGIPD - PROCEDURE PARAGRAPHS SHARED BY THE CGI PROGRAMS
      * THE PLUMBING. A CGI PROGRAM IS BORN, ANSWERS ONE REQUEST AND
      * DIES. THE WEB SERVER DOES NOT MIND; IT HAS SEEN WORSE.
      *---------------------------------------------------------------

      * GET-ENV: IN WS-ENV-NAME, OUT WS-ENV-VALUE (SPACES IF UNSET)
      * THE ENVIRONMENT IS THE ONLY MAIL THIS PROGRAM RECEIVES.
       GET-ENV.
           MOVE SPACES TO WS-ENV-VALUE
           DISPLAY WS-ENV-NAME UPON ENVIRONMENT-NAME
           ACCEPT WS-ENV-VALUE FROM ENVIRONMENT-VALUE
               ON EXCEPTION
                   MOVE SPACES TO WS-ENV-VALUE
           END-ACCEPT.

      * ENV-LEN: OUT WS-ENV-LEN = LENGTH OF WS-ENV-VALUE WITHOUT
      * PADDING. COBOL HAS NO STRLEN, SO WE COUNT BACKWARDS FROM
      * THE END, ON OUR FINGERS.
       ENV-LEN.
           MOVE 1100 TO WS-ENV-LEN
           PERFORM UNTIL WS-ENV-LEN = 0
                      OR WS-ENV-VALUE(WS-ENV-LEN:1) NOT = SPACE
               SUBTRACT 1 FROM WS-ENV-LEN
           END-PERFORM.

      * READ-QUERY: LOAD THE QUERY STRING INTO WS-SRC.
      * OVER 1024 BYTES IS A 414. NO QUERY WE WANT IS THAT LONG.
       READ-QUERY.
           MOVE "QUERY_STRING" TO WS-ENV-NAME
           PERFORM GET-ENV
           PERFORM ENV-LEN
           IF WS-ENV-LEN > 1024
               MOVE "414 URI Too Long" TO WS-HTTP-STATUS
               MOVE '{"error":"uri_too_long"}' TO WS-JSON-BODY
               PERFORM RESPOND-AND-EXIT
           END-IF
           MOVE WS-ENV-VALUE TO WS-SRC
           MOVE WS-ENV-LEN TO WS-SRC-LEN.

      * READ-BODY: LOAD THE REQUEST BODY (STDIN) INTO WS-SRC.
      * CONTENT_LENGTH SAYS HOW MUCH TO READ; WE BELIEVE IT UP TO
      * 1024 BYTES (413 BEYOND THAT). READ IN A LOOP, BECAUSE
      * read() MAY RETURN LESS THAN ASKED, LIKE A PART-TIME WORKER.
       READ-BODY.
           MOVE SPACES TO WS-SRC
           MOVE 0 TO WS-SRC-LEN
           MOVE "CONTENT_LENGTH" TO WS-ENV-NAME
           PERFORM GET-ENV
           COMPUTE WS-BODY-LEN = FUNCTION NUMVAL(WS-ENV-VALUE)
           IF WS-BODY-LEN > 1024
               MOVE "413 Payload Too Large" TO WS-HTTP-STATUS
               MOVE '{"error":"payload_too_large"}' TO WS-JSON-BODY
               PERFORM RESPOND-AND-EXIT
           END-IF
           MOVE 0 TO WS-TOTAL
           MOVE "N" TO WS-EOF
           PERFORM UNTIL WS-TOTAL >= WS-BODY-LEN OR WS-EOF = "Y"
               COMPUTE WS-WANT = WS-BODY-LEN - WS-TOTAL
               CALL "read" USING BY VALUE 0
                    BY REFERENCE WS-SRC(WS-TOTAL + 1:WS-WANT)
                    BY VALUE WS-WANT
                    RETURNING WS-READ-N
               IF WS-READ-N <= 0
                   MOVE "Y" TO WS-EOF
               ELSE
                   ADD WS-READ-N TO WS-TOTAL
               END-IF
           END-PERFORM
           MOVE WS-TOTAL TO WS-SRC-LEN.

      * HEX-VALUE: IN WS-HEX-CH, OUT WS-HEX-VAL (-1 IF NOT A HEX
      * DIGIT). THREE RANGES, ONE PER ALPHABET, NO CLEVERNESS.
       HEX-VALUE.
           EVALUATE TRUE
               WHEN WS-HEX-CH >= "0" AND WS-HEX-CH <= "9"
                   COMPUTE WS-HEX-VAL =
                       FUNCTION ORD(WS-HEX-CH) - FUNCTION ORD("0")
               WHEN WS-HEX-CH >= "A" AND WS-HEX-CH <= "F"
                   COMPUTE WS-HEX-VAL =
                       FUNCTION ORD(WS-HEX-CH) - FUNCTION ORD("A") + 10
               WHEN WS-HEX-CH >= "a" AND WS-HEX-CH <= "f"
                   COMPUTE WS-HEX-VAL =
                       FUNCTION ORD(WS-HEX-CH) - FUNCTION ORD("a") + 10
               WHEN OTHER
                   MOVE -1 TO WS-HEX-VAL
           END-EVALUATE.

      * URL-DECODE: IN WS-DEC-IN / WS-DEC-IN-LEN
      *             OUT WS-DEC-OUT / WS-DEC-OUT-LEN / WS-DEC-BAD
      * WS-DEC-BAD = 'Y' FOR A BROKEN %XX OR A CONTROL CHARACTER.
      * THE CALLER THEN GETS A 400.
       URL-DECODE.
           MOVE SPACES TO WS-DEC-OUT
           MOVE 0 TO WS-DEC-OUT-LEN
           MOVE "N" TO WS-DEC-BAD
           MOVE 1 TO WS-DEC-I
           PERFORM UNTIL WS-DEC-I > WS-DEC-IN-LEN
               MOVE WS-DEC-IN(WS-DEC-I:1) TO WS-CH
               MOVE WS-CH TO WS-CH-OUT
               ADD 1 TO WS-DEC-I
               EVALUATE TRUE
                   WHEN WS-CH = "+"
                       MOVE SPACE TO WS-CH-OUT
                   WHEN WS-CH = "%"
                       PERFORM DECODE-PERCENT
               END-EVALUATE
               PERFORM STORE-DECODED
           END-PERFORM.

      * %XX: TWO HEX DIGITS, ONE BYTE. IF THE DIGITS ARE NOT HEX,
      * OR ARE MISSING, THE VALUE IS BAD.
       DECODE-PERCENT.
           IF WS-DEC-I + 1 > WS-DEC-IN-LEN
               MOVE "Y" TO WS-DEC-BAD
           ELSE
               MOVE WS-DEC-IN(WS-DEC-I:1) TO WS-HEX-CH
               PERFORM HEX-VALUE
               MOVE WS-HEX-VAL TO WS-HI
               MOVE WS-DEC-IN(WS-DEC-I + 1:1) TO WS-HEX-CH
               PERFORM HEX-VALUE
               MOVE WS-HEX-VAL TO WS-LO
               IF WS-HI < 0 OR WS-LO < 0
                   MOVE "Y" TO WS-DEC-BAD
               ELSE
                   COMPUTE WS-BYTE = WS-HI * 16 + WS-LO
                   MOVE FUNCTION CHAR(WS-BYTE + 1) TO WS-CH-OUT
                   ADD 2 TO WS-DEC-I
               END-IF
           END-IF.

      * APPEND ONE DECODED CHARACTER. CONTROL CHARACTERS (BELOW
      * SPACE, AND DEL) MARK THE VALUE BAD; NOBODY TYPES THEM
      * ON PURPOSE.
       STORE-DECODED.
           IF WS-CH-OUT < SPACE OR WS-CH-OUT = X"7F"
               MOVE "Y" TO WS-DEC-BAD
           END-IF
           ADD 1 TO WS-DEC-OUT-LEN
           MOVE WS-CH-OUT TO WS-DEC-OUT(WS-DEC-OUT-LEN:1).

      * FIND-PARAM: IN WS-SRC / WS-SRC-LEN (K=V&K=V...) AND WS-KEY
      *             OUT WS-FOUND, WS-VAL / WS-VAL-LEN (DECODED),
      *             WS-DEC-BAD.  FIRST MATCH WINS; A SECOND
      *             'account=' IS IGNORED, POLITELY.
       FIND-PARAM.
           MOVE "N" TO WS-FOUND
           MOVE 0 TO WS-VAL-LEN
           MOVE SPACES TO WS-VAL
           MOVE "N" TO WS-DEC-BAD
           COMPUTE WS-KLEN = FUNCTION LENGTH(FUNCTION TRIM(WS-KEY))
           MOVE 1 TO WS-SEG-START
           PERFORM UNTIL WS-SEG-START > WS-SRC-LEN
                      OR WS-FOUND = "Y"
               MOVE WS-SEG-START TO WS-SEG-END
               PERFORM UNTIL WS-SEG-END > WS-SRC-LEN
                          OR WS-SRC(WS-SEG-END:1) = "&"
                   ADD 1 TO WS-SEG-END
               END-PERFORM
               MOVE WS-SEG-START TO WS-EQ-POS
               PERFORM UNTIL WS-EQ-POS >= WS-SEG-END
                          OR WS-SRC(WS-EQ-POS:1) = "="
                   ADD 1 TO WS-EQ-POS
               END-PERFORM
               IF WS-EQ-POS < WS-SEG-END
                   IF WS-EQ-POS - WS-SEG-START >= WS-KLEN
                      AND WS-SRC(WS-SEG-START:WS-KLEN)
                              = WS-KEY(1:WS-KLEN)
                       PERFORM TAKE-VALUE
                   END-IF
               END-IF
               COMPUTE WS-SEG-START = WS-SEG-END + 1
           END-PERFORM.

      * SLICE OUT THE TEXT AFTER THE = AND DECODE IT.
       TAKE-VALUE.
           COMPUTE WS-VLEN = WS-SEG-END - WS-EQ-POS - 1
           MOVE SPACES TO WS-DEC-IN
           IF WS-VLEN > 0
               MOVE WS-SRC(WS-EQ-POS + 1:WS-VLEN) TO WS-DEC-IN
           END-IF
           MOVE WS-VLEN TO WS-DEC-IN-LEN
           PERFORM URL-DECODE
           MOVE WS-DEC-OUT TO WS-VAL
           MOVE WS-DEC-OUT-LEN TO WS-VAL-LEN
           MOVE "Y" TO WS-FOUND.

      * SET-ESC-LEN: OUT WS-ESC-LEN = LENGTH OF WS-ESC-IN, WITHOUT
      * TRAILING SPACES. THE SPACE BAR HAS NO RIGHTS HERE.
       SET-ESC-LEN.
           MOVE 200 TO WS-ESC-LEN
           PERFORM UNTIL WS-ESC-LEN = 0
                      OR WS-ESC-IN(WS-ESC-LEN:1) NOT = SPACE
               SUBTRACT 1 FROM WS-ESC-LEN
           END-PERFORM.

      * JSON-ESCAPE: IN WS-ESC-IN / WS-ESC-LEN, OUT WS-ESC-OUT / -LEN
      * A BACKSLASH OR A QUOTE GETS A BACKSLASH IN FRONT OF IT;
      * A CONTROL CHARACTER BECOMES A SPACE (MERCY, OF A KIND).
       JSON-ESCAPE.
           MOVE SPACES TO WS-ESC-OUT
           MOVE 0 TO WS-ESC-OUT-LEN
           PERFORM VARYING WS-ESC-I FROM 1 BY 1
                   UNTIL WS-ESC-I > WS-ESC-LEN
               MOVE WS-ESC-IN(WS-ESC-I:1) TO WS-CH
               IF WS-CH = '"' OR WS-CH = "\"
                   ADD 1 TO WS-ESC-OUT-LEN
                   MOVE "\" TO WS-ESC-OUT(WS-ESC-OUT-LEN:1)
               END-IF
               IF WS-CH < SPACE
                   MOVE SPACE TO WS-CH
               END-IF
               ADD 1 TO WS-ESC-OUT-LEN
               MOVE WS-CH TO WS-ESC-OUT(WS-ESC-OUT-LEN:1)
           END-PERFORM.

      * APPEND-ESC: APPEND WS-ESC-IN, JSON-ESCAPED, TO WS-JSON-BODY.
      * TRAILING SPACES OF THE INPUT ARE DROPPED.
       APPEND-ESC.
           PERFORM SET-ESC-LEN
           PERFORM APPEND-ESC-RAW.

      * APPEND-ESC-RAW: SAME, BUT TRUSTS THE LENGTH ALREADY IN
      * WS-ESC-LEN (SO TRAILING SPACES IN A PASSWORD SURVIVE).
       APPEND-ESC-RAW.
           PERFORM JSON-ESCAPE
           IF WS-ESC-OUT-LEN > 0
               STRING WS-ESC-OUT(1:WS-ESC-OUT-LEN) DELIMITED BY SIZE
                   INTO WS-JSON-BODY WITH POINTER WS-JSON-PTR
               END-STRING
           END-IF.

      * SEND-JSON: WRITE THE CGI RESPONSE (STATUS, HEADERS, BODY).
      * CGI WANTS A 'Status:' LINE, THE HEADERS, A BLANK LINE, THEN
      * THE BODY. NO ADVANCING, BECAUSE WE WRITE THE CR+LF OURSELVES,
      * LIKE GENTLEMEN.
       SEND-JSON.
           DISPLAY "Status: " FUNCTION TRIM(WS-HTTP-STATUS) WS-CRLF
                   "Content-Type: application/json" WS-CRLF
                   "Cache-Control: no-store" WS-CRLF
                   NO ADVANCING
           IF WS-EXTRA-HEADER NOT = SPACES
               DISPLAY FUNCTION TRIM(WS-EXTRA-HEADER) WS-CRLF
                       NO ADVANCING
           END-IF
           DISPLAY WS-CRLF FUNCTION TRIM(WS-JSON-BODY TRAILING)
                   NO ADVANCING.

      * RESPOND-AND-EXIT: SEND THE RESPONSE, CLOSE THE DATABASE,
      * STOP RUN. EVERY ROAD IN THESE PROGRAMS ENDS HERE. THE
      * PROGRAM THEN DIES AND THE WEB SERVER STARTS ANOTHER. THIS
      * IS CALLED 'SCALABILITY' IN THE BROCHURES.
       RESPOND-AND-EXIT.
           PERFORM SEND-JSON
           PERFORM DB-DISCONNECT
           STOP RUN.

      * FAIL-500: SOMETHING WE DID NOT PLAN FOR. TELLS THE CALLER
      * AS LITTLE AS POSSIBLE; THE CALLER DID NOT ASK FOR OUR
      * OPINIONS.
       FAIL-500.
           MOVE "500 Internal Server Error" TO WS-HTTP-STATUS
           MOVE '{"error":"internal_error"}' TO WS-JSON-BODY
           PERFORM RESPOND-AND-EXIT.

      * LOAD-DB-CONFIG: HOST / PORT / DATABASE NAME FROM THE
      * ENVIRONMENT, WITH DEFAULTS FOR THE FORGETFUL. USER AND
      * PASSWORD ARE NOT HERE; THE CALLER SUPPLIES THEM.
       LOAD-DB-CONFIG.
           MOVE "DB_HOST" TO WS-ENV-NAME
           PERFORM GET-ENV
           MOVE WS-ENV-VALUE TO WS-DB-HOST
           IF WS-DB-HOST = SPACES
               MOVE "db" TO WS-DB-HOST
           END-IF
           MOVE "DB_PORT" TO WS-ENV-NAME
           PERFORM GET-ENV
           MOVE WS-ENV-VALUE TO WS-DB-PORT
           IF WS-DB-PORT = SPACES
               MOVE "5432" TO WS-DB-PORT
           END-IF
           MOVE "DB_NAME" TO WS-ENV-NAME
           PERFORM GET-ENV
           MOVE WS-ENV-VALUE TO WS-DB-NAME
           IF WS-DB-NAME = SPACES
               MOVE "accounts_db" TO WS-DB-NAME
           END-IF.

      * DB-CONNECT: IN WS-DB-USER / WS-DB-PASS (+ LOAD-DB-CONFIG
      * VALUES). BUILDS THE CONNECTION STRING (KEY=VALUE, SPACES
      * BETWEEN, A NUL AT THE END BECAUSE C INSISTS) AND KNOCKS.
      * FIVE SECONDS OF PATIENCE. ANY FAILURE IS A 500.
       DB-CONNECT.
           MOVE SPACES TO WS-CONNINFO
           STRING "host=" FUNCTION TRIM(WS-DB-HOST)
                  " port=" FUNCTION TRIM(WS-DB-PORT)
                  " dbname=" FUNCTION TRIM(WS-DB-NAME)
                  " user=" FUNCTION TRIM(WS-DB-USER)
                  " password=" FUNCTION TRIM(WS-DB-PASS)
                  " connect_timeout=5"
                  WS-NUL
                  DELIMITED BY SIZE INTO WS-CONNINFO
           END-STRING
           CALL "PQconnectdb" USING BY REFERENCE WS-CONNINFO
                RETURNING WS-CONN
           MOVE "Y" TO WS-DB-CONNECTED
           CALL "PQstatus" USING BY VALUE WS-CONN RETURNING WS-INT
           IF WS-INT NOT = 0
               PERFORM FAIL-500
           END-IF.

      * HANG UP POLITELY, BUT ONLY IF WE EVER CALLED.
       DB-DISCONNECT.
           IF WS-DB-CONNECTED = "Y"
               CALL "PQfinish" USING BY VALUE WS-CONN
               MOVE "N" TO WS-DB-CONNECTED
           END-IF.

      * DB-EXEC: RUN WS-SQL WITH WS-NPARAMS PARAMETERS
      *          ($1 = WS-P1, $2 = WS-P2)
      * WS-NPARAMS MAY BE 0 IF THE SQL TEXT IS COMPLETE ALREADY.
      * PARAMETERS ARE NUL-TERMINATED AND TRAVEL SEPARATELY FROM THE
      * SQL TEXT. ONLY LIBPQ STATUS 2 (ROWS COMING BACK) IS
      * ACCEPTED; ANYTHING ELSE IS A 500.
       DB-EXEC.
           SET WS-PARAM-PTR(1) TO ADDRESS OF WS-P1
           SET WS-PARAM-PTR(2) TO ADDRESS OF WS-P2
           SET WS-NULLPTR TO NULL
           CALL "PQexecParams" USING
                BY VALUE WS-CONN
                BY REFERENCE WS-SQL
                BY VALUE WS-NPARAMS
                BY VALUE WS-NULLPTR
                BY REFERENCE WS-PARAM-TABLE
                BY VALUE WS-NULLPTR
                BY VALUE WS-NULLPTR
                BY VALUE 0
                RETURNING WS-RES
           CALL "PQresultStatus" USING BY VALUE WS-RES
                RETURNING WS-INT
           IF WS-INT NOT = 2
               PERFORM FAIL-500
           END-IF.

      * GET-FIELD: IN WS-ROW / WS-COL (0-BASED), OUT WS-FIELD.
      * LIBPQ HANDS BACK A C STRING; WE COPY IT WITH ITS EXACT
      * LENGTH (200 AT MOST) INTO A COBOL FIELD.
       GET-FIELD.
           MOVE SPACES TO WS-FIELD
           CALL "PQgetvalue" USING BY VALUE WS-RES
                BY VALUE WS-ROW BY VALUE WS-COL
                RETURNING WS-PTR
           CALL "PQgetlength" USING BY VALUE WS-RES
                BY VALUE WS-ROW BY VALUE WS-COL
                RETURNING WS-STRLEN
           IF WS-STRLEN > 200
               MOVE 200 TO WS-STRLEN
           END-IF
           IF WS-STRLEN > 0
               SET ADDRESS OF LK-CSTR TO WS-PTR
               MOVE LK-CSTR(1:WS-STRLEN) TO WS-FIELD
           END-IF.
