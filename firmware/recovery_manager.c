/*
 * @file recovery_manager.c
 * @brief Project HEIMDALL - HMD-006 Recovery Manager Implementation
 */

#include "recovery_manager.h"
#include <stddef.h>

/* ========================================================================= */
/* Private Module State Variables                                           */
/* ========================================================================= */

static RecoveryState g_state = RM_STATE_RESET;
static RecoveryInputs g_inputs = { false, false, false };
static RecoveryOutputs g_outputs = { false, false, false, false };
static uint32_t g_delay_counter = 0U;
static uint32_t g_timeout_counter = 0U;
/* ========================================================================= */
/* Private Helper Functions                                                  */
/* ========================================================================= */

static void update_outputs(void)
{
    g_outputs.reset_request  = (g_state == RM_STATE_ASSERT_RESET) || 
                               (g_state == RM_STATE_HOLD_RESET);
    
    g_outputs.recovery_busy  = (g_state != RM_STATE_IDLE) && 
                               (g_state != RM_STATE_RESET);
    
    g_outputs.recovery_done   = (g_state == RM_STATE_COMPLETE);
    g_outputs.recovery_failed = (g_state == RM_STATE_FAILED);
}

/* ========================================================================= */
/* Public API Implementation                                                 */
/* ========================================================================= */

void recovery_manager_init(void)
{
    g_state = RM_STATE_RESET;

    g_inputs.rst = false;
    g_inputs.recovery_start = false;
    g_inputs.system_ready = false;

    g_delay_counter = 0U;
    g_timeout_counter = 0U;
    update_outputs();
}

void recovery_manager_set_inputs(const RecoveryInputs *inputs)
{
    if (inputs != NULL) {
        g_inputs = *inputs;
    }
}

RecoveryOutputs recovery_manager_get_outputs(void)
{
    return g_outputs;
}

RecoveryState recovery_manager_get_state(void)
{
    return g_state;
}

void recovery_manager_tick(void)
{
    if (g_inputs.rst)
        {
            g_state = RM_STATE_RESET;
        
            g_delay_counter = 0U;
            g_timeout_counter = 0U;
        
            update_outputs();
        
            return;
        }

    switch (g_state) {
        case RM_STATE_RESET:
        g_delay_counter = 0U;
        g_timeout_counter = 0U;
        g_state = RM_STATE_IDLE;
            break;

        case RM_STATE_IDLE:
            g_delay_counter = 0U;
            g_timeout_counter = 0U;
            if (g_inputs.recovery_start) {
                g_state = RM_STATE_ASSERT_RESET;
            }
            break;

        case RM_STATE_ASSERT_RESET:
            g_delay_counter = 1U;
            if (RESET_HOLD_CYCLES == 0U) {
                g_state = RM_STATE_RELEASE_RESET;
            } else {
                g_state = RM_STATE_HOLD_RESET;
            }
            break;

        case RM_STATE_HOLD_RESET:
            g_delay_counter++;
            if (g_delay_counter >= RESET_HOLD_CYCLES) {
                g_state = RM_STATE_RELEASE_RESET;
            }
            break;

        case RM_STATE_RELEASE_RESET:
            g_delay_counter = 1U;
            if (STABILIZATION_CYCLES == 0U) {
                g_state = RM_STATE_VERIFY_READY;
            } else {
                g_state = RM_STATE_WAIT_STABILIZE;
            }
            break;

        case RM_STATE_WAIT_STABILIZE:
            g_delay_counter++;
            if (g_delay_counter > STABILIZATION_CYCLES) {
                g_timeout_counter = 0U;
                g_state = RM_STATE_VERIFY_READY;
            }
            break;

        case RM_STATE_VERIFY_READY:
            if (g_inputs.system_ready) {
                g_delay_counter = 0U;
                g_state = RM_STATE_COMPLETE;
            } else {
                if (++g_timeout_counter == READY_TIMEOUT_CYCLES) {
                    g_delay_counter = 0U;
                    g_state = RM_STATE_FAILED;
                }
            }
            break;

        case RM_STATE_COMPLETE:
           
            g_delay_counter = 0U;
            g_timeout_counter = 0U;
            g_state = RM_STATE_IDLE;
            
        
            break;

        case RM_STATE_FAILED:

            g_delay_counter = 0U;
            g_timeout_counter = 0U;
            g_state = RM_STATE_IDLE;
            
        
            break;
            

        default:
            g_state = RM_STATE_RESET;
            break;
    }

    update_outputs();
}