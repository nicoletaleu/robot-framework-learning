*** Settings ***
Documentation    Day 12 - richer web interactions: dropdowns, checkboxes, dynamic elements, tables.
...              Builds on Day 11 (open/click/fill) with the controls real pages actually have.
...              Uses Browser library (Playwright-based, auto-waits for elements).
...              Site: https://the-internet.herokuapp.com (public practice site, no auth).
...              Run:  robot --outputdir results tests/web/12_web_interactions.robot
Library          Browser
Suite Setup      New Browser    chromium    headless=${HEADLESS}
Suite Teardown   Close Browser
Test Setup       New Page    ${BASE_URL}


*** Variables ***
${BASE_URL}      https://the-internet.herokuapp.com
# False = a real browser window you can watch. Set True for an invisible, faster run.
${HEADLESS}      False


*** Test Cases ***
Select An Option From A Dropdown
    [Documentation]    Pick a value from a <select> dropdown and confirm it is selected.
    [Tags]    web    dropdown    smoke
    Go To    ${BASE_URL}/dropdown
    # Select the option whose visible label is "Option 2".
    Select Options By    id=dropdown    label    Option 2
    # Read back what is now selected to prove it worked.
    ${selected}=    Get Selected Options    id=dropdown    label
    Should Contain    ${selected}    Option 2

Tick And Untick Checkboxes
    [Documentation]    Check a box, verify its state, then uncheck it.
    [Tags]    web    checkbox
    Go To    ${BASE_URL}/checkboxes
    # There are two checkboxes; target the first one.
    ${first}=    Set Variable    css=#checkboxes input >> nth=0
    # Make sure it ends up checked, then confirm.
    Check Checkbox    ${first}
    Get Checkbox State    ${first}    ==    checked
    # Now uncheck it and confirm the opposite.
    Uncheck Checkbox    ${first}
    Get Checkbox State    ${first}    ==    unchecked

Wait For An Element That Appears Later
    [Documentation]    Dynamic content: a button loads text after a few seconds.
    ...                Browser library auto-waits, but this shows the state check explicitly.
    [Tags]    web    dynamic    wait
    Go To    ${BASE_URL}/dynamic_loading/1
    Click    css=#start button
    # The hidden text only shows up after loading finishes - wait for it to be visible.
    Wait For Elements State    id=finish    visible    timeout=10s
    Get Text    id=finish    ==    Hello World!

Read A Value From A Table
    [Documentation]    Data on real pages often lives in tables - read a specific cell.
    [Tags]    web    table
    Go To    ${BASE_URL}/tables
    # Grab the last-name cell in the first data row of table #table1.
    ${last_name}=    Get Text    css=#table1 tbody tr >> nth=0 >> td >> nth=0
    Should Be Equal    ${last_name}    Smith

Take A Screenshot As Evidence
    [Documentation]    Capture the page to an image - useful as proof or for debugging failures.
    [Tags]    web    screenshot
    Go To    ${BASE_URL}
    # Saves into the output dir (results/) under the given name.
    Take Screenshot    filename=day12_home
