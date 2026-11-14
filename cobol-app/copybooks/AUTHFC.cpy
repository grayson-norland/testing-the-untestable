      *---------------------------------------------------------------
      * AUTHFC - FILE-CONTROL FOR THE AUTH-SERVER CALL
      * THREE FILES, ONE PER THING WE NEED TO PASS TO OR FROM curl.
      * THE FILE NAMES ARE CHOSEN AT RUN TIME (SEE MAKE-TMP-NAMES).
      *---------------------------------------------------------------
           SELECT REQ-FILE ASSIGN TO WS-REQ-PATH
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS WS-FS.
           SELECT CODE-FILE ASSIGN TO WS-CODE-PATH
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS WS-FS.
           SELECT RESP-FILE ASSIGN TO WS-RESP-PATH
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS WS-FS.
