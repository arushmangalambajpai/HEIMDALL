/* challenge_engine.c */

#include "challenge_engine.h"

static challenge_state_t s_state = CHALLENGE_IDLE;
static bool s_ok = false;

void challenge_init(void)
{
    s_state = CHALLENGE_IDLE;
    s_ok = false;
}

void challenge_start(void)
{
    s_state = CHALLENGE_WAIT_RESPONSE;
    s_ok = false;
}

void challenge_tick(
    bool response_valid,
    uint32_t expected_response,
    uint32_t received_response
)
{
    switch (s_state) {
        case CHALLENGE_IDLE:
            /* Engine is inactive; ignore ticks until challenge_start() */
            break;

        case CHALLENGE_WAIT_RESPONSE:
            if (response_valid) {
                s_state = CHALLENGE_COMPARE;
                /* Transition to COMPARE and evaluate match on same tick */
                s_ok = (expected_response == received_response);
                s_state = CHALLENGE_DONE;
            }
            break;

        case CHALLENGE_COMPARE:
            s_ok = (expected_response == received_response);
            s_state = CHALLENGE_DONE;
            break;

        case CHALLENGE_DONE:
            /* Retain DONE state for exactly one tick, then auto-return to IDLE */
            s_state = CHALLENGE_IDLE;
            break;

        default:
            s_state = CHALLENGE_IDLE;
            s_ok = false;
            break;
    }
}

bool challenge_busy(void)
{
    return (s_state != CHALLENGE_IDLE);
}

bool challenge_done(void)
{
    return (s_state == CHALLENGE_DONE);
}

bool challenge_ok(void)
{
    return s_ok;
}