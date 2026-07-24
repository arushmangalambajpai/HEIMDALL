#ifndef SUPERVISOR_FSM_H
#define SUPERVISOR_FSM_H

#include <stdint.h>
#include <stdbool.h>

/* ========================================================================== */
/* EVENT CODES                                                                */
/* ========================================================================== */
#define EVENT_HEARTBEAT_STARTED   0x01U
#define EVENT_HEARTBEAT_TIMEOUT   0x02U
#define EVENT_CHALLENGE_STARTED   0x03U
#define EVENT_CHALLENGE_SUCCESS   0x04U
#define EVENT_CHALLENGE_FAILURE   0x05U
#define EVENT_RECOVERY_STARTED    0x06U
#define EVENT_RECOVERY_COMPLETED  0x07U

/* ========================================================================== */
/* FSM STATES                                                                 */
/* ========================================================================== */
typedef enum {
    STATE_RESET = 0,
    STATE_INIT,
    STATE_IDLE,
    STATE_HEARTBEAT_START,
    STATE_WAIT_HEARTBEAT,
    STATE_CHALLENGE_START,
    STATE_WAIT_CHALLENGE,
    STATE_FAILURE_CHECK,
    STATE_RECOVERY,
    STATE_WAIT_RECOVERY
} SupervisorState_t;

/* ========================================================================== */
/* INPUTS                                                                     */
/* ========================================================================== */
typedef struct {
    bool heartbeat_enable;
    bool challenge_enable;
    uint32_t heartbeat_period;
    uint32_t challenge_period;
    uint8_t max_failure_count;
    bool heartbeat_timeout;
    bool challenge_busy;
    bool challenge_done;
    bool challenge_ok;
    bool recovery_complete;
} SupervisorInputs_t;

/* ========================================================================== */
/* OUTPUTS                                                                    */
/* ========================================================================== */
typedef struct {
    bool heartbeat_start;
    bool challenge_start;
    bool log_event;
    uint8_t log_event_code;
    bool recovery_start;
    bool system_fault;
} SupervisorOutputs_t;

/* ========================================================================== */
/* FSM CONTEXT                                                                */
/* ========================================================================== */
typedef struct {
    SupervisorState_t state;
    
    /* Internal Variables */
    uint32_t heartbeat_timer;
    uint32_t challenge_timer;
    uint8_t failure_counter;
    
    /* Signal Interfaces */
    SupervisorInputs_t inputs;
    SupervisorOutputs_t outputs;
} SupervisorFSM_t;

/* ========================================================================== */
/* PUBLIC API                                                                 */
/* ========================================================================== */

/**
 * @brief Initializes the Supervisor FSM structure and resets internal context.
 * @fsm: Pointer to SupervisorFSM instance.
 */
void SupervisorFSM_Init(SupervisorFSM_t *fsm);

/**
 * @brief Executes exactly one iteration (tick) of the Supervisor FSM.
 * @fsm: Pointer to SupervisorFSM instance.
 */
void SupervisorFSM_Run(SupervisorFSM_t *fsm);

#endif /* SUPERVISOR_FSM_H */