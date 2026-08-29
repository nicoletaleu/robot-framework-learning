*** Settings ***
Documentation    Day 10 - chaining requests: use a value from one response as input to the next.
...              API: https://jsonplaceholder.typicode.com (fake, no auth).
...              Run:  robot --outputdir results tests/api/10_api_chaining_and_validation.robot
Library          RequestsLibrary
Library          Collections
Suite Setup      Open Api Session


*** Variables ***
${BASE_URL}      https://jsonplaceholder.typicode.com
${SESSION}       jsonplaceholder


*** Test Cases ***
Capture An Id And Reuse It In The Next Request
    [Documentation]    Read a field from response #1, feed it into the URL of response #2.
    [Tags]    api    chaining    smoke
    ${post}=    GET On Session    ${SESSION}    /posts/1
    ${user_id}=    Set Variable    ${post.json()}[userId]
    # Use that id to fetch the matching user - this is the chain.
    ${user}=    GET On Session    ${SESSION}    /users/${user_id}
    Status Should Be    200    ${user}
    Should Be Equal As Integers    ${user.json()}[id]    ${user_id}

Fetch A User And Remember It
    [Documentation]    Save a value with 'Set Suite Variable' so a later test can read it.
    [Tags]    api    chaining    state
    ${response}=    GET On Session    ${SESSION}    /users/1
    ${email}=    Set Variable    ${response.json()}[email]
    # Now lives at suite level, visible to every following test.
    Set Suite Variable    ${SHARED_EMAIL}    ${email}
    Should Not Be Empty    ${SHARED_EMAIL}

Reuse The Remembered User Data
    [Documentation]    Reads the suite variable set by the previous test - no new request needed.
    [Tags]    api    chaining    state
    Should Contain    ${SHARED_EMAIL}    @

Walk A Chain Of Related Resources
    [Documentation]    3-hop chain: post -> its author -> every post that author wrote.
    [Tags]    api    chaining
    # Hop 1 - a post gives us an author id.
    ${post}=    GET On Session    ${SESSION}    /posts/1
    ${author_id}=    Set Variable    ${post.json()}[userId]
    # Hop 2 - all posts written by that author.
    ${params}=    Create Dictionary    userId=${author_id}
    ${their_posts}=    GET On Session    ${SESSION}    /posts    params=${params}
    Status Should Be    200    ${their_posts}
    # Hop 3 - every post returned must belong to that author.
    FOR    ${p}    IN    @{their_posts.json()}
        Should Be Equal As Integers    ${p}[userId]    ${author_id}
    END
    # ...and the original post must be in that list.
    ${ids}=    Create List
    FOR    ${p}    IN    @{their_posts.json()}
        Append To List    ${ids}    ${p}[id]
    END
    List Should Contain Value    ${ids}    ${1}

Validate The Shape Of A Response Body
    [Documentation]    Beyond status codes: check the body has the right keys with the right types.
    [Tags]    api    validation
    ${user}=    GET On Session    ${SESSION}    /users/1
    ${body}=    Set Variable    ${user.json()}
    # Expected keys are present.
    Dictionary Should Contain Key    ${body}    id
    Dictionary Should Contain Key    ${body}    name
    Dictionary Should Contain Key    ${body}    email
    # Types are what we expect.
    ${id_type}=    Evaluate    type($body['id']).__name__
    Should Be Equal    ${id_type}    int
    ${name_type}=    Evaluate    type($body['name']).__name__
    Should Be Equal    ${name_type}    str
    # Nested objects work too: address dict has a 'city'.
    Dictionary Should Contain Key    ${body}[address]    city

A Created Resource Is Not Persisted
    [Documentation]    Caveat of this fake API: POST returns id 101 but saves nothing,
    ...                so you can't chain create -> read like on a real API.
    [Tags]    api    chaining    negative
    ${payload}=    Create Dictionary    title=Day 10    body=chaining    userId=${1}
    ${created}=    POST On Session    ${SESSION}    /posts    json=${payload}
    Status Should Be    201    ${created}
    ${new_id}=    Set Variable    ${created.json()}[id]
    Should Be Equal As Integers    ${new_id}    101
    # Read it back - never stored, so expect 404.
    ${lookup}=    GET On Session    ${SESSION}    /posts/${new_id}    expected_status=404
    Status Should Be    404    ${lookup}


*** Keywords ***
Open Api Session
    [Documentation]    Suite Setup: open ONE session reused by every test.
    Create Session    ${SESSION}    ${BASE_URL}
