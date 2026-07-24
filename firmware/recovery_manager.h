/*
 * @file recovery_manager.h
 * @brief Project HEIMDALL - HMD-006 Recovery Manager Header
 *
 * Golden Reference Model for the HMD-006 Recovery Manager FSM.
 * Strict C99 implementation without dynamic allocation, interrupts, or OS dependencies.
 */

#ifndef RECOVERY_MANAGER_H
#define RECOVERY_MANAGER_H

#include <stdbool.h>
#include <stdint.h>

/* ========================================================================= */
/* Compile-Time Configuration Parameters                                     */
/* ========================================================================= */

#ifndef RESET_HOLD_CYCLES
#define RESET_HOLD_CYCLES        (5U)
#endif

#ifndef STABILIZATION_CYCLES
#define STABILIZATION_CYCLES     (10U)
#endif

#ifndef READY_TIMEOUT_CYCLES
#define READY_TIMEOUT_CYCLES     (15U)
#endif

/* ========================================================================= */
/* State Machine Definition                                                 */
/* ========================================================================= */

typedef enum {
    RM_STATE_RESET = 0,
    RM_STATE_IDLE,
    RM_STATE_ASSERT_RESET,
    RM_STATE_HOLD_RESET,
    RM_STATE_RELEASE_RESET,
    RM_STATE_WAIT_STABILIZE,
    RM_STATE_VERIFY_READY,
    RM_STATE_COMPLETE,
    RM_STATE_FAILED
} RecoveryState;

/* ========================================================================= */
/* Signal Interfaces                                                        */
/* ========================================================================= */

typedef struct {
    bool rst;
    bool recovery_start;
    bool system_ready;
} RecoveryInputs;

typedef struct {
    bool reset_request;
    bool recovery_busy;
    bool recovery_done;
    bool recovery_failed;
} RecoveryOutputs;

/* ========================================================================= */
/* Public API                                                                */
/* ========================================================================= */

/*
 * @brief Initializes the Recovery Manager FSM and resets internal counters.
 */
void recovery_manager_init(void);

/*
 * @brief Sets system inputs for the current clock cycle.
 * @param inputs Pointer to structure containing current input states.
 */
void recovery_manager_set_inputs(const RecoveryInputs *inputs);

/*
 * @brief Advances the Recovery Manager FSM by one clock tick.
 */
void recovery_manager_tick(void);

/*
 * @brief Retrieves current output signals.
 * @return Copy of the current RecoveryOutputs structure.
 */
RecoveryOutputs recovery_manager_get_outputs(void);

/*
 * @brief Helper function to get current state (useful for test verification/debugging).
 * @return Current FSM state enum value.
 */
RecoveryState recovery_manager_get_state(void);

#endif /* RECOVERY_MANAGER_H */