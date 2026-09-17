*** Settings ***
Documentation    Day 27 - INPUT DATA for tests/27_quarantine.robot.
...              In data/ because two of its four tests fail on purpose. Suite 27
...              runs this file three different ways and compares what each one
...              reports.
...
...              The `quarantine` tag on its own does nothing at all - it is a note to
...              a human. --skiponfailure is what gives it an effect, and that lives
...              in the run command, not in the file.


*** Test Cases ***
A Demo Test That Is Healthy
    [Documentation]    The control. Nothing about quarantine should touch a test that
    ...                was never in it.
    [Tags]    healthy
    Log    Green, and no tag involved.

A Demo Test In Quarantine That Still Fails
    [Documentation]    The reason quarantine exists: a real failure, with a cause
    ...                nobody has time to fix today. Deleting it loses the coverage;
    ...                leaving it red teaches everyone to ignore a red build.
    [Tags]    quarantine    known-race
    Fail    the underlying race is still there

A Demo Test In Quarantine That Has Started Passing
    [Documentation]    The half people forget. Quarantine is not a bin - a test that
    ...                has gone quiet is a candidate for release, and the only way to
    ...                notice is to keep running it.
    [Tags]    quarantine    known-race
    Log    Passed this time. Watch it, then take the tag off.

A Demo Test That Is Simply Broken
    [Documentation]    Not quarantined, and must stay a failure. A quarantine that
    ...                quietly swallowed this one would be worse than no build at all.
    [Tags]    healthy
    Should Be Equal    what shipped    what was expected
