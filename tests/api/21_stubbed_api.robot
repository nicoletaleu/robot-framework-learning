*** Settings ***
Documentation    Day 21 - stubbing the service under test.
...              The suites in this folder call a real API over the internet. That
...              makes them slow, breakable by someone else, and unable to test the
...              interesting cases - a live service will not return 500 on request.
...              A stub is a real HTTP server started inside the run that answers
...              what the test told it to, and records what the client sent.
...              Run:  robot --outputdir results tests/api/21_stubbed_api.robot
Library          RequestsLibrary
Library          Collections
Library          ../../libraries/StubServer.py
Suite Setup      Start The Stub And Open A Session
Suite Teardown   Stop Stub Server
Test Tags        api    stub


*** Variables ***
${SESSION}    stub


*** Test Cases ***
A Stubbed Endpoint Answers Exactly What The Test Asked For
    [Documentation]    No internet involved. The body is the one this test wrote
    ...                two lines earlier, so the assertion cannot drift.
    [Tags]    smoke
    ${body}=    Create Dictionary    id=${1}    title=A stubbed post
    Stub Request    GET    /posts/1    status=200    json_body=${body}
    ${response}=    GET On Session    ${SESSION}    /posts/1
    Status Should Be    200    ${response}
    Should Be Equal As Integers    ${response.json()}[id]    1
    Should Be Equal    ${response.json()}[title]    A stubbed post

An Unstubbed Call Fails Loudly
    [Documentation]    A stub that answered 200 to everything would let a test pass
    ...                while calling the wrong endpoint. Anything unplanned is a 404.
    [Tags]    negative
    ${response}=    GET On Session    ${SESSION}    /nothing/here    expected_status=404
    Should Contain    ${response.json()}[error]    No stub for GET /nothing/here

The Stub Records What The Client Actually Sent
    [Documentation]    The half a live API cannot give me. Not "did I get a 201"
    ...                but "did I send the right body, to the right path".
    [Tags]    smoke
    Clear Stub Requests
    Stub Request    POST    /posts    status=201    json_body=${{ {"id": 101} }}
    ${payload}=     Create Dictionary    title=Day 21    userId=${1}
    ${response}=    POST On Session    ${SESSION}    /posts    json=${payload}
    Status Should Be    201    ${response}

    ${sent}=    Requests Received    POST    /posts
    Length Should Be    ${sent}    1
    Should Be Equal    ${sent}[0][json][title]    Day 21
    Should Be Equal As Integers    ${sent}[0][json][userId]    1
    # RequestsLibrary sets this because of json=; nobody wrote it in the test.
    Should Be Equal    ${sent}[0][headers][content-type]    application/json

Query Parameters Arrive The Way The Client Built Them
    [Documentation]    params= is a dict on my side; this is what came out the other end.
    Clear Stub Requests
    Stub Request    GET    /posts    status=200    json_body=${{ [] }}
    ${params}=    Create Dictionary    userId=1
    GET On Session    ${SESSION}    /posts    params=${params}
    ${sent}=    Requests Received    GET    /posts
    Should Be Equal    ${sent}[0][query][userId][0]    1

A Server Error Happens On Request
    [Documentation]    The reason stubs exist. There is no way to make a live API
    ...                return 500 on a Tuesday afternoon, so this path never got tested.
    [Tags]    smoke    negative
    Stub Request    GET    /posts/500    status=500    json_body=${{ {"error": "boom"} }}
    ${response}=    GET On Session    ${SESSION}    /posts/500    expected_status=500
    Status Should Be    500    ${response}
    Should Be Equal    ${response.json()}[error]    boom

A Slow Response Trips The Client Timeout
    [Documentation]    delay= holds the answer back, so the timeout is real but the
    ...                test still takes a tenth of a second.
    ...                max_retries=0 is the point here: RequestsLibrary retries three
    ...                times by default, so without it a service that times out
    ...                intermittently looks healthy and the test just runs slower.
    ...                Its own session too - a timed-out connection is not something
    ...                to hand to the next test.
    [Tags]    negative
    Stub Request    GET    /posts/slow    status=200    json_body=${{ {} }}    delay=0.6
    Create Session    slow    ${BASE URL}    max_retries=0
    Run Keyword And Expect Error    *Read timed out*
    ...    GET On Session    slow    /posts/slow    timeout=0.1

A Stub Will Happily Lie
    [Documentation]    The honest limit. The stub returns a shape the real API never
    ...                returns, and every assertion still passes - because a stub
    ...                tests my client, never the service. That is what the handful
    ...                of tests against the live API are still for.
    Stub Request    GET    /posts/2    status=200    json_body=${{ {"nonsense": True} }}
    ${response}=    GET On Session    ${SESSION}    /posts/2
    Status Should Be    200    ${response}
    Dictionary Should Not Contain Key    ${response.json()}    id

The Port Is Handed Out At Runtime
    [Documentation]    Day 18: a hard-coded port is shared state, and two pabot
    ...                workers would fight over it. Port 0 asks the OS for a free one.
    Should Start With    ${BASE URL}    http://127.0.0.1:
    ${port}=    Evaluate    int($BASE_URL.rsplit(":", 1)[1])
    Should Be True    ${port} > 0


*** Keywords ***
Start The Stub And Open A Session
    [Documentation]    Suite Setup: one server and one session for the whole suite.
    ${base url}=    Start Stub Server
    Set Suite Variable    ${BASE URL}    ${base url}
    Create Session    ${SESSION}    ${base url}
