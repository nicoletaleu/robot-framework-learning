*** Settings ***
Documentation    Day 9 - API testing with PUT/PATCH/DELETE.
...              API: https://jsonplaceholder.typicode.com (fake, echoes writes, no auth).
Library          RequestsLibrary
Library          Collections
Suite Setup      Open Api Session


*** Variables ***
${BASE_URL}      https://jsonplaceholder.typicode.com
${SESSION}       jsonplaceholder


*** Test Cases ***
Replace A Post With PUT
    [Documentation]    PUT sends the FULL object to /posts/1. Server echoes it back with 200.
    [Tags]    api    put
    ${payload}=    Create Dictionary    id=${1}    title=Updated title    body=Updated body    userId=${1}
    ${response}=    PUT On Session    ${SESSION}    /posts/1    json=${payload}
    Status Should Be    200    ${response}
    ${updated}=    Set Variable    ${response.json()}
    # The echoed body must reflect the new values we sent.
    Should Be Equal    ${updated}[title]    Updated title
    Should Be Equal    ${updated}[body]     Updated body

Partially Update A Post With PATCH
    [Documentation]    PATCH changes ONLY the fields you send. Here just the title.
    [Tags]    api    patch
    ${payload}=    Create Dictionary    title=Only the title changed
    ${response}=    PATCH On Session    ${SESSION}    /posts/1    json=${payload}
    Status Should Be    200    ${response}
    ${patched}=    Set Variable    ${response.json()}
    # The changed field...
    Should Be Equal    ${patched}[title]    Only the title changed
    # ...and the untouched fields are still there (id stayed 1).
    Should Be Equal As Integers    ${patched}[id]    1

Delete A Post Returns 200
    [Documentation]    DELETE removes /posts/1. This fake API returns 200 + an empty body.
    [Tags]    api    delete
    ${response}=    DELETE On Session    ${SESSION}    /posts/1
    Status Should Be    200    ${response}
    # After a delete the body is empty ({}), so it has no keys.
    ${body}=    Set Variable    ${response.json()}
    Should Be Empty    ${body}


*** Keywords ***
Open Api Session
    [Documentation]    Suite Setup: open ONE session reused by every test.
    Create Session    ${SESSION}    ${BASE_URL}
