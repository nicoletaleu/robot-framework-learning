*** Settings ***
Documentation    Day 8 - API testing with RequestsLibrary: status codes and JSON bodies.
...              Day 28 moved it off the internet. What it used to do was open a
...              session against jsonplaceholder.typicode.com and run every test
...              through it, which made a push depend on someone else's uptime.
...              Rewriting it against the stub forced a better question than
...              "does this still pass": what was each test actually checking?
...              Several were checking the service, not my client - "the list has 100
...              items" is an assertion about somebody else's fixture data. Those are
...              now checks on what the client SENT, which is the half a live API
...              cannot show and the half I am responsible for.
...              One test still calls the real service, tagged `contract`, and runs
...              on a schedule rather than on every push.
...              Run:  robot --outputdir results tests/api/08_api_basics.robot
Library          RequestsLibrary
Library          Collections
Resource         ../../resources/stubbed_api.resource
Suite Setup      Start The Stubbed Api
Suite Teardown   Stop The Stubbed Api
Test Tags        api


*** Variables ***
&{A POST}    userId=${1}    id=${1}    title=A stubbed post    body=some words


*** Test Cases ***
A Get Returns The Status The Server Sent
    [Documentation]    The simplest call there is. Nothing about it needed the
    ...                internet - it needed something that answers 200.
    [Tags]    smoke
    Stub Request    GET    /posts/1    status=200    json_body=${A POST}
    ${response}=    GET On Session    ${STUB}    /posts/1
    Status Should Be    200    ${response}

A Json Body Arrives As A Dictionary
    [Documentation]    The body is a plain dictionary once parsed - Day 4, over HTTP.
    [Tags]    smoke
    Stub Request    GET    /posts/1    status=200    json_body=${A POST}
    ${response}=    GET On Session    ${STUB}    /posts/1
    ${body}=        Set Variable    ${response.json()}
    Should Be Equal As Integers    ${body}[id]    1
    Should Be Equal    ${body}[title]    A stubbed post
    Dictionary Should Contain Key    ${body}    body

A List Response Is Parsed As A List
    [Documentation]    This used to assert the list had 100 items, which was an
    ...                assertion about jsonplaceholder's fixture data and would have
    ...                broken the day they seeded it differently. What is mine to
    ...                check is that a list comes back as a list and can be walked.
    ${posts}=    Evaluate    [{"userId": 1, "id": i, "title": f"post {i}", "body": "x"} for i in range(1, 4)]
    Stub Request    GET    /posts    status=200    json_body=${posts}
    ${response}=    GET On Session    ${STUB}    /posts
    ${parsed}=    Set Variable    ${response.json()}
    Length Should Be    ${parsed}    3
    FOR    ${post}    IN    @{parsed}
        Dictionary Should Contain Key    ${post}    id
    END

Query Parameters Reach The Server
    [Documentation]    The rewrite that changed the most. Before, this filtered on
    ...                userId and checked every result came back with userId 1 - which
    ...                tested the service's filtering, not my request. Now it checks
    ...                what left my machine, which is the part I can break.
    Clear Stub Requests
    Stub Request    GET    /posts    status=200    json_body=${{ [] }}
    ${params}=    Create Dictionary    userId=1
    GET On Session    ${STUB}    /posts    params=${params}
    ${sent}=    The Only Request    GET    /posts
    Should Be Equal    ${sent}[query][userId][0]    1

A Missing Resource Returns 404
    [Documentation]    Negative case. expected_status=404 tells RequestsLibrary the
    ...                4xx is the point, otherwise it raises.
    [Tags]    negative
    Stub Request    GET    /posts/99999    status=404    json_body=${{ {"error": "not found"} }}
    ${response}=    GET On Session    ${STUB}    /posts/99999    expected_status=404
    Status Should Be    404    ${response}

A Post Sends The Body It Was Handed
    [Documentation]    Two different claims, so both are asserted: the client parsed
    ...                the 201 correctly, and the body that left was the one built
    ...                here. echo=True makes the stub send the request back, so the
    ...                first assertion is not just reading what this test typed.
    Clear Stub Requests
    Stub Request    POST    /posts    status=201    json_body=${{ {"id": 101} }}    echo=${True}
    ${payload}=     Create Dictionary    title=Day 8    body=Learning API testing    userId=${1}
    ${response}=    POST On Session    ${STUB}    /posts    json=${payload}
    Status Should Be    201    ${response}
    Should Be Equal    ${response.json()}[title]    Day 8
    Should Be Equal As Integers    ${response.json()}[id]    101

    ${sent}=    The Only Request    POST    /posts
    Should Be Equal    ${sent}[json][title]     Day 8
    Should Be Equal    ${sent}[json][body]      Learning API testing
    Should Be Equal    ${sent}[headers][content-type]    application/json

The Real Service Still Sends A Post The Tests Would Recognise
    [Documentation]    The one thing the stub cannot tell me, kept as a single live
    ...                call instead of six. Tagged `contract`, so it is off every push
    ...                and runs on the nightly schedule - a red run here means the
    ...                stubs above have gone stale, not that a change is broken.
    [Tags]    contract
    ${response}=    GET On Session    ${LIVE}    /posts/1
    Status Should Be    200    ${response}
    Payload Should Match Contract    ${response.json()}    post
