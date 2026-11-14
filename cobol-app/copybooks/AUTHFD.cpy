      *---------------------------------------------------------------
      * AUTHFD - FILE DESCRIPTIONS FOR THE AUTH-SERVER CALL
      *   REQ-FILE  : WHAT WE SEND (JSON BODY OR AN HTTP HEADER LINE)
      *   CODE-FILE : THE HTTP STATUS CODE THAT CAME BACK
      *   RESP-FILE : THE RESPONSE BODY THAT CAME BACK
      * ONE LINE EACH IS ENOUGH: WE ONLY EXPECT SHORT SENTENCES FROM
      * THE AUTH SERVER.
      *---------------------------------------------------------------
       FD  REQ-FILE.
       01  REQ-REC                 PIC X(400).
       FD  CODE-FILE.
       01  CODE-REC                PIC X(20).
       FD  RESP-FILE.
       01  RESP-REC                PIC X(1000).
