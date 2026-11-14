      *---------------------------------------------------------------
      * AUTHWS - WORKING-STORAGE FOR THE AUTH-SERVER CALL
      *---------------------------------------------------------------
      * FILE STATUS. '00' IS GOOD. EVERYTHING ELSE IS A STORY.
       01  WS-FS                   PIC XX.
       01  WS-TMP-ID               PIC X(16).
      * THE THREE TEMPORARY FILES OF ONE REQUEST. THEY ARE DELETED
      * AS SOON AS THE ANSWER HAS BEEN READ.
       01  WS-REQ-PATH             PIC X(80).
       01  WS-CODE-PATH            PIC X(80).
       01  WS-RESP-PATH            PIC X(80).

      * WHERE THE AUTH SERVER LIVES, WHICH ROUTE, AND WHETHER WE
      * POST OR GET ('P' OR 'G').  WS-CMD IS THE curl LINE.
       01  WS-AUTH-URL             PIC X(100).
       01  WS-AUTH-ROUTE           PIC X(20).
       01  WS-AUTH-MODE            PIC X.
       01  WS-CMD                  PIC X(600).
      * WHAT CAME BACK: THE CODE ('000' IF NOTHING DID) AND THE
      * BODY (FIRST 1000 BYTES ONLY; THE AUTH SERVER IS BRIEF).
       01  WS-HTTP-CODE            PIC X(3).
       01  WS-RESP-TEXT            PIC X(1000).

      * MINIMAL JSON READER: FIND A KEY, RETURN ITS STRING VALUE.
      * NOT A PARSER. A PARSER WOULD HAVE BEEN A SEPARATE BUDGET.
       01  WS-JKEY                 PIC X(20).
       01  WS-JVAL                 PIC X(100).
       01  WS-JVAL-LEN             PIC S9(9) COMP-5.
       01  WS-JFOUND               PIC X.
       01  WS-JBAD                 PIC X.
       01  WS-NEEDLE               PIC X(24).
       01  WS-NEEDLE-LEN           PIC S9(9) COMP-5.
       01  WS-JPOS                 PIC S9(9) COMP-5.
       01  WS-CNT                  PIC S9(9) COMP-5.
