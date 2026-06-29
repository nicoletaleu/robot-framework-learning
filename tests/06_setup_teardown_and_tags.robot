*** Settings ***
Documentation    Day 6 - Organising tests: Setup / Teardown and Tags.
...
...              SETUP runs BEFORE a test, TEARDOWN runs AFTER it (even if the test fails).
...              Use them to prepare and clean up state so each test starts fresh.
...
...              Suite Setup / Suite Teardown  -> run ONCE per file (before first / after last test).
...              Test Setup  / Test Teardown   -> run for EVERY test in the file.
...              [Setup] / [Teardown]          -> override Setup/Teardown for a single test.
...
...              TAGS label tests so you can run a subset:
...                robot --include smoke    tests/06_setup_teardown_and_tags.robot
...                robot --exclude slow     tests/06_setup_teardown_and_tags.robot
...
...              Run with:  robot --outputdir results tests/06_setup_teardown_and_tags.robot
Library          Collections

Suite Setup      Log    === Starting the cart test suite ===
Suite Teardown   Log    === Finished the cart test suite ===
Test Setup       Reset The Cart
Test Teardown    Log    Test finished, cart had ${cart_count} item(s).
Force Tags       cart


*** Variables ***
@{CART}         ${EMPTY}
${cart_count}    0


*** Keywords ***
Reset The Cart
    [Documentation]    Empties the cart so every test starts from a clean state.
    ...                This is the Test Setup, so it runs before each test.
    Set Global Variable    @{CART}    @{EMPTY}
    Set Global Variable    ${cart_count}    0
    Log    Cart reset to empty.

Add To Cart
    [Documentation]    Appends an item and keeps a running count.
    [Arguments]    ${item}
    Append To List    ${CART}    ${item}
    ${cart_count}=    Get Length    ${CART}
    Set Global Variable    ${cart_count}
    Log    Added ${item} (cart now has ${cart_count} item[s]).

Prepare Empty Checkout
    [Documentation]    A custom [Setup] for one test. Because it OVERRIDES the suite
    ...                Test Setup, it must reset the cart itself, then add its own logging.
    Reset The Cart
    Log    Preparing an empty-cart checkout scenario.

Can Checkout
    [Documentation]    Returns True only if the cart has at least one item.
    ${length}=    Get Length    ${CART}
    IF    ${length} > 0
        RETURN    ${TRUE}
    ELSE
        RETURN    ${FALSE}
    END


*** Test Cases ***
Cart Starts Empty
    [Documentation]    Test Setup emptied the cart before this test ran.
    [Tags]    smoke
    Length Should Be    ${CART}    0

Add One Item
    [Documentation]    Adds a single item, then checks the count.
    [Tags]    smoke
    Add To Cart    apple
    Length Should Be    ${CART}    1

Add Several Items
    [Documentation]    The cart was reset by Test Setup, so it starts empty again.
    [Tags]    regression
    Add To Cart    apple
    Add To Cart    banana
    Add To Cart    cherry
    Length Should Be    ${CART}    3
    List Should Contain Value    ${CART}    banana

Checkout An Empty Cart Is Blocked
    [Documentation]    A test with its OWN [Setup] that overrides the suite Test Setup.
    ...                Here we want a fresh empty cart and a custom message instead.
    [Tags]    regression    slow
    [Setup]    Prepare Empty Checkout
    ${status}=    Can Checkout
    Should Be Equal    ${status}    ${FALSE}
