*** Settings ***
Documentation    Day 17 - test data OUTSIDE the suite: variable files, JSON and CSV.
...              The suite says WHAT is checked; the files say WITH WHAT.
...              Run:  robot --outputdir results tests/17_external_test_data.robot
...              Other env:  robot --variablefile variables/config.py:staging tests/
Library          ../libraries/DataHelpers.py
Library          Collections
Variables        ../variables/config.py            # dynamic .py -> get_variables()
Variables        ../data/feature_flags.json        # static .json -> keys become variables
Library          ../variables/config.py            # same file as a library, to call get_variables
Test Tags        data


*** Variables ***
# ${CURDIR} = this file's folder, so the path survives any working directory.
${USERS_CSV}     ${CURDIR}/../data/users.csv
${TODAY}         2026-08-04


*** Test Cases ***
Variables Come From The Python Variable File
    [Documentation]    Asserted against the active ${ENV}, so a staging run passes too.
    [Tags]    smoke
    ${expected}=    config.Get Variables    ${ENV}
    Should Be Equal    ${BASE_URL}    ${expected}[BASE_URL]
    Should Be Equal    ${API_URL}     ${expected}[API_URL]
    Should Be Equal    ${TIMEOUT}     ${expected}[TIMEOUT]

Dev Is The Default Environment
    [Documentation]    No argument on the import = dev.
    ${dev}=    config.Get Variables
    Should Be Equal    ${dev}[ENV]    dev
    Should Be Equal    ${dev}[BASE_URL]    https://the-internet.herokuapp.com
    Should Be Equal    ${dev}[TIMEOUT]    10s

An Unknown Environment Fails Loudly
    [Documentation]    A typo raises instead of handing back empty URLs. The "config." prefix
    ...                is required: BuiltIn has its own Get Variables.
    ${error}=    Run Keyword And Expect Error    ValueError: *
    ...    config.Get Variables    prod
    Should Contain    ${error}    Unknown environment 'prod'

The JSON Variable File Keeps Real Types
    [Documentation]    JSON gives booleans, numbers, lists and dicts - CSV gives only text.
    [Tags]    smoke
    Should Be Equal    ${PRODUCT}    robot-framework-learning
    Should Be True    ${FEATURE_FLAGS}[new_checkout]
    Should Not Be True    ${FEATURE_FLAGS}[dark_mode]
    Length Should Be    ${SUPPORTED_LOCALES}    3
    Should Be Equal As Integers    ${MAX_LOGIN_ATTEMPTS}    3

Reading The CSV Gives One Dictionary Per Row
    [Documentation]    The header row becomes the keys, so rows are read by name, not index.
    [Tags]    smoke
    ${rows}=    Read CSV Rows    ${USERS_CSV}
    Length Should Be    ${rows}    4
    Should Be Equal    ${rows}[0][name]    Ana
    Dictionary Should Contain Key    ${rows}[0]    birthdate

Every Phone Number In The File Is Valid
    [Documentation]    Adding a user to the CSV extends the test without touching this file.
    ${rows}=    Read CSV Rows    ${USERS_CSV}
    FOR    ${row}    IN    @{rows}
        ${clean}=    Normalize Phone Number    ${row}[phone]
        Should Match Regexp    ${clean}    ^\\+?\\d{9,15}$
    END

Every Age In The File Matches The Expected Column
    [Documentation]    Input and expected result travel together in the file. Dan is the
    ...                boundary: born exactly on ${TODAY}.
    ${rows}=    Read CSV Rows    ${USERS_CSV}
    FOR    ${row}    IN    @{rows}
        ${age}=    Age On    ${row}[birthdate]    ${TODAY}
        Should Be Equal As Integers    ${age}    ${row}[expected_age]
        ...    msg=Wrong age for ${row}[name]
    END

An Empty Or Missing File Fails With A Clear Message
    [Documentation]    Silent empty data would make every loop above pass by doing nothing.
    Run Keyword And Expect Error    *nope.csv*
    ...    Read CSV Rows    ${CURDIR}/../data/nope.csv

CSV Values Are Always Strings
    [Documentation]    The trap: "17" from a CSV is text, so it fails against ${17}.
    ${rows}=    Read CSV Rows    ${USERS_CSV}
    Should Be Equal    ${rows}[1][expected_age]    17
    ${as_number}=    Convert To Integer    ${rows}[1][expected_age]
    Should Be Equal    ${as_number}    ${17}

Switching Environment Changes Every Value At Once
    [Documentation]    One argument swaps the whole config - the point of the variable file.
    ${dev}=        config.Get Variables    dev
    ${staging}=    config.Get Variables    staging
    Should Be Equal    ${staging}[ENV]    staging
    Should Contain    ${staging}[BASE_URL]    staging.
    Should Be Equal    ${staging}[TIMEOUT]    30s
    # Compared against dev, not the active ${BASE_URL} - on a staging run those match.
    Should Not Be Equal    ${staging}[BASE_URL]    ${dev}[BASE_URL]
