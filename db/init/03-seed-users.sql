-- Single login user. The password is stored hashed; crypt() checks it.
INSERT INTO app_users (username, password_hash)
VALUES ('test_user', 'cUKHJGBG86Mwc');
