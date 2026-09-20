*** Settings ***
Documentation    Day 12 - richer web interactions: dropdowns, checkboxes, dynamic
...              elements, tables.
...              Day 30 pointed it at the local site, and two tests did not survive
...              the move unchanged.
...              The table test asserted the first cell was "Smith" - which, once the
...              table is a file in this repo, is the Day 28 mistake in a new costume:
...              an assertion about fixture data dressed up as a test. What is mine to
...              get wrong there is the locator, so that is what it checks now.
...              The screenshot test had no assertion at all. It took a picture and
...              ended, so it could only ever fail by raising. It now checks the file
...              arrived, which is the only claim it was ever making.
...              Run:  robot --outputdir results tests/web/12_web_interactions.robot
Library          Browser
Library          OperatingSystem
Resource         ../../resources/local_site.resource
Suite Setup      Open The Local Site
Suite Teardown   Close The Local Site
Test Setup       Open A Fresh Page
Test Tags        web


*** Test Cases ***
Select An Option From A Dropdown
    [Documentation]    Pick a value from a <select> and read back what is selected.
    ...                Reading it back matters: Select Options By failing to match
    ...                anything is not an error, it is a dropdown that stayed put.
    [Tags]    dropdown    smoke
    Go To    ${BASE_URL}/dropdown
    Select Options By    id=dropdown    label    Option 2
    ${selected}=    Get Selected Options    id=dropdown    label
    Should Contain    ${selected}    Option 2

Tick And Untick Checkboxes
    [Documentation]    Both directions, because Check Checkbox is idempotent: it
    ...                leaves the box checked whether or not the click landed. Only
    ...                unchecking afterwards proves the state really moved.
    [Tags]    checkbox
    Go To    ${BASE_URL}/checkboxes
    ${first}=    Set Variable    css=#checkboxes input >> nth=0
    Check Checkbox    ${first}
    Get Checkbox State    ${first}    ==    checked
    Uncheck Checkbox    ${first}
    Get Checkbox State    ${first}    ==    unchecked

Wait For An Element That Appears Later
    [Documentation]    Dynamic content: the text only exists after the page's own
    ...                script finishes. Browser library auto-waits, but the explicit
    ...                state check says which state is being waited for.
    [Tags]    dynamic    wait
    Go To    ${BASE_URL}/dynamic_loading/1
    Click    css=#start button
    Wait For Elements State    id=finish    visible    timeout=10s
    Get Text    id=finish    ==    Hello World!

Read The Right Cell Out Of A Table
    [Documentation]    This used to assert the first cell said "Smith". Against a live
    ...                site that was an assertion about somebody else's data; against
    ...                data/pages/tables.html it is an assertion about a file two
    ...                directories away, which is worse - it looks like a test and
    ...                cannot fail for any interesting reason.
    ...                The part that is mine to get wrong is the locator, and the way
    ...                to get it wrong is off by one: reading the header row and
    ...                calling it data. So that is what is checked.
    [Tags]    table
    Go To    ${BASE_URL}/tables
    ${header}=       Get Text    css=#table1 thead tr >> nth=0 >> th >> nth=0
    ${first cell}=   Get Text    css=#table1 tbody tr >> nth=0 >> td >> nth=0
    Should Not Be Equal    ${first cell}    ${header}
    ...    The locator walked into the header row instead of the first data row
    # And the row locator counts data rows only - a <thead> row must not be in it.
    ${rows}=    Get Element Count    css=#table1 tbody tr
    ${all}=     Get Element Count    css=#table1 tr
    Should Be Equal As Integers    ${all}    ${rows + 1}

Take A Screenshot As Evidence
    [Documentation]    A screenshot is evidence, so the test that takes one should
    ...                check there is evidence. Before Day 30 this ended on Take
    ...                Screenshot and asserted nothing: a silent no-op would have
    ...                passed it every time.
    [Tags]    screenshot
    ${path}=    Take Screenshot    filename=day12_home
    File Should Exist     ${path}
    ${size}=    Get File Size    ${path}
    Should Be True    ${size} > 0    The screenshot file is empty
