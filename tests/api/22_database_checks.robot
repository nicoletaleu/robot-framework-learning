*** Settings ***
Documentation    Day 22 - checking the database behind the API.
...              Every API test so far has asked the service how it went and believed
...              the answer. A 201 is a claim, not a receipt: the interesting bugs are
...              the ones where the response is perfect and nothing was written, or
...              something wrong was. The only way to catch those is to look at the
...              other end - and a test that checks both ends checks the system, not
...              the conversation.
...              SQLite, so there is no server to install and CI needs nothing extra.
...              Run:  robot --outputdir results tests/api/22_database_checks.robot
Library          RequestsLibrary
Library          Collections
Library          OperatingSystem
Library          DatabaseLibrary
Library          ../../libraries/OrderService.py
Library          ../../libraries/DataHelpers.py
Suite Setup      Start The Service And Connect To Its Database
Suite Teardown   Stop Everything
Test Setup       Start From An Empty Orders Table
Test Tags        api    database


*** Variables ***
${SESSION}    orders


*** Test Cases ***
A Healthy Write Reaches The Database
    [Documentation]    The baseline: both ends agree. 201 from the API, and a row
    ...                that holds exactly what was sent.
    [Tags]    smoke
    ${response}=    Order    espresso    ${2}
    Status Should Be    201    ${response}
    Check Row Count    SELECT * FROM orders    ==    1
    ${rows}=    Query    SELECT item, quantity FROM orders
    Should Be Equal    ${rows}[0][0]    espresso
    Should Be Equal As Integers    ${rows}[0][1]    2

A Green API Assertion Can Sit On Top Of A Broken System
    [Documentation]    The whole point of the day. The service answers 201 with an
    ...                id, every assertion an API test would make passes, and the
    ...                database is empty. A suite that only reads responses is green
    ...                while orders are being silently thrown away.
    [Tags]    smoke
    Break The Service    drop_writes
    ${response}=    Order    latte    ${1}
    # Everything an API-only test would check - all of it passes.
    Status Should Be    201    ${response}
    Dictionary Should Contain Key    ${response.json()}    id
    Should Be Equal    ${response.json()}[item]    latte
    # And the receipt says otherwise.
    Check Row Count    SELECT * FROM orders    ==    0

The Row Has To Be Read, Not Just Counted
    [Documentation]    The subtler fault: the row IS written, with the wrong values.
    ...                "a row exists" would pass. Checking what is in it is the
    ...                difference between a real check and a reassuring one.
    Break The Service    mangle_data
    ${response}=    Order    flat white    ${5}
    Status Should Be    201    ${response}
    Check Row Count    SELECT * FROM orders    ==    1
    ${rows}=    Query    SELECT item, quantity FROM orders
    Should Be Equal    ${rows}[0][0]    flat white
    # Sent 5, stored 1. The count never noticed.
    Should Be Equal As Integers    ${rows}[0][1]    1

A Delete That Deletes Nothing Still Answers 204
    [Documentation]    Same shape of bug on the way out. 204 means "done, nothing to
    ...                say" - and there is nothing in the response to contradict it.
    ${created}=    Order    cortado    ${1}
    ${id}=    Set Variable    ${created.json()}[id]
    Break The Service    drop_deletes
    ${response}=    DELETE On Session    ${SESSION}    /orders/${id}
    Status Should Be    204    ${response}
    Check Row Count    SELECT id FROM orders WHERE id = ${id}    ==    1

A Second Call Sometimes Reveals It, But Not Always
    [Documentation]    The API can catch a dropped write here, because a GET reads the
    ...                same table back. That is not a general rule - a service that
    ...                writes asynchronously, or reads from a cache, answers happily.
    ...                The database check does not depend on which of those it is.
    ...                For a write that is genuinely slow rather than missing,
    ...                Check Row Count takes retry_timeout=5s and polls instead of
    ...                sleeping - the Day 15 rule, applied to the database.
    Break The Service    drop_writes
    ${created}=    Order    macchiato    ${1}
    ${id}=    Set Variable    ${created.json()}[id]
    ${lookup}=    GET On Session    ${SESSION}    /orders/${id}    expected_status=404
    Status Should Be    404    ${lookup}

Reading The Database Proves Storage, Never Behaviour
    [Documentation]    The honest limit, the mirror of Day 21's "a stub will happily
    ...                lie". A row put there by the test itself looks exactly like one
    ...                the service wrote, so a database check alone proves nothing
    ...                about the API. The two ends are only worth anything together.
    Execute Sql String    INSERT INTO orders (item, quantity) VALUES ('planted', 3)
    Check Row Count    SELECT * FROM orders    ==    1
    # The service will serve it back without ever having created it.
    ${rows}=    Query    SELECT id FROM orders WHERE item = 'planted'
    ${response}=    GET On Session    ${SESSION}    /orders/${rows}[0][0]
    Should Be Equal    ${response.json()}[item]    planted

The Database Is State, So Every Test Starts From Empty
    [Documentation]    Day 18, one more time: this is the most shared state in the
    ...                repo. Test Setup empties the table, so no test can be made to
    ...                pass or fail by whichever one ran before it.
    Check Row Count    SELECT * FROM orders    ==    0
    Order    americano    ${1}
    Check Row Count    SELECT * FROM orders    ==    1


*** Keywords ***
Start The Service And Connect To Its Database
    [Documentation]    Suite Setup: a database file of this process's own, the service
    ...                on top of it, and one HTTP session.
    # Day 18: two pabot workers sharing one SQLite file would be sharing test data.
    ${db name}=    Unique Artifact Name    day22_orders.db
    ${db path}=    Set Variable    ${TEMPDIR}/${db name}
    Remove File    ${db path}
    Set Suite Variable    ${DB PATH}    ${db path}

    ${base url}=    Start Order Service    ${db path}
    Create Session    ${SESSION}    ${base url}
    # DatabaseLibrary talks to the same file the service writes to - no server,
    # no credentials, just a path.
    Connect To Database    db_module=sqlite3    db_name=${db path}

Stop Everything
    [Documentation]    Suite Teardown. Run Keyword And Ignore Error is deliberate:
    ...                a failure in the first step must not skip the second.
    Run Keyword And Ignore Error    Disconnect From Database
    Stop Order Service
    Remove File    ${DB PATH}

Start From An Empty Orders Table
    [Documentation]    Test Setup: empty table, healthy service. Faults are switched
    ...                on per test and must not leak into the next one.
    Repair The Service
    Delete All Rows From Table    orders

Order
    [Documentation]    POSTs an order and returns the response, whatever the status.
    [Arguments]    ${item}    ${quantity}
    ${payload}=    Create Dictionary    item=${item}    quantity=${quantity}
    ${response}=    POST On Session    ${SESSION}    /orders    json=${payload}
    ...    expected_status=any
    RETURN    ${response}
