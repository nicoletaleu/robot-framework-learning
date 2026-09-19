*** Settings ***
Documentation    Day 28 - shared setup for the API suites that used to call the internet.
...              Suites 08, 09 and 10 each opened a session against
...              jsonplaceholder.typicode.com and ran every test through it. That made
...              a push depend on somebody else's uptime, and it quietly limited what
...              the tests could check: a live service answers how it likes, so the
...              only questions available were "did it say 200" and "does the body
...              have this key".
...              Now each suite gets two sessions. ${STUB} is the Day 21 stub server,
...              offline, where the responses are the test's to choose and the
...              REQUEST can be inspected. ${LIVE} is the real service, used only by
...              the handful of tests tagged `contract`, which run on a schedule.
Library          RequestsLibrary
Library          ../libraries/StubServer.py
Library          ../libraries/ContractHelpers.py
Library          Collections


*** Variables ***
${STUB}        stub
${LIVE}        live
${LIVE URL}    https://jsonplaceholder.typicode.com


*** Keywords ***
Start The Stubbed Api
    [Documentation]    Suite Setup for 08, 09 and 10. Starts the stub on a free port
    ...                and opens both sessions.
    ${base url}=    Start Stub Server
    Set Suite Variable    ${STUB URL}    ${base url}
    Create Session    ${STUB}    ${base url}
    # verify=${True} is not the default; RequestsLibrary accepts any certificate
    # unless told otherwise. The stub is plain http and needs none.
    Create Session    ${LIVE}    ${LIVE URL}    verify=${True}

Stop The Stubbed Api
    [Documentation]    Suite Teardown. Safe when the stub never started.
    Stop Stub Server

The Only Request
    [Documentation]    The single request the stub saw for this method and path,
    ...                failing clearly when there was none or more than one.
    ...                Pair it with Clear Stub Requests at the top of a test.
    [Arguments]    ${method}    ${path}
    ${received}=    Requests Received    ${method}    ${path}
    Length Should Be    ${received}    1
    ...    Expected exactly one ${method} ${path}, got ${received}
    RETURN    ${received}[0]
