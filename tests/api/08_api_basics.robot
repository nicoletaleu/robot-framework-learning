*** Settings ***
Documentation    Day 8 - API testing with RequestsLibrary.
...              Make real HTTP calls and check the status code + JSON body.
...              Target API: https://jsonplaceholder.typicode.com (free, no auth).
...              Run with:  robot --outputdir results tests/api/08_api_basics.robot
Library          RequestsLibrary
Library          Collections
Suite Setup      Open Api Session


*** Variables ***
${BASE_URL}      https://jsonplaceholder.typicode.com
${SESSION}       jsonplaceholder


*** Test Cases ***
Get A Single Post Returns 200
    [Documentation]    Simplest GET: fetch /posts/1 and check the status code.
    [Tags]    smoke    api
    ${response}=    GET On Session    ${SESSION}    /posts/1
    Status Should Be    200    ${response}

Get A Single Post Has Expected Fields
    [Documentation]    Parse the JSON body into a dictionary and inspect it.
    [Tags]    api
    ${response}=    GET On Session    ${SESSION}    /posts/1
    ${body}=    Set Variable    ${response.json()}
    # The JSON body is just a dictionary (Day 4).
    Should Be Equal As Integers    ${body}[id]    1
    Dictionary Should Contain Key    ${body}    title
    Dictionary Should Contain Key    ${body}    body

Get All Posts Returns A List
    [Documentation]    /posts returns a LIST of 100 items: check count + loop.
    [Tags]    api
    ${response}=    GET On Session    ${SESSION}    /posts
    ${posts}=    Set Variable    ${response.json()}
    Length Should Be    ${posts}    100
    FOR    ${post}    IN    @{posts}[:5]
        Dictionary Should Contain Key    ${post}    id
    END

Get With Query Parameters
    [Documentation]    Pass query params (?userId=1) via 'params='.
    [Tags]    api
    ${params}=    Create Dictionary    userId=1
    ${response}=    GET On Session    ${SESSION}    /posts    params=${params}
    Status Should Be    200    ${response}
    FOR    ${post}    IN    @{response.json()}
        Should Be Equal As Integers    ${post}[userId]    1
    END

Get A Missing Post Returns 404
    [Documentation]    Negative test. Pass expected_status=404 so a 4xx is OK,
    ...                not a failure (the default for RequestsLibrary).
    [Tags]    api    negative
    ${response}=    GET On Session    ${SESSION}    /posts/99999    expected_status=404
    Status Should Be    404    ${response}

Create A Post With POST
    [Documentation]    Send a JSON payload with POST. Returns 201 + echoes it back.
    [Tags]    api
    ${payload}=    Create Dictionary    title=Day 8    body=Learning API testing    userId=${1}
    ${response}=    POST On Session    ${SESSION}    /posts    json=${payload}
    Status Should Be    201    ${response}
    ${created}=    Set Variable    ${response.json()}
    # The echoed body must match what we sent.
    Should Be Equal    ${created}[title]    Day 8
    Should Be Equal    ${created}[body]     Learning API testing


*** Keywords ***
Open Api Session
    [Documentation]    Suite Setup: open ONE session (alias + base URL) reused by every test.
    Create Session    ${SESSION}    ${BASE_URL}
