*** Settings ***
Documentation    Day 13 - page objects: move locators and actions out of the tests.
...              Days 11-12 put selectors directly in the tests. That does not scale:
...              one changed id means editing every test. Here the login page lives in
...              resources/login_page.resource and the tests only describe BEHAVIOUR.
...              Also revisits data-driven testing (Day 7) applied to a real UI.
...              Run:  robot --outputdir results tests/web/13_page_objects.robot
Library          Browser
Resource         ../../resources/login_page.resource
Suite Setup      New Browser    chromium    headless=${HEADLESS}
Suite Teardown   Close Browser
Test Setup       New Page    ${BASE_URL}
Test Tags        web    login


*** Variables ***
# ${BASE_URL} and the credentials come from login_page.resource - not redefined here.
${HEADLESS}      True


*** Test Cases ***
A User Can Log In And Log Out
    [Documentation]    Full happy path, written entirely in page-object keywords.
    ...                Notice: not a single CSS selector in this test.
    [Tags]    smoke
    Open Login Page
    Login With Valid Credentials
    Login Should Have Succeeded
    Logout

A Wrong Password Is Rejected
    [Documentation]    Negative case reusing the same keywords with different data.
    [Tags]    negative
    Open Login Page
    Login With    ${VALID_USER}    definitely-not-the-password
    Login Should Have Failed With    Your password is invalid!

An Unknown User Is Rejected
    [Documentation]    Different failure, different message - the site distinguishes them.
    [Tags]    negative
    Open Login Page
    Login With    ghost-user    ${VALID_PASSWORD}
    Login Should Have Failed With    Your username is invalid!

Invalid Logins Are Rejected
    [Documentation]    Data-driven: one keyword, many rows of data (Day 7 style).
    ...                Each row below runs as its own check - all of them run even if
    ...                an earlier one fails, so you see every problem in one go.
    [Tags]    negative    data-driven
    [Template]    Invalid Login Shows Message
    ghost-user       ${VALID_PASSWORD}    Your username is invalid!
    ${VALID_USER}    wrong-password       Your password is invalid!
    ${EMPTY}         ${EMPTY}             Your username is invalid!
    TOMSMITH         ${VALID_PASSWORD}    Your username is invalid!

The Secure Page Is Not Reachable Without Logging In
    [Documentation]    Security-ish check: going straight to /secure must bounce you back.
    [Tags]    negative    access
    Go To    ${BASE_URL}/secure
    Get Text    ${FLASH_MESSAGE}    contains    You must login to view the secure area!


*** Keywords ***
Invalid Login Shows Message
    [Documentation]    The template keyword: one row of test data -> one attempt.
    ...                Lives here (not in the resource) because it is only useful
    ...                to this suite - resources hold what OTHER suites would reuse too.
    [Arguments]    ${username}    ${password}    ${expected_message}
    Open Login Page
    Login With    ${username}    ${password}
    Login Should Have Failed With    ${expected_message}
