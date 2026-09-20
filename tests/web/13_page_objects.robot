*** Settings ***
Documentation    Day 13 - page objects: move locators and actions out of the tests.
...              Days 11-12 put selectors directly in the tests. That does not scale:
...              one changed id means editing every test. Here the login page lives in
...              resources/login_page.resource and the tests only describe BEHAVIOUR.
...              Day 30 is where the design paid off and where it showed its seam. The
...              suite moved from a public site to a local server on a random port and
...              not one test changed - every edit landed in the page object. The seam
...              is that the page object had been holding the site's address, which is
...              not part of describing a page; that moved out too.
...              What the suite cannot claim, now that the server is mine: it does not
...              test authentication. It tests that these keywords compose, and that
...              the two failure messages stay distinguishable - which
...              tests/web/29_local_pages.robot pins down at the fixture end.
...              Run:  robot --outputdir results tests/web/13_page_objects.robot
Library          Browser
Resource         ../../resources/local_site.resource
Resource         ../../resources/login_page.resource
Suite Setup      Open The Local Site
Suite Teardown   Close The Local Site
Test Setup       Open A Fresh Page
Test Tags        web    login


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
    [Documentation]    Different failure, different message. Worth keeping as its own
    ...                test rather than another row below: it is the one that would
    ...                catch a server collapsing both messages into a single generic
    ...                "login failed".
    [Tags]    negative
    Open Login Page
    Login With    ghost-user    ${VALID_PASSWORD}
    Login Should Have Failed With    Your username is invalid!

Invalid Logins Are Rejected
    [Documentation]    Data-driven: one keyword, many rows of data (Day 7 style).
    ...                Each row below runs as its own check - all of them run even if
    ...                an earlier one fails, so you see every problem in one go.
    ...                The last row is the interesting one: the same name in the wrong
    ...                case is a different user, not the same one.
    [Tags]    negative    data-driven
    [Template]    Invalid Login Shows Message
    ghost-user       ${VALID_PASSWORD}    Your username is invalid!
    ${VALID_USER}    wrong-password       Your password is invalid!
    ${EMPTY}         ${EMPTY}             Your username is invalid!
    TOMSMITH         ${VALID_PASSWORD}    Your username is invalid!

The Secure Page Is Not Reachable Without Logging In
    [Documentation]    Day 13 filed this as a "security-ish check". It is not one, and
    ...                it is less of one now: the session cookie PageServer sets is the
    ...                username in plain text, so anyone could forge it. What it checks
    ...                is the redirect - that a page meant to be behind a login sends
    ...                you to the login instead of rendering. Real access-control
    ...                testing belongs with a real implementation, on the P-track.
    [Tags]    negative    access
    Go To    ${BASE_URL}/secure
    Get Text    ${FLASH_MESSAGE}    contains    You must login to view the secure area!
    ${url}=    Get Url
    Should End With    ${url}    /login


*** Keywords ***
Invalid Login Shows Message
    [Documentation]    The template keyword: one row of test data -> one attempt.
    ...                Lives here (not in the resource) because it is only useful
    ...                to this suite - resources hold what OTHER suites would reuse too.
    [Arguments]    ${username}    ${password}    ${expected_message}
    Open Login Page
    Login With    ${username}    ${password}
    Login Should Have Failed With    ${expected_message}
