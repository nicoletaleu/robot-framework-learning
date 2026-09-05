*** Settings ***
Documentation    Day 25 - contract tests: keeping the stub honest.
...              Day 21 built a stub and admitted its flaw - it returns whatever it
...              was told to, including a shape the real service never sends, and
...              every test stays green. A contract closes that hole. One file,
...              data/contracts/post.json, describes what the tests need a post to
...              look like, and two different things are held to it: the stub,
...              offline on every run, and the live API, on a schedule.
...              Neither check is worth much alone. Together they mean "my client
...              handles this shape" AND "this shape is still what arrives".
...              The live tests are tagged `contract` and stay off the pull request
...              path on purpose - a check that needs the internet does not belong
...              on the fast feedback loop. See .github/workflows/tests.yml.
...              Run offline:  robot --exclude contract --outputdir results tests/api/25_contract_tests.robot
...              Run all:      robot --outputdir results tests/api/25_contract_tests.robot
Library          RequestsLibrary
Library          Collections
Library          OperatingSystem
Library          ../../libraries/StubServer.py
Library          ../../libraries/ContractHelpers.py
Suite Setup      Start The Stub And Open Sessions
Suite Teardown   Stop Stub Server
Test Tags        api


*** Variables ***
${LIVE URL}      https://jsonplaceholder.typicode.com
${STUB}          stub
${LIVE}          live
${WORKFLOW}      ${CURDIR}/../../.github/workflows/tests.yml
&{GOOD POST}     userId=${1}    id=${1}    title=A stubbed post    body=some words


*** Test Cases ***
The Stub Answers With Something The Contract Allows
    [Documentation]    What Day 21 could not check. The canned response is held to the
    ...                same written shape the real service is held to, so the stub can
    ...                no longer drift away from reality unnoticed.
    [Tags]    smoke
    Stub Request    GET    /posts/1    status=200    json_body=${GOOD POST}
    ${response}=    GET On Session    ${STUB}    /posts/1
    Status Should Be    200    ${response}
    Payload Should Match Contract    ${response.json()}    post

A Missing Field Breaks The Contract
    [Documentation]    The check has teeth: prove it fails before trusting it to pass.
    [Tags]    smoke
    ${incomplete}=    Create Dictionary    userId=${1}    id=${1}    title=No body here
    ${violations}=    Contract Violations    ${incomplete}    post
    Length Should Be    ${violations}    1
    Should Contain    ${violations}[0]    'body' is a required property

A Field Of The Wrong Type Breaks The Contract
    [Documentation]    The drift that actually happens in the wild: a number starts
    ...                arriving as a string. The field is present, the count is right,
    ...                and every test that only checks for existence stays green.
    ${stringly}=    Create Dictionary
    ...    userId=${1}    id=1    title=An id as text    body=some words
    ${violations}=    Contract Violations    ${stringly}    post
    Length Should Be    ${violations}    1
    Should Contain    ${violations}[0]    root.id
    Should Contain    ${violations}[0]    is not of type 'integer'

Several Violations Are Reported At Once
    [Documentation]    A drifted response has usually drifted in more than one place.
    ...                Reporting the first one only turns a five minute fix into five
    ...                runs.
    ${bad}=    Create Dictionary    userId=nope    id=${0}    title=${EMPTY}
    ${violations}=    Contract Violations    ${bad}    post
    Length Should Be    ${violations}    4

The Contract Ignores Fields It Does Not Use
    [Documentation]    Deliberate, and the part people get wrong. A contract says what
    ...                this consumer NEEDS, not everything the provider may send. If a
    ...                new field broke the tests, no service could ever add one - so
    ...                additionalProperties is left open.
    ${with extra}=    Copy Dictionary    ${GOOD POST}
    Set To Dictionary    ${with extra}    published    ${True}    slug    a-stubbed-post
    Payload Should Match Contract    ${with extra}    post

A Contract With A Typo In It Fails Loudly
    [Documentation]    The one failure mode a contract must not have is passing
    ...                everything because nobody noticed it is not a valid schema.
    ...                Load Contract checks the schema itself before using it.
    Run Keyword And Expect Error    *No contract named 'no_such_thing'*
    ...    Load Contract    no_such_thing

The Real API Still Matches The Contract
    [Documentation]    The other half, and the only one that can tell me the stub has
    ...                gone stale. Needs the network, so it is tagged `contract` and
    ...                runs on a schedule rather than on every push.
    [Tags]    contract
    ${response}=    GET On Session    ${LIVE}    /posts/1
    Status Should Be    200    ${response}
    Payload Should Match Contract    ${response.json()}    post

Every Item In A Real List Matches The Contract
    [Documentation]    A list that is right about the first item and wrong about the
    ...                fortieth is exactly what a spot check misses.
    [Tags]    contract
    ${response}=    GET On Session    ${LIVE}    /posts
    Status Should Be    200    ${response}
    ${posts}=    Set Variable    ${response.json()}
    Length Should Be    ${posts}    100
    Every Item Should Match Contract    ${posts}    post

The Contract Tests Stay Off The Pull Request Path
    [Documentation]    A network check on the fast loop is a flaky test waiting to
    ...                happen - Day 24, from the other direction. This asserts the
    ...                workflow keeps them out of the push runs and gives them a
    ...                schedule of their own.
    ${workflow}=    Get File    ${WORKFLOW}
    Should Contain    ${workflow}    --exclude contract
    Should Contain    ${workflow}    --include contract
    Should Contain    ${workflow}    schedule:


*** Keywords ***
Start The Stub And Open Sessions
    [Documentation]    Suite Setup: the Day 21 stub for the offline tests, and a
    ...                session against the real service for the two tagged ones.
    ${base url}=    Start Stub Server
    Create Session    ${STUB}    ${base url}
    # verify=${True} is not the default: RequestsLibrary accepts any certificate
    # unless told otherwise, so a suite would happily keep passing against a
    # server whose TLS had quietly broken. The stub is plain http, so it needs none.
    Create Session    ${LIVE}    ${LIVE URL}    verify=${True}
