*** Settings ***
Documentation    Day 19 - INPUT DATA for tests/19_listeners.robot, not part of the run.
...
...              It lives in data/ and not in tests/ on purpose: the middle test
...              below has to fail, and a failing test inside tests/ would break
...              every `robot tests/` run and turn the CI badge red for no reason.
...              Suite 19 starts this file as a CHILD robot process with the
...              listener attached, then reads back what the listener recorded.
...
...              Notice what is missing: no Library import, no listener setting,
...              no mention of RunListener anywhere. That is the point - a
...              listener attaches from the command line and the suite never
...              knows it is being watched.


*** Test Cases ***
A Demo Test That Passes
    Log    Nothing interesting - the listener is what is under test here.

A Demo Test That Fails On Purpose
    Fail    deliberate failure - suite 19 checks the listener recorded a FAIL

A Demo Test That Is Slow Enough To Be Tagged
    [Documentation]    The child run sets the threshold below this sleep, so
    ...                end_test adds a "slow" tag that this file never declares.
    Sleep    0.4s
