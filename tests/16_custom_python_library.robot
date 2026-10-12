*** Settings ***
Documentation    Day 16 - writing my OWN keywords in Python: ../libraries/DataHelpers.py
...              Python produces the data, Robot does the asserting - a check hidden
...              in Python disappears from the report.
...              Run:  robot --outputdir results tests/16_custom_python_library.robot
Library          ../libraries/DataHelpers.py
Library          Collections
Library          String
Test Tags        custom-library    unit


*** Variables ***
${BIRTHDATE}     1990-05-17
# Fixed reference date: a test that depends on today breaks on its own.
${REFERENCE}     2026-05-16


*** Test Cases ***
A Python Method Becomes A Keyword
    [Documentation]    random_email() in Python is "Random Email" here - importing is the whole wiring.
    [Tags]    smoke
    ${email}=    Random Email
    Should Match Regexp    ${email}    ^user_\\d{8}@example\\.com$

Keyword Arguments And Defaults Work Like Anywhere Else
    [Documentation]    Python defaults become Robot defaults; named arguments override one at a time.
    ${default}=    Random Email
    ${custom}=     Random Email    prefix=qa    domain=example.com
    Should Start With    ${default}    user_
    Should Match Regexp    ${custom}    ^qa_\\d{8}@example\\.com$

Generated Data Is Unique Every Time
    [Documentation]    Why this library exists: reusing one address passes once, then "email taken".
    [Tags]    smoke
    ${first}=     Random Email
    ${second}=    Random Email
    Should Not Be Equal    ${first}    ${second}

A Keyword Can Be Renamed For Readability
    [Documentation]    The method is random_string; @keyword makes the call read as a sentence.
    ${text}=    Random String Of Length    12
    Length Should Be    ${text}    12

Type Hints Convert My Arguments
    [Documentation]    length: int means "5" arrives as 5 - no Convert To Integer needed.
    ${text}=    Random String Of Length    length=5
    Length Should Be    ${text}    5

A Bad Argument Type Fails With A Readable Error
    [Documentation]    The flip side: garbage is rejected before my code runs.
    ...                Tagged no-dryrun: --dryrun converts arguments without running
    ...                anything, so it hits the same ValueError this test is asserting
    ...                and reports it as a failure. The test is right and the dry run
    ...                is right - they cannot both be satisfied in one pass.
    [Tags]    no-dryrun
    Run Keyword And Expect Error    *Argument 'length' got value 'abc' that cannot be converted to integer*
    ...    Random String Of Length    abc

A Keyword Can Return A Dictionary
    [Documentation]    Any Python object can come back - a dict is the shape a POST body needs.
    [Tags]    smoke
    ${user}=    Build User    Nicoleta    31
    Should Be Equal    ${user}[name]    Nicoleta
    Should Be Equal As Integers    ${user}[age]    31
    Should Be True    ${user}[is_adult]
    Dictionary Should Contain Key    ${user}    email

Dates Are Converted Too And The Age Is Computed In Python
    [Documentation]    birthdate: date turns "1990-05-17" into a real date object.
    ${age}=    Age On    ${BIRTHDATE}    ${REFERENCE}
    Should Be Equal As Integers    ${age}    35

The Day Before The Birthday Still Counts As The Previous Year
    [Documentation]    The boundary is where age maths breaks, so it gets its own test.
    ${day_before}=    Age On    ${BIRTHDATE}    2026-05-16
    ${on_the_day}=    Age On    ${BIRTHDATE}    2026-05-17
    Should Be Equal As Integers    ${day_before}    35
    Should Be Equal As Integers    ${on_the_day}    36

Messy Phone Numbers Are Cleaned Up
    [Documentation]    [Template] from Day 7 does not care that the keyword is Python now.
    [Template]    Phone Should Normalize To
    +40 721 123 456       +40721123456
    (0721) 123-456        0721123456
    0721.123.456          0721123456
    +40-721-123-456       +40721123456

An Invalid Phone Number Fails The Test With My Own Message
    [Documentation]    raise in Python = failed test, and my message is what lands in the report.
    [Tags]    smoke
    Run Keyword And Expect Error    *Not a valid phone number: '12345'*
    ...    Normalize Phone Number    12345

Only Decorated Methods Are Exposed As Keywords
    [Documentation]    slugify() has no underscore and no @keyword - so suites cannot call it.
    ...                Tagged no-dryrun for the same reason as above: a dry run resolves
    ...                keyword names, and "no keyword with that name" is exactly what
    ...                this test wants to happen.
    [Tags]    no-dryrun
    Run Keyword And Expect Error    No keyword with name 'Slugify' found.
    ...    Slugify    Hello World

The Library Keeps Its State Across Tests
    [Documentation]    scope="GLOBAL" shares one instance. Asserted as a delta, so adding a
    ...                test above does not break this one.
    ${before}=    Emails Generated So Far
    Random Email
    Random Email
    ${after}=    Emails Generated So Far
    ${expected}=    Evaluate    ${before} + 2
    Should Be Equal As Integers    ${after}    ${expected}

Python Can Write Straight Into The Report
    [Documentation]    robot.api.logger with html=True renders a real table in log.html.
    ${users}=    Create List
    ...    ${{ {'name': 'Ana', 'age': 30, 'email': 'ana@example.com'} }}
    ...    ${{ {'name': 'Bogdan', 'age': 17, 'email': 'bogdan@example.com'} }}
    Log Users As A Table    ${users}
    Length Should Be    ${users}    2


*** Keywords ***
Phone Should Normalize To
    [Documentation]    Python cleans the number, the assertion stays in Robot so it reaches the report.
    [Arguments]    ${raw}    ${expected}
    ${actual}=    Normalize Phone Number    ${raw}
    Should Be Equal    ${actual}    ${expected}
