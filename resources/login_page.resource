*** Settings ***
Documentation    Page Object for the login page of https://the-internet.herokuapp.com
...              A "page object" keeps LOCATORS and ACTIONS for one page in one file.
...              Why: when the page changes, you fix the selector HERE, not in 20 tests.
...              Tests then read like plain English: "Login With    tomsmith    ...".
Library          Browser


*** Variables ***
${BASE_URL}             https://the-internet.herokuapp.com
# --- Locators: every selector this page needs, named once. -----------------
${LOGIN_URL}            ${BASE_URL}/login
${USERNAME_FIELD}       id=username
${PASSWORD_FIELD}       id=password
${SUBMIT_BUTTON}        button[type=submit]
${FLASH_MESSAGE}        id=flash
# "text=Logout" would also match the paragraph mentioning logout - be specific.
${LOGOUT_BUTTON}        a[href="/logout"]
# --- Known-good credentials for this practice site. ------------------------
${VALID_USER}           tomsmith
${VALID_PASSWORD}       SuperSecretPassword!


*** Keywords ***
Open Login Page
    [Documentation]    Navigates to the login page and confirms we really got there.
    Go To    ${LOGIN_URL}
    Get Text    h2    ==    Login Page

Login With
    [Documentation]    One action, two arguments: fill both fields and submit.
    ...                This is the keyword every login test will reuse.
    [Arguments]    ${username}    ${password}
    Fill Text    ${USERNAME_FIELD}    ${username}
    Fill Text    ${PASSWORD_FIELD}    ${password}
    Click    ${SUBMIT_BUTTON}

Login With Valid Credentials
    [Documentation]    Convenience wrapper: the happy path, no arguments needed.
    ...                Useful as a Test Setup for tests that start "already logged in".
    Login With    ${VALID_USER}    ${VALID_PASSWORD}

Login Should Have Succeeded
    [Documentation]    Assertion keyword: we are on /secure and the banner confirms it.
    ${url}=    Get Url
    Should End With    ${url}    /secure
    Get Text    ${FLASH_MESSAGE}    contains    You logged into a secure area!

Login Should Have Failed With
    [Documentation]    Assertion keyword for negative cases.
    ...                Checks the error text AND that we were NOT let in.
    [Arguments]    ${expected_message}
    Get Text    ${FLASH_MESSAGE}    contains    ${expected_message}
    ${url}=    Get Url
    Should End With    ${url}    /login

Logout
    [Documentation]    Clicks Logout and verifies we are back on the login page.
    Click    ${LOGOUT_BUTTON}
    Get Text    ${FLASH_MESSAGE}    contains    You logged out of the secure area!
