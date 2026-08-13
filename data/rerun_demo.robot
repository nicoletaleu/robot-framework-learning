*** Settings ***
Documentation    Day 20 - INPUT DATA for tests/20_rerun_and_merge.robot.
...              Lives in data/ because two of its three tests have to fail.
...              Suite 20 runs it twice: once as it is, then again with
...              --rerunfailed, and merges the two reports.
Library          OperatingSystem


*** Variables ***
# Suite 20 passes a real path with --variable on the second run only. The
# default is deliberately something that will never exist.
${FIX MARKER}    ${TEMPDIR}/day20_fix_that_is_never_applied


*** Test Cases ***
A Demo Test That Always Passes
    [Documentation]    Passes in the first run, so --rerunfailed must NOT pick it up again.
    Log    Nothing to fix here.

A Demo Test That Fails Until The Fix Is In Place
    [Documentation]    The realistic case: red, someone fixes the cause, only this
    ...                test is run again. The marker file stands in for the fix.
    File Should Exist    ${FIX MARKER}    The fix is not in place yet.

A Demo Test That Stays Broken
    [Documentation]    Still red after the rerun - merging must not launder it.
    Fail    this one is not fixed by anything
