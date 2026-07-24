#include <stdio.h>
#include <stdbool.h>
#include "supervisor_fsm.h"

/* Helper macro for printing test results */
#define TEST_ASSERT(cond, name) \
    do { \
        if (cond) { \
            printf("[PASS] %s\n", name); \
        } else { \
            printf("[FAIL] %s\n", name); \
            all_passed = false; \
        } \
    } while(0)

int main(void)
{
    SupervisorFSM_t fsm;
    bool all_passed = true;

    printf("====================================================\n");
    printf("  HEIMDALL - HMD-005 Supervisor FSM Unit Tests\n");
    printf("====================================================\n\n");

    /* ---------------------------------------------------- */
    /* TEST 1: Reset & Init Transition                       */
    /* ---------------------------------------------------- */
    SupervisorFSM_Init(&fsm);
    TEST_ASSERT(fsm.state == STATE_RESET, "Test 1.1: Initial State is RESET");

    SupervisorFSM_Run(&fsm); /* RESET -> INIT */
    TEST_ASSERT(fsm.state == STATE_INIT, "Test 1.2: State transitions to INIT");

    SupervisorFSM_Run(&fsm); /* INIT -> IDLE */
    TEST_ASSERT(fsm.state == STATE_IDLE, "Test 1.3: State transitions to IDLE");

    /* Configure FSM parameters */
    fsm.inputs.max_failure_count = 2U;
    fsm.inputs.heartbeat_period = 3U;
    fsm.inputs.challenge_period = 5U;

    /* ---------------------------------------------------- */
    /* TEST 2: Normal Heartbeat Cycle                        */
    /* ---------------------------------------------------- */
    fsm.inputs.heartbeat_enable = true;
    fsm.inputs.challenge_enable = false;

    /* Tick 1 & 2: Increment heartbeat timer */
    SupervisorFSM_Run(&fsm); /* timer = 1 */
    SupervisorFSM_Run(&fsm); /* timer = 2 */
    SupervisorFSM_Run(&fsm); /* timer = 3 -> Transition to HEARTBEAT_START */

    TEST_ASSERT(fsm.state == STATE_HEARTBEAT_START, "Test 2.1: Reached HEARTBEAT_START");

    SupervisorFSM_Run(&fsm); /* Execute HEARTBEAT_START */
    TEST_ASSERT(fsm.outputs.heartbeat_start == true, "Test 2.2: heartbeat_start asserted");
    TEST_ASSERT(fsm.outputs.log_event == true && fsm.outputs.log_event_code == EVENT_HEARTBEAT_STARTED,
                "Test 2.3: Log event 0x01 (Heartbeat Started)");
    TEST_ASSERT(fsm.state == STATE_WAIT_HEARTBEAT, "Test 2.4: State is WAIT_HEARTBEAT");

    /* Simulate normal heartbeat response (no timeout) */
    fsm.inputs.heartbeat_timeout = false;
    SupervisorFSM_Run(&fsm); /* Process WAIT_HEARTBEAT -> IDLE */
    TEST_ASSERT(fsm.state == STATE_IDLE, "Test 2.5: Heartbeat success returns to IDLE");
    TEST_ASSERT(fsm.heartbeat_timer == 0U, "Test 2.6: heartbeat_timer reset to 0");
    fsm.challenge_timer = 0U;
    /* ---------------------------------------------------- */
    /* TEST 3: Normal Challenge Cycle                        */
    /* ---------------------------------------------------- */
    fsm.inputs.heartbeat_enable = false;
    fsm.inputs.challenge_enable = true;

    /* Tick IDLE until timer reaches challenge_period (5) */
    for (int i = 0; i < 5; i++) {
        SupervisorFSM_Run(&fsm);
    }
    TEST_ASSERT(fsm.state == STATE_CHALLENGE_START, "Test 3.1: Reached CHALLENGE_START");

    SupervisorFSM_Run(&fsm); /* Execute CHALLENGE_START */
    TEST_ASSERT(fsm.outputs.challenge_start == true, "Test 3.2: challenge_start asserted");
    TEST_ASSERT(fsm.outputs.log_event == true && fsm.outputs.log_event_code == EVENT_CHALLENGE_STARTED,
                "Test 3.3: Log event 0x03 (Challenge Started)");
    TEST_ASSERT(fsm.state == STATE_WAIT_CHALLENGE, "Test 3.4: State is WAIT_CHALLENGE");

    /* Simulate challenge completion with success */
    fsm.inputs.challenge_done = true;
    fsm.inputs.challenge_ok = true;
    SupervisorFSM_Run(&fsm);
    TEST_ASSERT(fsm.outputs.log_event == true && fsm.outputs.log_event_code == EVENT_CHALLENGE_SUCCESS,
                "Test 3.5: Log event 0x04 (Challenge Success)");
    TEST_ASSERT(fsm.state == STATE_IDLE, "Test 3.6: Challenge success returns to IDLE");
    TEST_ASSERT(fsm.challenge_timer == 0U, "Test 3.7: challenge_timer reset to 0");

    /* ---------------------------------------------------- */
    /* TEST 4: Challenge Failure                             */
    /* ---------------------------------------------------- */
    fsm.inputs.challenge_done = false;
    fsm.challenge_timer = 0U;
    /* Tick IDLE to start another challenge */
    for (int i = 0; i < 5; i++) {
        SupervisorFSM_Run(&fsm);
    }
    SupervisorFSM_Run(&fsm); /* Execute CHALLENGE_START -> WAIT_CHALLENGE */

    /* Simulate challenge failure */
    fsm.inputs.challenge_done = true;
    fsm.inputs.challenge_ok = false;
    SupervisorFSM_Run(&fsm); /* Process WAIT_CHALLENGE -> FAILURE_CHECK */

    TEST_ASSERT(fsm.outputs.log_event == true && fsm.outputs.log_event_code == EVENT_CHALLENGE_FAILURE,
                "Test 4.1: Log event 0x05 (Challenge Failure)");
    TEST_ASSERT(fsm.failure_counter == 1U, "Test 4.2: failure_counter incremented to 1");
    TEST_ASSERT(fsm.state == STATE_FAILURE_CHECK, "Test 4.3: State is FAILURE_CHECK");

    SupervisorFSM_Run(&fsm); /* Process FAILURE_CHECK -> IDLE (1 < max 2) */
    TEST_ASSERT(fsm.state == STATE_IDLE, "Test 4.4: Returns to IDLE because max_failure_count not reached");

    /* ---------------------------------------------------- */
    /* TEST 5: Heartbeat Timeout                             */
    /* ---------------------------------------------------- */
    fsm.inputs.heartbeat_enable = true;
    fsm.inputs.challenge_enable = false;
    fsm.heartbeat_timer = 0U;
    /* Advance to HEARTBEAT_START */
    for (int i = 0; i < 3; i++) {
        SupervisorFSM_Run(&fsm);
    }
    SupervisorFSM_Run(&fsm); /* Execute HEARTBEAT_START -> WAIT_HEARTBEAT */

    /* Simulate heartbeat timeout */
    fsm.inputs.heartbeat_timeout = true;
    SupervisorFSM_Run(&fsm); /* Process WAIT_HEARTBEAT -> FAILURE_CHECK */

    TEST_ASSERT(fsm.outputs.log_event == true && fsm.outputs.log_event_code == EVENT_HEARTBEAT_TIMEOUT,
                "Test 5.1: Log event 0x02 (Heartbeat Timeout)");
    TEST_ASSERT(fsm.failure_counter == 2U, "Test 5.2: failure_counter incremented to 2");

    /* ---------------------------------------------------- */
    /* TEST 6: Failure Escalation to Recovery                */
    /* ---------------------------------------------------- */
    SupervisorFSM_Run(&fsm); /* Process FAILURE_CHECK -> RECOVERY (2 >= max 2) */
    TEST_ASSERT(fsm.state == STATE_RECOVERY, "Test 6.1: Escalated to RECOVERY state");

    /* ---------------------------------------------------- */
    /* TEST 7: Recovery Execution                            */
    /* ---------------------------------------------------- */
    SupervisorFSM_Run(&fsm); /* Execute RECOVERY -> WAIT_RECOVERY */
    TEST_ASSERT(fsm.outputs.recovery_start == true, "Test 7.1: recovery_start asserted");
    TEST_ASSERT(fsm.outputs.system_fault == true, "Test 7.2: system_fault asserted");
    TEST_ASSERT(fsm.outputs.log_event == true && fsm.outputs.log_event_code == EVENT_RECOVERY_STARTED,
                "Test 7.3: Log event 0x06 (Recovery Started)");
    TEST_ASSERT(fsm.state == STATE_WAIT_RECOVERY, "Test 7.4: State is WAIT_RECOVERY");

    /* Simulate recovery completion */
    fsm.inputs.recovery_complete = true;
    SupervisorFSM_Run(&fsm); /* Process WAIT_RECOVERY -> INIT */

    TEST_ASSERT(fsm.outputs.log_event == true && fsm.outputs.log_event_code == EVENT_RECOVERY_COMPLETED,
                "Test 7.5: Log event 0x07 (Recovery Completed)");
    TEST_ASSERT(fsm.failure_counter == 0U, "Test 7.6: failure_counter reset to 0");
    TEST_ASSERT(fsm.outputs.system_fault == false, "Test 7.7: system_fault cleared");
    TEST_ASSERT(fsm.state == STATE_INIT, "Test 7.8: State returned to INIT");

    /* ---------------------------------------------------- */
    /* TEST 8: Return to IDLE from INIT                      */
    /* ---------------------------------------------------- */
    SupervisorFSM_Run(&fsm); /* Process INIT -> IDLE */
    TEST_ASSERT(fsm.state == STATE_IDLE, "Test 8.1: Normal operation resumed at IDLE");

    printf("\n====================================================\n");
    if (all_passed) {
        printf("  OVERALL UNIT TEST RESULT: ALL TESTS PASSED\n");
    } else {
        printf("  OVERALL UNIT TEST RESULT: TESTS FAILED\n");
    }
    printf("====================================================\n");

    return all_passed ? 0 : 1;
}