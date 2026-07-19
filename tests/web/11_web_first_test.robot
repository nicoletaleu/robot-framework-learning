*** Settings ***
Documentation    Day 11 - first browser test: open, click, type, assert.
...              Uses Browser library (Playwright-based, auto-waits for elements).
...              Setup once:  pip install robotframework-browser  &&  rfbrowser init
...              Run:  robot --outputdir results tests/web/11_web_first_test.robot
Library          Browser
Suite Setup      Open Browser To Home Page
Suite Teardown   Close Browser


*** Variables ***
${BASE_URL}      https://the-internet.herokuapp.com
# ${HEADLESS} = True means an invisible browser (faster). Set False to watch what happens.
${HEADLESS}      True


*** Test Cases ***
Open A Page And Check Its Title
    [Documentation]    Simplest test: page loaded and has the expected title.
    [Tags]    web    smoke
    ${title}=    Get Title
    Should Be Equal    ${title}    The Internet

See That An Element Is Visible
    [Documentation]    Check that a text/element actually shows on screen.
    [Tags]    web
    # 'h1' is the big heading on the page. Get Text reads its content.
    ${heading}=    Get Text    h1
    Should Be Equal    ${heading}    Welcome to the-internet

Click A Link And Land On Another Page
    [Documentation]    Navigation: click a link and verify you landed on the right page.
    [Tags]    web    navigation
    # Click the link with the exact text "Form Authentication".
    Click    text=Form Authentication
    # After the click, the URL must end with /login.
    ${url}=    Get Url
    Should End With    ${url}    /login
    # ...and the new page has its own big heading.
    Get Text    h2    ==    Login Page

Fill A Form And Log In Successfully
    [Documentation]    Fill a form, submit and verify the success message.
    [Tags]    web    form    login
    Go To    ${BASE_URL}/login
    # Fill Text writes into a field located by 'id'.
    Fill Text    id=username    tomsmith
    Fill Text    id=password    SuperSecretPassword!
    # Press the submit button.
    Click    button[type=submit]
    # The message area (#flash) must contain the login confirmation.
    Get Text    id=flash    contains    You logged into a secure area!

A Wrong Password Shows An Error
    [Documentation]    Negative case: wrong credentials -> error message, not success.
    [Tags]    web    form    login    negative
    Go To    ${BASE_URL}/login
    Fill Text    id=username    tomsmith
    Fill Text    id=password    wrong-password
    Click    button[type=submit]
    # The error message must appear.
    Get Text    id=flash    contains    Your password is invalid!


*** Keywords ***
Open Browser To Home Page
    [Documentation]    Suite Setup: open one browser + page, reused by all tests.
    New Browser    chromium    headless=${HEADLESS}
    New Page    ${BASE_URL}
