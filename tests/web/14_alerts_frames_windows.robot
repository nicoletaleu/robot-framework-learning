*** Settings ***
Documentation    Day 14 - things that live outside the page: alerts, iframes, tabs, uploads.
...              Day 30 pointed it at the local site. This is the suite that changed
...              least, and for a good reason: alerts, iframes and tabs are browser
...              machinery, not site behaviour. A dialog blocks the page whoever wrote
...              the page, and an iframe has its own document whatever is inside it.
...              That is why these tests survived the move almost verbatim while the
...              table test next door had to be rewritten.
...              One piece of history is worth keeping visible: the iframe test below
...              once broke because the live site changed how many <p> tags it had.
...              The assertion that replaced it is still the right one - it just no
...              longer has to survive someone else's redesign.
...              Run:  robot --outputdir results tests/web/14_alerts_frames_windows.robot
Library          Browser
Library          OperatingSystem
Resource         ../../resources/local_site.resource
Suite Setup      Open The Local Site
Suite Teardown   Close The Local Site
Test Setup       Open A Fresh Page
Test Tags        web


*** Test Cases ***
Accept A Simple Alert
    [Documentation]    An alert blocks the page, so say how to answer it BEFORE the
    ...                click. Handle Future Dialogs = standing rule for this page.
    [Tags]    alert    smoke
    Go To    ${BASE_URL}/javascript_alerts
    Handle Future Dialogs    action=accept
    Click    text=Click for JS Alert
    Get Text    id=result    ==    You successfully clicked an alert

Accept Or Dismiss A Confirm Box
    [Documentation]    Both branches matter - a classic missed test case. Two answers
    ...                in one test, so arm one promise per click instead of a standing
    ...                rule.
    [Tags]    alert
    Go To    ${BASE_URL}/javascript_alerts
    # OK
    ${promise}=    Promise To    Wait For Alert    action=accept
    Click    text=Click for JS Confirm
    Wait For    ${promise}
    Get Text    id=result    ==    You clicked: Ok
    # Cancel
    ${promise}=    Promise To    Wait For Alert    action=dismiss
    Click    text=Click for JS Confirm
    Wait For    ${promise}
    Get Text    id=result    ==    You clicked: Cancel

Type Into A Prompt
    [Documentation]    Prompts take text via prompt_input, and Wait For hands back
    ...                the dialog's message so you can assert on it.
    [Tags]    alert
    Go To    ${BASE_URL}/javascript_alerts
    ${promise}=    Promise To    Wait For Alert    action=accept    prompt_input=Robot Framework
    Click    text=Click for JS Prompt
    ${question}=    Wait For    ${promise}
    Should Be Equal    ${question}    I am a JS prompt
    Get Text    id=result    ==    You entered: Robot Framework

Work Inside An Iframe
    [Documentation]    An iframe is a separate document. Reach into it with '>>>'.
    ...                Left of '>>>' = the iframe, right = the element inside.
    [Tags]    iframe
    Go To    ${BASE_URL}/iframe
    # The iframe loads after the outer page is ready - wait before reading.
    Wait For Elements State    id=mce_0_ifr >>> p    visible    timeout=10s
    ${text}=    Get Text    id=mce_0_ifr >>> p
    Should Contain    ${text}    Your content goes here.
    # No prefix: this heading is on the outer page.
    Get Text    h3    ==    An iFrame containing the TinyMCE WYSIWYG Editor
    # The outer document cannot see the iframe's text at all - which is the whole
    # point, and the only way to prove the '>>>' above did any work. An earlier
    # version counted <p> tags on the outer page and broke when the live site
    # changed how many it had; asserting on the body says what is meant.
    ${outer_text}=    Get Text    body
    Should Not Contain    ${outer_text}    Your content goes here.

Switch To A Newly Opened Tab
    [Documentation]    target=_blank opens a second page, but the library keeps
    ...                working on the old tab until you switch.
    [Tags]    window    tab
    Go To    ${BASE_URL}/windows
    Click    text=Click Here
    Switch Page    NEW
    Get Text    h3    ==    New Window
    # Back to the original tab.
    Close Page
    Switch Page    CURRENT
    Get Text    h3    ==    Opening a new window

Upload A File
    [Documentation]    File inputs are not clicked - you set the path on them.
    ...                The test creates its own file so it needs nothing pre-existing.
    ...                The echoed filename is what makes this a test: the form could
    ...                render "File Uploaded!" without a single byte having moved.
    [Tags]    upload
    ${file}=    Set Variable    ${OUTPUT DIR}${/}day14_upload.txt
    Create File    ${file}    uploaded by robot framework
    Go To    ${BASE_URL}/upload
    Upload File By Selector    id=file-upload    ${file}
    Click    id=file-submit
    Get Text    h3    ==    File Uploaded!
    Get Text    id=uploaded-files    ==    day14_upload.txt
    [Teardown]    Remove File    ${file}
