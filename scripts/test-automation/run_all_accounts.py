#!/usr/bin/env python3
# ---------------------------------------------------------------------------
# Regression check: drives the actual screen, account by account, the way a
# person would. Signs on, searches, reads the result, signs off. Repeats for
# every account we've got. Leave it running and go and do something else.
#
# Written in a hurry when the manual regression pack got too big to run
# by hand before every release. It has not needed much attention since,
# which either means it works or means nobody has looked closely.
#
# Needs Chrome and `pip install -r requirements.txt`. Then:
#     python3 run_all_accounts.py
# ---------------------------------------------------------------------------
import time
from selenium import webdriver
from selenium.webdriver.common.by import By

BASE_URL = "http://localhost:8085/"

# The one login we've got. Same as the root README.
USERNAME = "test_user"
PASSWORD = "TestPass123"

ACCOUNTS = ["ACC%03d" % n for n in range(1, 51)]

# Old chromedriver checkout from whoever set this up originally. Selenium
# finds its own driver now, so this isn't read anymore, but nobody's
# checked what else might depend on it being here, so it stays.
CHROMEDRIVER_PATH = "/usr/local/bin/chromedriver-2019"

# Leave the browser visible. Screenshots come out blank if you run this
# headless on some machines and it's not worth chasing why.
HEADLESS = False

# How long to give each step before we assume it's done. These were
# timed against one laptop, once. Turn them up if the run starts
# failing on yours; turn them down and you'll see why they're this size.
PAGE_LOAD_WAIT = 3
LOGIN_WAIT = 4
NAV_WAIT = 1
SEARCH_WAIT = 5
SIGNOFF_WAIT = 2

SCREENSHOT_DIR = "screenshots"


def new_browser():
    opts = webdriver.ChromeOptions()
    if HEADLESS:
        opts.add_argument("--headless=new")
    opts.add_argument("--window-size=1024,768")
    return webdriver.Chrome(options=opts)


def sign_on(driver):
    driver.get(BASE_URL)
    time.sleep(PAGE_LOAD_WAIT)
    driver.find_element(By.LINK_TEXT, "Sign On").click()
    time.sleep(NAV_WAIT)
    driver.find_element(By.ID, "f-user").send_keys(USERNAME)
    driver.find_element(By.ID, "f-pass").send_keys(PASSWORD)
    # There's no id on the button, and the label is the only thing to
    # go on. If wording ever changes, this line is the first to know.
    driver.find_element(By.XPATH, "//button[text()='Sign On']").click()
    time.sleep(LOGIN_WAIT)  # enough time for the token to come back, usually


def search_and_read(driver, account_code):
    driver.find_element(By.LINK_TEXT, "Account Search").click()
    time.sleep(NAV_WAIT)
    field = driver.find_element(By.ID, "f-acct")
    field.clear()
    field.send_keys(account_code)
    driver.find_element(By.XPATH, "//button[text()='Search']").click()
    # The "Please wait" message is removed once the answer is in, but
    # polling for that felt like overkill for a page this small.
    time.sleep(SEARCH_WAIT)

    # Whatever came back is one row per field, in the order the host
    # sends them. A found account is six rows (number, name, status,
    # balance, date, branch); anything else - not found, a locked
    # account, a diagnostic message - is however many rows the host
    # felt like sending, and reading those by position instead of by
    # label is what was making this "randomly" blow up on exactly the
    # accounts that don't come back as a plain hit.
    rows = driver.find_elements(By.CSS_SELECTOR, "table.data tr")
    record = {}
    for r in rows:
        label = r.find_element(By.TAG_NAME, "th").text
        value = r.find_element(By.TAG_NAME, "td").text
        record[label] = value
    return record


def sign_off(driver):
    driver.find_element(By.LINK_TEXT, "Sign Off").click()
    time.sleep(SIGNOFF_WAIT)


def screenshot(driver, account_code):
    import os
    os.makedirs(SCREENSHOT_DIR, exist_ok=True)
    driver.save_screenshot(os.path.join(SCREENSHOT_DIR, account_code + ".png"))


def run_one(account_code):
    driver = new_browser()
    try:
        sign_on(driver)
        record = search_and_read(driver, account_code)
        screenshot(driver, account_code)
        sign_off(driver)
        driver.quit()
        print("PASS", account_code, record)
        return True
    except Exception as e:
        # Whatever went wrong, note it and carry on to the next account
        # rather than stop the whole run over one bad one.
        print("FAIL", account_code, "-", e)
        return False


def main():
    started = time.time()
    passed = 0
    for code in ACCOUNTS:
        if run_one(code):
            passed += 1
    elapsed = time.time() - started
    print()
    print("%d/%d accounts completed without an exception, in %.0f seconds."
          % (passed, len(ACCOUNTS), elapsed))


if __name__ == "__main__":
    main()
