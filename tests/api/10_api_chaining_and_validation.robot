*** Settings ***
Documentation    Day 10 - chaining requests, and checking the shape of what comes back.
...              Day 28 moved it off the internet. Chaining is entirely a client-side
...              affair - read a field out of one response, put it in the next URL -
...              so a stub tests it as well as a live service does, and without the
...              wait. The shape check got better rather than merely offline: it used
...              to hand-roll type assertions, and now it validates against
...              data/contracts/user.json, the same file the nightly contract test
...              holds the real service to.
...              Two live calls remain, both tagged `contract`.
...              Run:  robot --outputdir results tests/api/10_api_chaining_and_validation.robot
Library          RequestsLibrary
Library          Collections
Resource         ../../resources/stubbed_api.resource
Suite Setup      Set Up The Chain
Suite Teardown   Stop The Stubbed Api
Test Tags        api


*** Test Cases ***
Capture An Id And Reuse It In The Next Request
    [Documentation]    The chain itself: a field out of response one becomes part of
    ...                the URL of response two.
    [Tags]    chaining    smoke
    ${post}=       GET On Session    ${STUB}    /posts/1
    ${user id}=    Set Variable      ${post.json()}[userId]
    ${user}=       GET On Session    ${STUB}    /users/${user id}
    Status Should Be    200    ${user}
    Should Be Equal As Integers    ${user.json()}[id]    ${user id}

Fetch A User And Remember It
    [Documentation]    Set Suite Variable puts a value where later tests can read it.
    ...                Note what this costs: the test below now depends on this one
    ...                having run, which is the Day 24 trap written on purpose.
    [Tags]    chaining    state
    ${response}=    GET On Session    ${STUB}    /users/1
    ${email}=       Set Variable      ${response.json()}[email]
    Set Suite Variable    ${SHARED EMAIL}    ${email}
    Should Not Be Empty    ${SHARED EMAIL}

Reuse The Remembered User Data
    [Documentation]    Reads the suite variable rather than making a request. Run this
    ...                test on its own and it fails - which is exactly what Day 24
    ...                taught me to look for, and the reason Set Suite Variable is a
    ...                tool to reach for rarely.
    [Tags]    chaining    state
    Should Contain    ${SHARED EMAIL}    @

Walk A Chain Of Related Resources
    [Documentation]    Three hops: a post gives an author, the author gives their
    ...                posts, and every one of those must belong to them.
    [Tags]    chaining
    ${post}=         GET On Session    ${STUB}    /posts/1
    ${author id}=    Set Variable      ${post.json()}[userId]
    ${params}=       Create Dictionary    userId=${author id}
    ${their posts}=  GET On Session    ${STUB}    /posts    params=${params}
    Status Should Be    200    ${their posts}
    ${ids}=    Create List
    FOR    ${p}    IN    @{their posts.json()}
        Should Be Equal As Integers    ${p}[userId]    ${author id}
        Append To List    ${ids}    ${p}[id]
    END
    List Should Contain Value    ${ids}    ${1}
    # And the filter really left the machine, which the response alone cannot show.
    # As Integers, because a query string is text: the author id is a number on
    # this side of the wire and the characters "1" on the other.
    ${sent}=    The Only Request    GET    /posts
    Should Be Equal As Integers    ${sent}[query][userId][0]    ${author id}

The Shape Of A Response Is Checked Against The Written Contract
    [Documentation]    This used to hand-roll its type checks: fetch the body, evaluate
    ...                type(id).__name__, compare to "int". That works and it drifts -
    ...                the rules lived in this one test and nowhere else. Now it uses
    ...                data/contracts/user.json, so the stub here and the real service
    ...                on the nightly run are held to exactly the same description.
    [Tags]    validation    smoke
    ${user}=    GET On Session    ${STUB}    /users/1
    Payload Should Match Contract    ${user.json()}    user
    # Nested objects are part of the contract too, not an afterthought.
    Dictionary Should Contain Key    ${user.json()}[address]    city

The Real Service Still Sends A User The Tests Would Recognise
    [Documentation]    The live half of the test above. If jsonplaceholder ever drops
    ...                a field, this is what says so - and it says it on the nightly
    ...                run, not in the middle of someone's pull request.
    [Tags]    contract    validation
    ${user}=    GET On Session    ${LIVE}    /users/1
    Status Should Be    200    ${user}
    Payload Should Match Contract    ${user.json()}    user

A Created Resource Is Not Persisted
    [Documentation]    A fact about the real service, so it stays a real call. It
    ...                answers 201 with id 101 and stores nothing, so the id cannot be
    ...                read back - Day 22's point, discovered here first.
    ...                Stubbing this would be circular: the test would program both the
    ...                201 and the 404 and then assert them.
    [Tags]    contract    chaining    negative
    ${payload}=    Create Dictionary    title=Day 10    body=chaining    userId=${1}
    ${created}=    POST On Session    ${LIVE}    /posts    json=${payload}
    Status Should Be    201    ${created}
    ${new id}=    Set Variable    ${created.json()}[id]
    ${lookup}=    GET On Session    ${LIVE}    /posts/${new id}    expected_status=404
    Status Should Be    404    ${lookup}


*** Keywords ***
Set Up The Chain
    [Documentation]    Suite Setup: the shared stub and sessions, plus the three
    ...                responses this suite's chain walks through.
    Start The Stubbed Api
    ${user}=    Create Dictionary
    ...    id=${1}    name=Leanne Graham    username=Bret    email=Sincere@april.biz
    ...    address=${{ {"city": "Gwenborough"} }}
    Stub Request    GET    /users/1    status=200    json_body=${user}
    Stub Request    GET    /posts/1    status=200
    ...    json_body=${{ {"userId": 1, "id": 1, "title": "a post", "body": "words"} }}
    Stub Request    GET    /posts     status=200
    ...    json_body=${{ [{"userId": 1, "id": 1, "title": "a post", "body": "words"}, {"userId": 1, "id": 7, "title": "another", "body": "more"}] }}
