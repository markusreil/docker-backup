*** Settings ***
Documentation    Kopia end-to-end: the merged agent snapshots a labeled volume
...              to the central server, and the snapshot restores byte-identical.
Library    OperatingSystem
Library    Process
Library    String
Suite Setup    Start Kopia Stacks
Suite Teardown    Stop Kopia Stacks

*** Variables ***
${ROOT}       /home/mreil/projects/mreil/docker-images/docker-backup
${TIMEOUT}    4 min
${RETRY}      5 sec
${VOL}        test-cluster_demo-vol
${MNT}        /mnt/test-cluster_demo-vol


*** Test Cases ***
Labeled Volume Is Snapshotted To Server
    [Documentation]    Agent renders the demo volume from its label and
    ...                snapshots it; the snapshot is listed at the agent.
    Wait Until Keyword Succeeds    ${TIMEOUT}    ${RETRY}
    ...    Snapshot Should Exist    ${MNT}

Snapshot Restores Byte-Identical Content
    [Documentation]    Restoring the latest snapshot reproduces the sentinel.
    ${dir}=    Set Variable    /tmp/restore-${SENTINEL}
    Wait Until Keyword Succeeds    ${TIMEOUT}    ${RETRY}
    ...    Restore Should Contain    ${MNT}    ${dir}    sentinel.txt    ${SENTINEL}


*** Keywords ***
Start Kopia Stacks
    Server Compose    up    -d
    Wait Until Keyword Succeeds    ${TIMEOUT}    ${RETRY}
    ...    Server Fingerprint Should Exist
    ${fp}=    Server Compose    exec    -T    server    cat    /repo/certs/fingerprint
    ${fp}=    Strip String    ${fp}
    ${tpl}=    Get File    ${ROOT}/test/cluster/env.example
    ${env}=    Replace String    ${tpl}    replace-me-with-server-fingerprint    ${fp}
    Create File    ${ROOT}/test/cluster/.env    ${env}
    Compose    ${ROOT}/test/cluster    up    -d    --build
    Wait Until Keyword Succeeds    ${TIMEOUT}    ${RETRY}
    ...    Cluster Log Should Contain    agent    Watching docker events
    ${SENTINEL}=    Generate Random String    12    [LETTERS][NUMBERS]
    Set Suite Variable    ${SENTINEL}    ${SENTINEL}
    ${w}=    Run Process    docker    exec    test-cluster-demo-1
    ...    sh    -c    echo ${SENTINEL} > /data/sentinel.txt
    Should Be Equal As Integers    ${w.rc}    0    msg=${w.stderr}

Stop Kopia Stacks
    Compose    ${ROOT}/test/cluster    down    --remove-orphans
    Run Process    docker    volume    rm    test-cluster_demo-vol
    Server Compose    down

Compose
    [Arguments]    ${dir}    @{args}
    ${r}=    Run Process    docker    compose    @{args}    cwd=${dir}
    Should Be Equal As Integers    ${r.rc}    0    msg=${r.stderr}
    RETURN    ${r.stdout}

Server Compose
    [Arguments]    @{args}
    ${r}=    Run Process    docker    compose    --env-file    env.test    @{args}    cwd=${ROOT}/server
    Should Be Equal As Integers    ${r.rc}    0    msg=${r.stderr}
    RETURN    ${r.stdout}

Cluster Exec
    [Arguments]    ${service}    @{cmd}
    ${r}=    Run Process    docker    compose    exec    -T    ${service}    @{cmd}    cwd=${ROOT}/test/cluster
    Should Be Equal As Integers    ${r.rc}    0    msg=${r.stderr}
    RETURN    ${r.stdout}

Cluster Log Should Contain
    [Arguments]    ${service}    ${text}
    ${logs}=    Compose    ${ROOT}/test/cluster    logs    ${service}
    Should Contain    ${logs}    ${text}

Server Fingerprint Should Exist
    Server Compose    exec    -T    server    cat    /repo/certs/fingerprint

Snapshot Should Exist
    [Arguments]    ${path}
    ${listing}=    Kopia    snapshot    list    ${path}
    Should Contain    ${listing}    ${path}

Restore Should Contain
    [Arguments]    ${source}    ${dir}    ${file}    ${expected}
    ${snap}=    Latest Snapshot Id    ${source}
    Kopia    snapshot    restore    ${snap}    ${dir}
    ${found}=    Cluster Exec    agent    find    ${dir}    -name    ${file}
    ${path}=    Strip String    ${found}
    Should Not Be Empty    ${path}
    ${content}=    Cluster Exec    agent    cat    ${path}
    Should Contain    ${content}    ${expected}

Latest Snapshot Id
    [Arguments]    ${path}
    ${pipeline}=    Catenate    SEPARATOR=${SPACE}
    ...    kopia-auth snapshot list --json ${path} | yq -r '.[-1].rootEntry.obj'
    ${out}=    Cluster Exec    agent    sh    -c    ${pipeline}
    ${snap}=    Strip String    ${out}
    Should Not Be Empty    ${snap}
    RETURN    ${snap}

Kopia
    [Documentation]    Run kopia in the agent with the persisted user password.
    [Arguments]    @{cmd}
    ${r}=    Run Process    docker    compose    exec    -T    agent
    ...    kopia-auth    @{cmd}
    ...    cwd=${ROOT}/test/cluster
    Should Be Equal As Integers    ${r.rc}    0    msg=${r.stderr}
    RETURN    ${r.stdout}
