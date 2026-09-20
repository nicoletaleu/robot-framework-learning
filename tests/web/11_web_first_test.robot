*** Settings ***
Documentation    Day 11 - first browser test: open, click, type, assert.
...              Day 30 pointed it at the local site and made each test start from
...              its own page. Both changes were overdue: the suite used to open one
...              page in Suite Setup and let every test inherit whatever the last one
...              left behind, so "click the link on the home page" only worked because
...              it happened to run third.
...              It also made the suite honest about what it proves. The title and the
...              heading below now come from data/pages/index.html - a file in this
...              repo - so asserting them is not checking that a site is correct. It
...              is checking that the browser went where the test told it to and that
...              the test can read what is on the screen. That is the skill Day 11 was
...              actually learning.
...              Run:  robot --outputdir results tests/web/11_web_first_test.robot
Library          Browser
Resource         ../../resources/local_site.resource
Suite Setup      Open The Local Site
Suite Teardown   Close The Local Site
Test Setup       Open A Fresh Page
Test Tags        web


*** Test Cases ***
Open A Page And Check Its Title
    [Documentation]    The simplest thing a browser test can assert: we arrived, and
    ...                the page is the one we asked for rather than an error page.
    [Tags]    smoke
    Get Title    ==    The Internet

See That An Element Is Visible
    [Documentation]    Reading text off the screen - the other half of every UI
    ...                assertion. Get Text waits for the element first.
    Get Text    h1    ==    Welcome to the-internet

Click A Link And Land On Another Page
    [Documentation]    Navigation, and the first test here with something at stake:
    ...                a click that silently does nothing looks exactly like a click
    ...                that worked, until the URL is checked.
    [Tags]    navigation
    Click    text=Form Authentication
    ${url}=    Get Url
    Should End With    ${url}    /login
    Get Text    h2    ==    Login Page

Fill A Form And Log In Successfully
    [Documentation]    Fill two fields, submit, read the result. Worth being plain
    ...                about: this is not a test of authentication. The password it
    ...                sends is the one PageServer is written to accept. What it
    ...                exercises is filling a form and following a redirect.
    [Tags]    form    login
    Go To    ${BASE_URL}/login
    Fill Text    id=username    tomsmith
    Fill Text    id=password    SuperSecretPassword!
    Click    button[type=submit]
    Get Text    id=flash    contains    You logged into a secure area!
    # The message alone is not proof - a page can say anything. The URL is the
    # second, independent sign that the login actually went through.
    ${url}=    Get Url
    Should End With    ${url}    /secure

A Wrong Password Shows An Error
    [Documentation]    The negative case, and the one that stops the test above from
    ...                passing by accident: a form that ignores its input entirely
    ...                would pass one of these two, never both.
    [Tags]    form    login    negative
    Go To    ${BASE_URL}/login
    Fill Text    id=username    tomsmith
    Fill Text    id=password    wrong-password
    Click    button[type=submit]
    Get Text    id=flash    contains    Your password is invalid!
    ${url}=    Get Url
    Should End With    ${url}    /login
