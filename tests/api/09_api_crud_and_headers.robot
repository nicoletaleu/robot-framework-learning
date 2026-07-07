*** Settings ***
Documentation    Day 9 - CRUD verbs PUT/PATCH/DELETE + custom headers.
...              API: https://jsonplaceholder.typicode.com (fake, echoes writes, no auth).
Library          RequestsLibrary
Library          Collections
Suite Setup      Open Api Session


*** Variables ***
${BASE_URL}      https://jsonplaceholder.typicode.com
${SESSION}       jsonplaceholder


*** Test Cases ***
Update A Post Fully With PUT
    [Documentation]    PUT replaces the WHOLE resource; returns 200 + echoed body.
    [Tags]    api    update
    ${payload}=    Create Dictionary    id=${1}    title=Updated title    body=New body    userId=${1}
    ${response}=    PUT On Session    ${SESSION}    /posts/1    json=${payload}
    Status Should Be    200    ${response}
    ${updated}=    Set Variable    ${response.json()}
    Should Be Equal    ${updated}[title]    Updated title
    Should Be Equal    ${updated}[body]     New body

Update A Post Partially With PATCH
    [Documentation]    PATCH updates only the fields sent (here the title); the rest stay. Differs from PUT.
    [Tags]    api    update
    ${payload}=    Create Dictionary    title=Only the title changed
    ${response}=    PATCH On Session    ${SESSION}    /posts/1    json=${payload}
    Status Should Be    200    ${response}
    Should Be Equal    ${response.json()}[title]    Only the title changed

Delete A Post Returns 200
    [Documentation]    DELETE removes a resource. jsonplaceholder returns 200 + an empty body.
    [Tags]    api    delete
    ${response}=    DELETE On Session    ${SESSION}    /posts/1
    Status Should Be    200    ${response}

Send A Custom Header
    [Documentation]    Pass extra headers via 'headers=' (tokens, content type, etc.).
    [Tags]    api    headers
    ${headers}=    Create Dictionary    X-Learning-Day=9    Accept=application/json
    ${response}=    GET On Session    ${SESSION}    /posts/1    headers=${headers}
    Status Should Be    200    ${response}

Send A Bearer Token Header
    [Documentation]    The common auth pattern: 'Authorization: Bearer <token>' header.
    [Tags]    api    headers    auth
    ${headers}=    Create Dictionary    Authorization=Bearer my-fake-token-123
    ${response}=    GET On Session    ${SESSION}    /posts/1    headers=${headers}
    Status Should Be    200    ${response}

Inspect The Response Headers
    [Documentation]    Responses have headers too. Check the server sent JSON back.
    [Tags]    api    headers
    ${response}=    GET On Session    ${SESSION}    /posts/1
    Should Contain    ${response.headers}[Content-Type]    application/json


*** Keywords ***
Open Api Session
    [Documentation]    Suite Setup: open ONE session reused by every test.
    Create Session    ${SESSION}    ${BASE_URL}
