#include "supervisor_fsm.h"
#include <stddef.h>

void SupervisorFSM_Init(SupervisorFSM_t *fsm)
{
    if (fsm == NULL) {
        return;
    }

    /* Initialize internal state and variables */
    fsm->state = STATE_RESET;
    fsm->heartbeat_timer = 0U;
    fsm->challenge_timer = 0U;
    fsm->failure_counter = 0U;

    /* Initialize inputs */
    fsm->inputs.heartbeat_enable = false;
    fsm->inputs.challenge_enable = false;
    fsm->inputs.heartbeat_period = 0U;
    fsm->inputs.challenge_period = 0U;
    fsm->inputs.max_failure_count = 0U;
    fsm->inputs.heartbeat_timeout = false;
    fsm->inputs.challenge_busy = false;
    fsm->inputs.challenge_done = false;
    fsm->inputs.challenge_ok = false;
    fsm->inputs.recovery_complete = false;

    /* Initialize outputs */
    fsm->outputs.heartbeat_start = false;
    fsm->outputs.challenge_start = false;
    fsm->outputs.log_event = false;
    fsm->outputs.log_event_code = 0x00U;
    fsm->outputs.recovery_start = false;
    fsm->outputs.system_fault = false;
}

void SupervisorFSM_Run(SupervisorFSM_t *fsm)
{
    if (fsm == NULL) {
        return;
    }

    /* Clear single-cycle pulse outputs at the start of every iteration */
    fsm->outputs.heartbeat_start = false;
    fsm->outputs.challenge_start = false;
    fsm->outputs.log_event = false;
    fsm->outputs.log_event_code = 0x00U;
    fsm->outputs.recovery_start = false;

    switch (fsm->state) {
        case STATE_RESET:
            /* Reset timers, counters, and outputs */
            fsm->heartbeat_timer = 0U;
            fsm->challenge_timer = 0U;
            fsm->failure_counter = 0U;
            fsm->outputs.system_fault = false;

            /* Transition to INIT */
            fsm->state = STATE_INIT;
            break;

        case STATE_INIT:
            /* Initialize timers and counters */
            fsm->heartbeat_timer = 0U;
            fsm->challenge_timer = 0U;
            fsm->failure_counter = 0U;
            fsm->outputs.system_fault = false;

            /* Transition to IDLE */
            fsm->state = STATE_IDLE;
            break;

        case STATE_IDLE:
            /* Increment timers */
            fsm->heartbeat_timer++;
            fsm->challenge_timer++;

            /* Priority: Heartbeat has higher priority than Challenge */
            if (fsm->inputs.heartbeat_enable && 
               (fsm->heartbeat_timer >= fsm->inputs.heartbeat_period)) {
                fsm->state = STATE_HEARTBEAT_START;
            }
            else if (fsm->inputs.challenge_enable && 
                    (fsm->challenge_timer >= fsm->inputs.challenge_period)) {
                fsm->state = STATE_CHALLENGE_START;
            }
            break;

        case STATE_HEARTBEAT_START:
            /* Assert heartbeat_start for one iteration */
            fsm->outputs.heartbeat_start = true;

            /* Generate event 0x01 */
            fsm->outputs.log_event = true;
            fsm->outputs.log_event_code = EVENT_HEARTBEAT_STARTED;

            /* Immediately go to WAIT_HEARTBEAT */
            fsm->state = STATE_WAIT_HEARTBEAT;
            break;

        case STATE_WAIT_HEARTBEAT:
            if (!fsm->inputs.heartbeat_timeout) {
                /* Heartbeat succeeded / No timeout */
                fsm->heartbeat_timer = 0U;
                fsm->state = STATE_IDLE;
            }
            else {
                /* Heartbeat timeout detected */
                fsm->outputs.log_event = true;
                fsm->outputs.log_event_code = EVENT_HEARTBEAT_TIMEOUT;
                fsm->failure_counter++;
                fsm->state = STATE_FAILURE_CHECK;
            }
            break;

        case STATE_CHALLENGE_START:
            /* Assert challenge_start */
            fsm->outputs.challenge_start = true;

            /* Generate event 0x03 */
            fsm->outputs.log_event = true;
            fsm->outputs.log_event_code = EVENT_CHALLENGE_STARTED;

            fsm->state = STATE_WAIT_CHALLENGE;
            break;

        case STATE_WAIT_CHALLENGE:
            if ((!fsm->inputs.challenge_busy) && (fsm->inputs.challenge_done)) {
                if (fsm->inputs.challenge_ok) {
                    /* Challenge success */
                    fsm->outputs.log_event = true;
                    fsm->outputs.log_event_code = EVENT_CHALLENGE_SUCCESS;
                    fsm->challenge_timer = 0U;
                    fsm->state = STATE_IDLE;
                }
                else {
                    /* Challenge failure */
                    fsm->outputs.log_event = true;
                    fsm->outputs.log_event_code = EVENT_CHALLENGE_FAILURE;
                    fsm->failure_counter++;
                    fsm->state = STATE_FAILURE_CHECK;
                }
            }
            break;

        case STATE_FAILURE_CHECK:
            if ((fsm->inputs.max_failure_count == 0U) || (fsm->failure_counter >= fsm->inputs.max_failure_count)) {
                fsm->state = STATE_RECOVERY;
            }
            else {
                fsm->state = STATE_IDLE;
            }
            break;

        case STATE_RECOVERY:
            /* Assert recovery_start and system_fault */
            fsm->outputs.recovery_start = true;
            fsm->outputs.system_fault = true;

            /* Generate event 0x06 */
            fsm->outputs.log_event = true;
            fsm->outputs.log_event_code = EVENT_RECOVERY_STARTED;

            fsm->state = STATE_WAIT_RECOVERY;
            break;

        case STATE_WAIT_RECOVERY:
            if (fsm->inputs.recovery_complete) {
                /* Generate event 0x07 */
                fsm->outputs.log_event = true;
                fsm->outputs.log_event_code = EVENT_RECOVERY_COMPLETED;

                fsm->failure_counter = 0U;
                fsm->outputs.system_fault = false;
                fsm->state = STATE_INIT;
            }
            break;

        default:
            fsm->state = STATE_RESET;
            break;
    }
}