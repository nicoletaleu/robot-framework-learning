*** Settings ***
Documentation    Day 15 - waits and flakiness. Rule of thumb: wait for a STATE, never a fixed TIME.
...              Site: https://the-internet.herokuapp.com
...              Run:  robot --outputdir results tests/web/15_waits_and_flakiness.robot
Library          Browser
Suite Setup      New Browser    chromium    headless=${HEADLESS}
Suite Teardown   Close Browser
Test Setup       New Page    ${BASE_URL}
Test Tags        web    wait


*** Variables ***
${BASE_URL}      https://the-internet.herokuapp.com
${HEADLESS}      ${False}
${Slow}    8s


*** Test Cases ***
Auto-Wait Handles Most Cases
    [Documentation]    Browser library auto-waits before every action, so the happy path often needs no explicit wait.
    [Tags]    autowait
    Go To    ${BASE_URL}/dynamic_loading/2
    Click    css=#start button
    # No Wait keyword here on purpose: Get Text auto-waits for #finish to appear.
    Get Text    id=finish    ==    Hello World!

Wait For An Element To Become Visible
    [Documentation]    The element exists but is hidden, then revealed - wait for the state 'visible'.
    [Tags]    visible
    Go To    ${BASE_URL}/dynamic_loading/1
    Click    css=#start button
    Wait For Elements State    id=finish    visible    timeout=10s
    Get Text    id=finish    ==    Hello World!

Wait For An Element To Be Added To The DOM
    [Documentation]    The element does not exist until loading finishes - wait for 'attached' (created in the DOM).
    [Tags]    attached
    Go To    ${BASE_URL}/dynamic_loading/2
    Click    css=#start button
    Wait For Elements State    id=finish    attached    timeout=10s
    Get Text    id=finish    ==    Hello World!

Wait For A Control To Become Enabled
    [Documentation]    A field can be visible but disabled - 'visible' passes too early, so wait for 'enabled'.
    [Tags]    enabled
    Go To    ${BASE_URL}/dynamic_controls
    # The input starts disabled; the button turns it on after a short spinner.
    Click    css=#input-example button
    Wait For Elements State    css=#input-example input    enabled    timeout=10s
    Fill Text    css=#input-example input    now I can type
    Get Text    id=message    ==    It's enabled!

Wait For An Element To Disappear
    [Documentation]    After removing something, wait for it to be gone before asserting, or you hit stale DOM.
    [Tags]    detached
    Go To    ${BASE_URL}/dynamic_controls
    Click    css=#checkbox-example button
    # 'detached' = removed from the DOM entirely (use 'hidden' if it stays but is invisible).
    Wait For Elements State    css=#checkbox    detached    timeout=10s
    Get Text    id=message    ==    It's gone!

Wait For A Custom JavaScript Condition
    [Documentation]    When no element state fits, wait on a condition - here a text change. Good for text/attributes.
    [Tags]    condition
    Go To    ${BASE_URL}/dynamic_controls
    Click    css=#checkbox-example button
    Wait For Condition    Text    id=message    contains    gone

Set A Timeout Once For The Whole Test
    [Documentation]    Set one default timeout instead of repeating timeout= everywhere; per-keyword still overrides.
    [Tags]    timeout
    Set Browser Timeout    15s
    Go To    ${BASE_URL}/dynamic_loading/1
    Click    css=#start button
    # No timeout= here - it inherits the 15s default set above.
    Wait For Elements State    id=finish    visible
    Get Text    id=finish    ==    Hello World!
