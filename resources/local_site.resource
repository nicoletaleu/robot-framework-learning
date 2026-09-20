*** Settings ***
Documentation    Day 30 - shared setup for the web suites, now that the site is local.
...              Suites 11-15 each opened their own browser against
...              the-internet.herokuapp.com. Day 29 built the replacement; this is
...              where they actually move onto it.
...              One thing changes shape in the process: the base URL is no longer a
...              constant anybody can type. The page server takes whatever port is
...              free, so the URL does not exist until the run starts, and a suite
...              has to be handed it rather than know it. That is closer to how a
...              real environment behaves than a hard-coded address ever was.
Library          Browser
Library          ../libraries/PageServer.py


*** Variables ***
# Headless by default - it is faster and it is what CI does anyway. Watch a run
# with:  robot --variable HEADLESS:False tests/web/
${HEADLESS}      True
# Filled in by Open The Local Site. Empty here on purpose: a suite that somehow
# reads it before setup should fail loudly, not quietly open about:blank.
${BASE_URL}      ${EMPTY}


*** Keywords ***
Open The Local Site
    [Documentation]    Suite Setup: start the page server, publish its URL to the
    ...                suite, and open one browser for all of its tests.
    ${base url}=    Start Page Server
    Set Suite Variable    ${BASE_URL}    ${base url}
    New Browser    chromium    headless=${HEADLESS}

Close The Local Site
    [Documentation]    Suite Teardown. The server is stopped even if closing the
    ...                browser fails, or a crashed browser would leave a thread and
    ...                a port behind for the rest of the run.
    Run Keyword And Ignore Error    Close Browser
    Stop Page Server

Open A Fresh Page
    [Documentation]    Test Setup: a new context, so each test starts with its own
    ...                cookies. Without it the login suites pass or fail depending
    ...                on the order they run in - Day 24's trap, and the reason
    ...                --randomize tests is worth running now and then.
    [Arguments]    ${path}=${EMPTY}
    New Context
    New Page    ${BASE_URL}${path}
