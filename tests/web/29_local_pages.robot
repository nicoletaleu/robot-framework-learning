*** Settings ***
Documentation    Day 29 - the pages the web suites need, served from this repo.
...              Suites 11-15 used to drive the-internet.herokuapp.com. After Day 28
...              that was the last thing here depending on someone else being up, and
...              it was the expensive kind: an API call that fails is one red test, a
...              page that fails to load takes a whole browser suite with it.
...              So data/pages/ holds the pages and libraries/PageServer.py serves
...              them. This suite tests the fixture itself. That is not ceremony - a
...              broken fixture does not announce itself, it just makes the suite that
...              uses it look broken, and I would spend the morning reading the wrong
...              log.html.
...              Day 30 moved suites 11-15 onto it, so every check below now has five
...              suites standing on it.
...              Run:  robot --outputdir results tests/web/29_local_pages.robot
Library          Browser
Library          RequestsLibrary
Library          OperatingSystem
# Append To List lives here, and the only place it is called is inside an IF
# that never ran while every page was being served. --dryrun found it: without
# this import, the first missing page would have crashed the test that exists
# to name it.
Library          Collections
Library          ../../libraries/PageServer.py
Suite Setup      Start The Local Site
Suite Teardown   Stop The Local Site
# A fresh context per test = fresh cookies. Without it the login tests below
# would pass or fail depending on their order, which is the Day 24 trap.
Test Setup       New Context
Test Tags        web    local


*** Variables ***
${HEADLESS}      True
${SITE}          site
# Every page suites 11-15 open. /secure is deliberately not here: logged out it
# redirects to /login and would answer 200 without existing at all, so it is
# checked properly by the login tests instead.
@{REQUIRED PAGES}
...    /
...    /login
...    /dropdown
...    /checkboxes
...    /tables
...    /dynamic_loading/1
...    /dynamic_loading/2
...    /dynamic_controls
...    /javascript_alerts
...    /iframe
...    /iframe_content
...    /windows
...    /windows/new
...    /upload


*** Test Cases ***
Every Page The Web Suites Need Is Served
    [Documentation]    A plain HTTP check, no browser: a missing page should fail here
    ...                with its own name in the message, not four suites later as
    ...                "Timeout waiting for selector id=dropdown".
    [Tags]    smoke
    ${missing}=    Create List
    FOR    ${path}    IN    @{REQUIRED PAGES}
        ${response}=    GET On Session    ${SITE}    ${path}    expected_status=any
        IF    ${response.status_code} != 200
            Append To List    ${missing}    ${path} (${response.status_code})
        END
    END
    Should Be Empty    ${missing}    Not served from ${PAGES DIR}: ${missing}

A Page Outside The Pages Directory Is Not Served
    [Documentation]    The server turns a URL into a file path, so a URL that climbs
    ...                out of data/pages/ would hand back the rest of the repo.
    ...                The probe file is created for this test because the check is
    ...                worthless against a path that does not exist - a 404 would then
    ...                prove nothing.
    ...                Note %2f rather than a plain slash: requests tidies "/../x" into
    ...                "/x" before it ever leaves, so the encoded form is the only way
    ...                to put the traversal in front of the server.
    ${probe}=    Set Variable    ${CURDIR}${/}..${/}..${/}traversal_probe.html
    Create File    ${probe}    <p>this file is not in data/pages</p>
    ${response}=    GET On Session    ${SITE}    /..%2f..%2ftraversal_probe
    ...    expected_status=any
    Should Be Equal As Integers    ${response.status_code}    404
    Should Not Contain    ${response.text}    not in data/pages
    [Teardown]    Remove File    ${probe}

The Home Page Is The One The Suites Expect
    [Documentation]    Suite 11 asserts on this title and this heading, so they are
    ...                part of the fixture's job rather than decoration.
    [Tags]    smoke
    New Page    ${SITE URL}
    Get Title    ==    The Internet
    Get Text     h1    ==    Welcome to the-internet
    Get Element Count    a >> text=Form Authentication    ==    1

