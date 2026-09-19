*** Settings ***
Documentation    Day 9 - the write verbs (PUT/PATCH/DELETE) and custom headers.
...              Day 28 moved it off the internet, and the header tests are where the
...              rewrite paid for itself. They used to send a header and assert the
...              response was 200 - which it would have been with no header at all.
...              Against the stub the request itself is visible, so they now assert
...              the header actually left. Same for PATCH: the whole point of PATCH is
...              that it sends only the fields that change, and that is a fact about
...              the request, invisible from any response.
...              One live call remains, tagged `contract`.
...              Run:  robot --outputdir results tests/api/09_api_crud_and_headers.robot
Library          RequestsLibrary
Library          Collections
Resource         ../../resources/stubbed_api.resource
Suite Setup      Start The Stubbed Api
Suite Teardown   Stop The Stubbed Api
Test Setup       Clear Stub Requests
Test Tags        api


*** Test Cases ***
Put Sends The Whole Resource
    [Documentation]    PUT replaces everything, so every field has to be in the body.
    ...                echo=True sends the request back as the response, so the first
    ...                half is not this test reading its own canned answer.
    [Tags]    put    update    smoke
    Stub Request    PUT    /posts/1    status=200    echo=${True}
    ${payload}=    Create Dictionary
    ...    id=${1}    title=Updated title    body=Updated body    userId=${1}
    ${response}=    PUT On Session    ${STUB}    /posts/1    json=${payload}
    Status Should Be    200    ${response}
    Should Be Equal    ${response.json()}[title]    Updated title

    ${sent}=    The Only Request    PUT    /posts/1
    ${keys}=    Evaluate    sorted($sent["json"].keys())
    Should Be Equal    ${keys}    ${{ ["body", "id", "title", "userId"] }}

Patch Sends Only The Fields That Change
    [Documentation]    The actual difference between PATCH and PUT, and it lives in the
    ...                REQUEST. No response can show it, which is why the old version of
    ...                this test could not check it at all.
    [Tags]    patch    update
    Stub Request    PATCH    /posts/1    status=200    echo=${True}    json_body=${{ {"id": 1} }}
    ${payload}=     Create Dictionary    title=Only the title changed
    ${response}=    PATCH On Session    ${STUB}    /posts/1    json=${payload}
    Status Should Be    200    ${response}
    Should Be Equal As Integers    ${response.json()}[id]    1

    ${sent}=    The Only Request    PATCH    /posts/1
    ${keys}=    Evaluate    sorted($sent["json"].keys())
    Should Be Equal    ${keys}    ${{ ["title"] }}

Delete Returns An Empty Body
    [Documentation]    A successful delete has nothing to say, so the body is empty.
    [Tags]    delete
    Stub Request    DELETE    /posts/1    status=200    json_body=${{ {} }}
    ${response}=    DELETE On Session    ${STUB}    /posts/1
    Status Should Be    200    ${response}
    Should Be Empty    ${response.json()}

A Custom Header Actually Leaves The Machine
    [Documentation]    The old test set a header and asserted 200, which would have
    ...                passed with the header removed. This one reads the header off
    ...                the request the server received.
    [Tags]    headers
    Stub Request    GET    /posts/1    status=200    json_body=${{ {} }}
    ${headers}=    Create Dictionary    X-Learning-Day=9    Accept=application/json
    GET On Session    ${STUB}    /posts/1    headers=${headers}
    ${sent}=    The Only Request    GET    /posts/1
    # Header names are case-insensitive in HTTP; the stub lowercases them on the
    # way in so a test never has to guess which casing arrived.
    Should Be Equal    ${sent}[headers][x-learning-day]    9
    Should Be Equal    ${sent}[headers][accept]            application/json

A Bearer Token Actually Leaves The Machine
    [Documentation]    The common auth pattern, and the one worth checking properly:
    ...                a token that is silently dropped looks identical to one that
    ...                was sent, if all you read is the status code.
    [Tags]    headers    auth
    Stub Request    GET    /posts/1    status=200    json_body=${{ {} }}
    ${headers}=    Create Dictionary    Authorization=Bearer my-fake-token-123
    GET On Session    ${STUB}    /posts/1    headers=${headers}
    ${sent}=    The Only Request    GET    /posts/1
    Should Be Equal    ${sent}[headers][authorization]    Bearer my-fake-token-123

The Response Carries Headers Of Its Own
    [Documentation]    Traffic goes both ways. The stub always answers as JSON, which
    ...                is what the client relies on when it calls .json().
    [Tags]    headers
    Stub Request    GET    /posts/1    status=200    json_body=${{ {} }}
    ${response}=    GET On Session    ${STUB}    /posts/1
    Should Contain    ${response.headers}[Content-Type]    application/json

The Real Service Still Accepts A Write The Same Way
    [Documentation]    The single live call left in this suite. It checks the verb is
    ...                still accepted and the echo still matches the written contract -
    ...                not the six things the stub already covers.
    [Tags]    contract
    ${payload}=    Create Dictionary
    ...    id=${1}    title=Updated title    body=Updated body    userId=${1}
    ${response}=    PUT On Session    ${LIVE}    /posts/1    json=${payload}
    Status Should Be    200    ${response}
    Payload Should Match Contract    ${response.json()}    post
