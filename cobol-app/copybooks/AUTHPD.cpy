      *---------------------------------------------------------------
      * AUTHPD - PARAGRAPHS THAT TALK TO THE AUTH SERVER (VIA curl)
      * NOTHING THE CALLER TYPED EVER GOES ON THE COMMAND LINE: THE
      * REQUEST TRAVELS IN A TEMPORARY FILE.
      * (A PASSWORD ON A COMMAND LINE IS A PASSWORD ON A NOTICE
      * BOARD. THE PS COMMAND IS THE NOTICE BOARD.)
      *---------------------------------------------------------------

      * FAIL-503: THE AUTH SERVER COULD NOT BE REACHED, OR SAID
      * SOMETHING WE DO NOT UNDERSTAND. NOT THE CALLER'S FAULT.
       FAIL-503.
           MOVE "503 Service Unavailable" TO WS-HTTP-STATUS
           MOVE '{"error":"auth_unavailable"}' TO WS-JSON-BODY
           PERFORM RESPOND-AND-EXIT.

      * MAKE-TMP-NAMES: FILE NAMES FOR ONE REQUEST. THEY ARE TAKEN
      * FROM THE CLOCK, TO THE HUNDREDTH OF A SECOND, WHICH HAS
      * ALWAYS BEEN AMPLE FOR ONE VISITOR AT A TIME. AS A BONUS THEY
      * SORT NICELY IN A DIRECTORY LISTING.
       MAKE-TMP-NAMES.
           MOVE FUNCTION CURRENT-DATE(1:16) TO WS-TMP-ID
           MOVE SPACES TO WS-REQ-PATH WS-CODE-PATH WS-RESP-PATH
           STRING "/var/lib/tut-work/" WS-TMP-ID ".req"
                  DELIMITED BY SIZE INTO WS-REQ-PATH
           END-STRING
           STRING "/var/lib/tut-work/" WS-TMP-ID ".code"
                  DELIMITED BY SIZE INTO WS-CODE-PATH
           END-STRING
           STRING "/var/lib/tut-work/" WS-TMP-ID ".resp"
                  DELIMITED BY SIZE INTO WS-RESP-PATH
           END-STRING.

      * WRITE-REQ: SAVE REQ-REC TO THE REQUEST FILE. IF THE FILE
      * CANNOT BE WRITTEN, THAT IS A 500 (OUR OWN KITCHEN IS ON FIRE).
       WRITE-REQ.
           OPEN OUTPUT REQ-FILE
           IF WS-FS NOT = "00"
               PERFORM FAIL-500
           END-IF
           WRITE REQ-REC
           CLOSE REQ-FILE.

      * AUTH_URL FROM THE ENVIRONMENT, WITH A DEFAULT FOR THE
      * FORGETFUL. (THE DEFAULT IS THE NAME COMPOSE GIVES THE
      * AUTH SERVER.)
       LOAD-AUTH-URL.
           MOVE "AUTH_URL" TO WS-ENV-NAME
           PERFORM GET-ENV
           MOVE WS-ENV-VALUE TO WS-AUTH-URL
           IF WS-AUTH-URL = SPACES
               MOVE "http://auth-server:5000" TO WS-AUTH-URL
           END-IF.

      * CALL-AUTH: WS-AUTH-MODE 'P' = POST THE REQUEST FILE AS JSON
      *                         'G' = GET; REQUEST FILE HOLDS A HEADER
      *            WS-AUTH-ROUTE = PATH ON THE AUTH SERVER
      *            OUT WS-HTTP-CODE ('000' IF NOTHING CAME BACK)
      *                WS-RESP-TEXT (THE RESPONSE BODY)
      * curl GIVES UP AFTER 5 SECONDS. SO DOES THE CALLER.
       CALL-AUTH.
           PERFORM LOAD-AUTH-URL
           MOVE SPACES TO WS-CMD
           IF WS-AUTH-MODE = "P"
               STRING "curl -s -m 5 -o " FUNCTION TRIM(WS-RESP-PATH)
                      " -w '%{http_code}'"
                      " -H 'Content-Type: application/json'"
                      " --data-binary @" FUNCTION TRIM(WS-REQ-PATH)
                      " " FUNCTION TRIM(WS-AUTH-URL)
                      FUNCTION TRIM(WS-AUTH-ROUTE)
                      " > " FUNCTION TRIM(WS-CODE-PATH)
                      " 2>/dev/null"
                      WS-NUL
                      DELIMITED BY SIZE INTO WS-CMD
               END-STRING
           ELSE
               STRING "curl -s -m 5 -o " FUNCTION TRIM(WS-RESP-PATH)
                      " -w '%{http_code}'"
                      " -H @" FUNCTION TRIM(WS-REQ-PATH)
                      " " FUNCTION TRIM(WS-AUTH-URL)
                      FUNCTION TRIM(WS-AUTH-ROUTE)
                      " > " FUNCTION TRIM(WS-CODE-PATH)
                      " 2>/dev/null"
                      WS-NUL
                      DELIMITED BY SIZE INTO WS-CMD
               END-STRING
           END-IF
           CALL "SYSTEM" USING WS-CMD
           PERFORM READ-AUTH-RESULT
           PERFORM CLEAN-TMP.

      * READ THE CODE FILE, THEN THE BODY FILE. A MISSING FILE
      * LEAVES THE DEFAULTS ('000' AND SPACES) IN PLACE.
       READ-AUTH-RESULT.
           MOVE "000" TO WS-HTTP-CODE
           MOVE SPACES TO WS-RESP-TEXT
           OPEN INPUT CODE-FILE
           IF WS-FS = "00"
               READ CODE-FILE
                   AT END
                       CONTINUE
                   NOT AT END
                       MOVE CODE-REC(1:3) TO WS-HTTP-CODE
               END-READ
               CLOSE CODE-FILE
           END-IF
           OPEN INPUT RESP-FILE
           IF WS-FS = "00"
               READ RESP-FILE
                   AT END
                       CONTINUE
                   NOT AT END
                       MOVE RESP-REC TO WS-RESP-TEXT
               END-READ
               CLOSE RESP-FILE
           END-IF.

      * CLEAN-TMP: DELETE THE TEMPORARY FILES. THEY MAY HOLD SECRETS,
      * AND SECRETS DO NOT BELONG IN /var/lib.
       CLEAN-TMP.
           MOVE SPACES TO WS-CMD
           STRING "rm -f " FUNCTION TRIM(WS-REQ-PATH)
                  " " FUNCTION TRIM(WS-CODE-PATH)
                  " " FUNCTION TRIM(WS-RESP-PATH)
                  WS-NUL
                  DELIMITED BY SIZE INTO WS-CMD
           END-STRING
           CALL "SYSTEM" USING WS-CMD.

      * JSON-GET-STRING: IN WS-RESP-TEXT AND WS-JKEY, E.G. 'token'
      *                  OUT WS-JFOUND, WS-JVAL / WS-JVAL-LEN
      * READS ONLY SIMPLE STRING VALUES; A BACKSLASH IN THE VALUE
      * MAKES IT 'NOT FOUND'. IT IS A NEEDLE-AND-HAYSTACK ROUTINE
      * AND PROUD OF IT.
       JSON-GET-STRING.
           MOVE "N" TO WS-JFOUND
           MOVE "N" TO WS-JBAD
           MOVE SPACES TO WS-JVAL
           MOVE 0 TO WS-JVAL-LEN
           MOVE SPACES TO WS-NEEDLE
           COMPUTE WS-KLEN = FUNCTION LENGTH(FUNCTION TRIM(WS-JKEY))
           STRING '"' FUNCTION TRIM(WS-JKEY) '"'
                  DELIMITED BY SIZE INTO WS-NEEDLE
           END-STRING
           COMPUTE WS-NEEDLE-LEN = WS-KLEN + 2
           MOVE 0 TO WS-CNT
           INSPECT WS-RESP-TEXT TALLYING WS-CNT
               FOR CHARACTERS BEFORE INITIAL WS-NEEDLE(1:WS-NEEDLE-LEN)
           IF WS-CNT < 1000
               COMPUTE WS-JPOS = WS-CNT + WS-NEEDLE-LEN + 1
               PERFORM SKIP-JSON-SPACES
               IF WS-JPOS <= 1000
                   IF WS-RESP-TEXT(WS-JPOS:1) = ":"
                       ADD 1 TO WS-JPOS
                       PERFORM SKIP-JSON-SPACES
                       IF WS-JPOS <= 1000
                           IF WS-RESP-TEXT(WS-JPOS:1) = '"'
                               ADD 1 TO WS-JPOS
                               PERFORM COLLECT-JSON-VALUE
                           END-IF
                       END-IF
                   END-IF
               END-IF
           END-IF.

      * STEP OVER BLANKS. JSON HAS MORE OF THEM THAN IT NEEDS.
       SKIP-JSON-SPACES.
           PERFORM UNTIL WS-JPOS > 1000
                      OR WS-RESP-TEXT(WS-JPOS:1) NOT = SPACE
               ADD 1 TO WS-JPOS
           END-PERFORM.

      * COPY CHARACTERS UP TO THE CLOSING QUOTE (MAX 100).
       COLLECT-JSON-VALUE.
           PERFORM UNTIL WS-JPOS > 1000
                      OR WS-RESP-TEXT(WS-JPOS:1) = '"'
                      OR WS-JVAL-LEN >= 100
               IF WS-RESP-TEXT(WS-JPOS:1) = "\"
                   MOVE "Y" TO WS-JBAD
               END-IF
               ADD 1 TO WS-JVAL-LEN
               MOVE WS-RESP-TEXT(WS-JPOS:1)
                   TO WS-JVAL(WS-JVAL-LEN:1)
               ADD 1 TO WS-JPOS
           END-PERFORM
           IF WS-JPOS <= 1000 AND WS-JBAD = "N"
               IF WS-RESP-TEXT(WS-JPOS:1) = '"'
                   MOVE "Y" TO WS-JFOUND
               END-IF
           END-IF.
