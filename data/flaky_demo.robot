*** Settings ***
Documentation    Day 24 - INPUT DATA for tests/24_flaky_tests.robot.
...              Lives in data/ because these tests are supposed to fail, and how
...              often depends on how they are run - which is the whole point.
...              Suite 24 runs this file several different ways and compares.
...
...              Two causes, both real, both common:
...                1. order dependence - a test that only passes after its neighbour
...                2. state that survives the run - a test that alternates
...              Neither is random. They only look random from inside a single run.
Library          Collections
Library          OperatingSystem
Library          ../libraries/DataHelpers.py


*** Variables ***
# Overwritten by suite 24 with a path of its own.
${COUNTER FILE}    ${TEMPDIR}/day24_counter_unused
@{CART}            @{EMPTY}


*** Test Cases ***
A Demo Test That Fills The Cart
    [Documentation]    Leaves state behind on purpose. Nothing here is wrong yet -
    ...                the damage is done by the test below trusting it.
    Append To List    ${CART}    espresso
    Append To List    ${CART}    cortado
    Length Should Be    ${CART}    2

A Demo Test That Trusts The Cart
    [Documentation]    Passes when the whole file runs top to bottom, fails on its
    ...                own. Same code, same machine, opposite result - and the test
    ...                itself contains no clue about why.
    Length Should Be    ${CART}    2
    Should Contain    ${CART}    espresso

A Demo Test That Alternates Between Runs
    [Documentation]    Fails on odd runs, passes on even ones. Stands in for anything
    ...                that carries state across runs: a leftover record, a cached
    ...                token, a file nobody cleaned up.
    ${run}=    Bump Counter    ${COUNTER FILE}
    Log    This is run number ${run}.
    Should Be True    ${run} % 2 == 0    run ${run} is odd, so this one fails

A Demo Test That Builds Its Own Cart
    [Documentation]    The fix, for comparison: it depends on nothing that happened
    ...                before it, so the order it runs in cannot change the answer.
    ${own cart}=    Create List    espresso    cortado
    Length Should Be    ${own cart}    2
    Should Contain    ${own cart}    espresso