A Valid Login Lands On The Secure Page
    [Documentation]    The form post, the redirect and the flash message - the three
    ...                pieces a static file cannot provide, which is why PageServer
    ...                handles login itself.
    New Page    ${SITE URL}/login
    Log In As    tomsmith    SuperSecretPassword!
    ${url}=    Get Url
    Should End With    ${url}    /secure
    Get Text    id=flash    contains    You logged into a secure area!

The Two Login Failures Are Told Apart
    [Documentation]    An unknown user and a wrong password give different messages.
    ...                Suite 13 has a data-driven test built on exactly that
    ...                distinction, so collapsing both into one message here would
    ...                quietly break it.
    New Page    ${SITE URL}/login
    Log In As    ghost-user    SuperSecretPassword!
    Get Text    id=flash    contains    Your username is invalid!
    Log In As    tomsmith    definitely-not-the-password
    Get Text    id=flash    contains    Your password is invalid!

A Flash Message Is Shown Once And Then Cleared
    [Documentation]    A flash belongs to one response. If it stuck around, a later
    ...                test could read the previous test's message and pass for the
    ...                wrong reason - the worst kind of green.
    New Page    ${SITE URL}/login
    Log In As    tomsmith    SuperSecretPassword!
    Get Text    id=flash    contains    You logged into a secure area!
    Go To    ${SITE URL}/secure
    Get Element Count    id=flash    ==    0

The Secure Page Is Not Reachable Without Logging In
    [Documentation]    Not a security test - the session cookie here is the username
    ...                in plain text. It pins the redirect, which is the behaviour
    ...                suite 13 drives.
    New Page    ${SITE URL}/secure
    ${url}=    Get Url
    Should End With    ${url}    /login
    Get Text    id=flash    contains    You must login to view the secure area!

A Hidden Element Is Revealed By The Page's Own Script
    [Documentation]    The waiting pages have to actually wait, or suite 15 becomes
    ...                seven tests that pass instantly and teach nothing.
    New Page    ${SITE URL}/dynamic_loading/1
    Get Element States    id=finish    contains    hidden
    Click    css=#start button
    Wait For Elements State    id=finish    visible    timeout=10s
    Get Text    id=finish    ==    Hello World!

The Iframe Really Is A Separate Document
    [Documentation]    Suite 14's point is that an iframe has its own DOM. If the
    ...                fixture put that text on the outer page too, the suite would
    ...                pass without the iframe ever being entered.
    New Page    ${SITE URL}/iframe
    Wait For Elements State    id=mce_0_ifr >>> p    visible    timeout=10s
    Get Text    id=mce_0_ifr >>> p    ==    Your content goes here.
    ${outer}=    Get Text    body
    Should Not Contain    ${outer}    Your content goes here.


*** Keywords ***
Start The Local Site
    [Documentation]    Suite Setup: the server, a browser, and a plain HTTP session
    ...                for the checks that do not need one.
    ${base url}=    Start Page Server
    ${directory}=   Pages Directory
    Set Suite Variable    ${SITE URL}     ${base url}
    Set Suite Variable    ${PAGES DIR}    ${directory}
    Create Session    ${SITE}    ${base url}
    New Browser    chromium    headless=${HEADLESS}

Stop The Local Site
    [Documentation]    Suite Teardown. Both halves run even if the first one fails.
    Run Keyword And Ignore Error    Close Browser
    Stop Page Server

Log In As
    [Documentation]    Fill both fields and submit. Local to this suite on purpose:
    ...                resources/login_page.resource is suite 13's page object and
    ...                Day 30 is where it starts pointing here.
    [Arguments]    ${username}    ${password}
    Fill Text    id=username    ${username}
    Fill Text    id=password    ${password}
    Click        button[type=submit]
