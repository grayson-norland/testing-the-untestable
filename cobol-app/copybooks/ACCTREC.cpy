      *---------------------------------------------------------------
      * ACCTREC - ONE ACCOUNT, AS A MAINFRAME WOULD HAVE LIKED IT:
      * FIXED WIDTHS, NO NEGOTIATION.
      *---------------------------------------------------------------
       01  ACCT-REC.
      * 'ACC' + 3 DIGITS.
           05  ACCT-CODE           PIC X(6).
      * THE NAME, IN A FIELD OF FIXED WIDTH. THE PEOPLE WHO HAVE
      * THE NAMES WERE NOT CONSULTED ABOUT THE WIDTH.
           05  ACCT-NAME           PIC X(25).
      * TWO-CHARACTER STATUS CODE, KEPT AS TEXT AND NOT TRANSLATED.
           05  ACCT-STATUS         PIC X(2).
      * 9 DIGITS, 2 DECIMALS, SIGNED. THE V IS AN IMAGINARY DECIMAL
      * POINT: IT TAKES NO SPACE IN THE RECORD AND NO RESPONSIBILITY.
           05  ACCT-BALANCE        PIC S9(9)V99.
      * YYYY-MM-DD, KEPT AS TEXT.
           05  ACCT-OPENED         PIC X(10).
      * THREE CHARACTERS. LEADING ZEROS ARE PART OF THE DEAL.
           05  ACCT-BRANCH         PIC X(3).
