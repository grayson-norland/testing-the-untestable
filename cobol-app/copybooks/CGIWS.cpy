      *---------------------------------------------------------------
      * CGIWS - WORKING-STORAGE SHARED BY THE CGI PROGRAMS
      * EVERYTHING IN ONE PLACE, WHERE IT CANNOT HIDE.
      *---------------------------------------------------------------
      * HTTP LINES END IN CR+LF. A RULE OLDER THAN THIS DEPARTMENT
      * AND THE ONE THING ON THIS PAGE EVERYONE AGREES ON.
       01  WS-CRLF                 PIC XX           VALUE X"0D0A".
       01  WS-NUL                  PIC X            VALUE X"00".
      * WHAT WE TELL THE CALLER: '200 OK', '401 Unauthorized', ETC.
      * THE EXTRA HEADER IS FOR THE OCCASIONAL 'Allow:' AND FRIENDS.
       01  WS-HTTP-STATUS          PIC X(40)        VALUE SPACES.
       01  WS-EXTRA-HEADER         PIC X(80)        VALUE SPACES.
      * THE ANSWER, BUILT UP PIECE BY PIECE AND SENT AT THE END.
      * 1500 BYTES. IF YOU NEED MORE, YOU NEED A DIFFERENT PROGRAM.
       01  WS-JSON-BODY            PIC X(1500)      VALUE SPACES.
       01  WS-JSON-PTR             PIC S9(9) COMP-5 VALUE 1.

      * ENVIRONMENT: HOW A CGI PROGRAM LEARNS ANYTHING AT ALL.
      * THE WEB SERVER LEAVES NOTES IN THE ENVIRONMENT AND LEAVES.
       01  WS-ENV-NAME             PIC X(40)        VALUE SPACES.
       01  WS-ENV-VALUE            PIC X(1100)      VALUE SPACES.
       01  WS-ENV-LEN              PIC S9(9) COMP-5 VALUE 0.

      * REQUEST PARSING: THE QUERY STRING OR THE FORM BODY (K=V&K=V)
      * TURNED INTO SOMETHING A PERSON COULD READ. 1100 BYTES; THE
      * READ ROUTINES REFUSE ANYTHING OVER 1024 BEFORE IT GETS HERE.
       01  WS-SRC                  PIC X(1100)      VALUE SPACES.
       01  WS-SRC-LEN              PIC S9(9) COMP-5 VALUE 0.
       01  WS-KEY                  PIC X(20)        VALUE SPACES.
       01  WS-VAL                  PIC X(1100)      VALUE SPACES.
       01  WS-VAL-LEN              PIC S9(9) COMP-5 VALUE 0.
       01  WS-FOUND                PIC X            VALUE "N".
       01  WS-SEG-START            PIC S9(9) COMP-5.
       01  WS-SEG-END              PIC S9(9) COMP-5.
       01  WS-EQ-POS               PIC S9(9) COMP-5.
       01  WS-KLEN                 PIC S9(9) COMP-5.
       01  WS-VLEN                 PIC S9(9) COMP-5.
       01  WS-BODY-LEN             PIC S9(9) COMP-5.
       01  WS-TOTAL                PIC S9(9) COMP-5.
       01  WS-WANT                 USAGE BINARY-DOUBLE.
       01  WS-READ-N               USAGE BINARY-DOUBLE.
       01  WS-EOF                  PIC X            VALUE "N".

      * URL DECODING: TEXT ARRIVES IN DISGUISE (%41, +). THIS IS
      * THE UNMASKING.
       01  WS-DEC-IN               PIC X(1100).
       01  WS-DEC-IN-LEN           PIC S9(9) COMP-5.
       01  WS-DEC-OUT              PIC X(1100).
       01  WS-DEC-OUT-LEN          PIC S9(9) COMP-5.
       01  WS-DEC-I                PIC S9(9) COMP-5.
       01  WS-DEC-BAD              PIC X            VALUE "N".
       01  WS-CH                   PIC X.
       01  WS-CH-OUT               PIC X.
       01  WS-HEX-CH               PIC X.
       01  WS-HEX-VAL              PIC S9(4) COMP-5.
       01  WS-HI                   PIC S9(4) COMP-5.
       01  WS-LO                   PIC S9(4) COMP-5.
       01  WS-BYTE                 PIC S9(9) COMP-5.

      * JSON ESCAPING: IN THE WORST CASE EVERY CHARACTER GROWS TO
      * TWO. HENCE 420 FOR A 200-BYTE INPUT, WITH A LITTLE HOPE.
       01  WS-ESC-IN               PIC X(200).
       01  WS-ESC-LEN              PIC S9(9) COMP-5.
       01  WS-ESC-OUT              PIC X(420).
       01  WS-ESC-OUT-LEN          PIC S9(9) COMP-5.
       01  WS-ESC-I                PIC S9(9) COMP-5.

      * DATABASE ACCESS: LIBPQ, CALLED DIRECTLY. NO PRECOMPILER WAS
      * HARMED. HOST, PORT AND NAME COME FROM THE ENVIRONMENT; USER
      * AND PASSWORD ARE FILLED IN BY THE PROGRAM THAT NEEDS THEM.
       01  WS-DB-HOST              PIC X(64).
       01  WS-DB-PORT              PIC X(8).
       01  WS-DB-NAME              PIC X(64).
       01  WS-DB-USER              PIC X(64).
       01  WS-DB-PASS              PIC X(64).
       01  WS-CONNINFO             PIC X(400).
      * THE POINTERS BELOW BELONG TO LIBPQ. DO NOT DEREFERENCE,
      * DO NOT ADMIRE.
       01  WS-CONN                 USAGE POINTER.
       01  WS-RES                  USAGE POINTER.
       01  WS-PTR                  USAGE POINTER.
       01  WS-NULLPTR              USAGE POINTER.
       01  WS-DB-CONNECTED         PIC X            VALUE "N".
       01  WS-INT                  PIC S9(9) COMP-5.
      * THE SQL TEXT AND UP TO TWO PARAMETERS ($1, $2). 200 BYTES
      * HAS ALWAYS BEEN ENOUGH FOR EVERY QUERY WE HAVE WRITTEN.
       01  WS-SQL                  PIC X(200).
       01  WS-P1                   PIC X(120).
       01  WS-P2                   PIC X(120).
       01  WS-NPARAMS              PIC S9(9) COMP-5.
       01  WS-PARAM-TABLE.
           05  WS-PARAM-PTR        USAGE POINTER OCCURS 2 TIMES.
       01  WS-ROW                  PIC S9(9) COMP-5.
       01  WS-COL                  PIC S9(9) COMP-5.
       01  WS-STRLEN               USAGE BINARY-DOUBLE UNSIGNED.
      * ONE RESULT COLUMN AT A TIME, UP TO 200 BYTES.
       01  WS-FIELD                PIC X(200).
