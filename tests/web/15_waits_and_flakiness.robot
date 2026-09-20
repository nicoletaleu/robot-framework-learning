*** Settings ***
Documentation    Day 15 - waits and flakiness. Rule of thumb: wait for a STATE, never
...              a fixed TIME.
...              Day 30 pointed it at the local site, which put an uncomfortable
...              question in front of the whole suite. The delays are now in
...              data/pages/, which means I choose them - and a wait test whose page
...              answers instantly is decoration: it passes with the wait, without the
...              wait, and with the wait removed entirely. It tests nothing.
...              So the first test below now checks the thing that makes the other six
...              worth running: immediately after the click, the element is NOT ready.
...              If that ever starts failing, the pages have become too fast and every
...              wait in this file has quietly stopped being load-bearing.
...              Run:  robot --outputdir results tests/web/15_waits_and_flakiness.robot
Library          Browser
Resource         ../../resources/local_site.resource
Suite Setup      Open The Local Site
Suite Teardown   Close The Local Site
Test Setup       Open A Fresh Page
Test Tags        web    wait


*** Test Cases ***
The Waits In This Suite Are Load-Bearing
    [Documentation]    The test that keeps the rest honest. Nothing here waits: it
    ...                clicks and looks straight away, and the element must still be
    ...                unfinished. A green run means the six tests below are really
    ...                waiting for something.
    [Tags]    meta
    Go To    ${BASE_URL}/dynamic_loading/2
    Click    css=#start button
    # No wait, on purpose. Get Element Count does not auto-wait the way Get Text
    # does, so this reads the DOM as it is at this instant.
    ${count}=    Get Element Count    id=finish
    Should Be Equal As Integers    ${count}    0
    ...    #finish was already there - the page answers too fast for this suite to prove anything

Auto-Wait Handles Most Cases
    [Documentation]    Browser library auto-waits before every action, so the happy
    ...                path often needs no explicit wait at all.
    [Tags]    autowait    smoke
    Go To    ${BASE_URL}/dynamic_loading/2
    Click    css=#start button
    # No Wait keyword here on purpose: Get Text auto-waits for #finish to appear.
    Get Text    id=finish    ==    Hello World!

Wait For An Element To Become Visible
    [Documentation]    The element exists but is hidden, then revealed - wait for the
    ...                state 'visible'. On this page 'attached' would pass instantly
    ...                and prove nothing, which is the distinction the two dynamic
    ...                loading pages exist to make.
    [Tags]    visible
    Go To    ${BASE_URL}/dynamic_loading/1
    Click    css=#start button
    Wait For Elements State    id=finish    visible    timeout=10s
    Get Text    id=finish    ==    Hello World!

Wait For An Element To Be Added To The DOM
    [Documentation]    Here the element does not exist until loading finishes - wait
    ...                for 'attached' (created in the DOM).
    [Tags]    attached
    Go To    ${BASE_URL}/dynamic_loading/2
    Click    css=#start button
    Wait For Elements State    id=finish    attached    timeout=10s
    Get Text    id=finish    ==    Hello World!

Wait For A Control To Become Enabled
    [Documentation]    A field can be visible but disabled - 'visible' passes too
    ...                early, so wait for 'enabled'. Typing into it afterwards is what
    ...                proves the wait ended at the right moment.
    [Tags]    enabled
    Go To    ${BASE_URL}/dynamic_controls
    Click    css=#input-example button
    Wait For Elements State    css=#input-example input    enabled    timeout=10s
    Fill Text    css=#input-example input    now I can type
    Get Text    id=message    ==    It's enabled!

Wait For An Element To Disappear
    [Documentation]    After removing something, wait for it to be gone before
    ...                asserting, or you hit a stale DOM.
    [Tags]    detached
    Go To    ${BASE_URL}/dynamic_controls
    Click    css=#checkbox-example button
    # 'detached' = removed from the DOM entirely (use 'hidden' if it stays but is invisible).
    Wait For Elements State    css=#checkbox    detached    timeout=10s
    Get Text    id=message    ==    It's gone!

Wait For A Custom JavaScript Condition
    [Documentation]    When no element state fits, wait on a condition - here a text
    ...                change. Good for text and attributes.
    [Tags]    condition
    Go To    ${BASE_URL}/dynamic_controls
    Click    css=#checkbox-example button
    Wait For Condition    Text    id=message    contains    gone

Set A Timeout Once For The Whole Test
    [Documentation]    Set one default timeout instead of repeating timeout=
    ...                everywhere; per-keyword still overrides.
    [Tags]    timeout
    Set Browser Timeout    15s
    Go To    ${BASE_URL}/dynamic_loading/1
    Click    css=#start button
    # No timeout= here - it inherits the 15s default set above.
    Wait For Elements State    id=finish    visible
    Get Text    id=finish    ==    Hello World!
