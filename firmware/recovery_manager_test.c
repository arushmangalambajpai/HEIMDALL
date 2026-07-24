/**
 * @file recovery_manager_test.c
 * @brief Standard C Unit Test Suite for HMD-006 Recovery Manager
 */

#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>
#include "recovery_manager.h"

static uint32_t g_tests_run = 0;
static uint32_t g_tests_passed = 0;

#define ASSERT_TEST(cond, name) do { \
    g_tests_run++; \
    if (cond) { \
        g_tests_passed++; \
        printf("[PASS] %s\n", name); \
    } else { \
        printf("[FAIL] %s (Line %d)\n", name, __LINE__); \
    } \
} while(0)

/* Helper function to step N cycles with static inputs */
static void step_cycles(uint32_t cycles, RecoveryInputs inputs) {
    recovery_manager_set_inputs(&inputs);
    for (uint32_t i = 0; i < cycles; i++) {
        recovery_manager_tick();
    }
}

/* ========================================================================= */
/* Test Cases (1-16)                                                         */
/* ========================================================================= */

/* Test 1: Power-up reset transition to IDLE */
static void test_01_power_up_reset(void) {
    recovery_manager_init();
    ASSERT_TEST(recovery_manager_get_state() == RM_STATE_RESET, "Test 1a: Init state is RM_STATE_RESET");
    
    recovery_manager_tick();
    RecoveryOutputs out = recovery_manager_get_outputs();
    ASSERT_TEST(recovery_manager_get_state() == RM_STATE_IDLE, "Test 1b: Transition to RM_STATE_IDLE on tick");
    ASSERT_TEST(!out.reset_request && !out.recovery_busy && !out.recovery_done && !out.recovery_failed,
                "Test 1c: All outputs low in IDLE");
}

/* Test 2: Idle state holding */
static void test_02_idle_state(void) {
    recovery_manager_init();
    recovery_manager_tick(); /* Move to IDLE */
    
    RecoveryInputs in = { .recovery_start = false, .system_ready = false };
    step_cycles(10, in);
    
    RecoveryOutputs out = recovery_manager_get_outputs();
    ASSERT_TEST(recovery_manager_get_state() == RM_STATE_IDLE, "Test 2a: Remains in IDLE with no start");
    ASSERT_TEST(!out.recovery_busy, "Test 2b: Busy remains low");
}

/* Test 3: Recovery request triggers FSM */
static void test_03_recovery_request(void) {
    recovery_manager_init();
    recovery_manager_tick(); /* IDLE */
    
    RecoveryInputs in = { .recovery_start = true, .system_ready = false };
    recovery_manager_set_inputs(&in);
    recovery_manager_tick();
    
    ASSERT_TEST(recovery_manager_get_state() == RM_STATE_ASSERT_RESET, "Test 3a: Enters ASSERT_RESET");
    ASSERT_TEST(recovery_manager_get_outputs().recovery_busy, "Test 3b: Busy signal goes high");
}

/* Test 4: Reset assertion outputs */
static void test_04_reset_assertion(void) {
    recovery_manager_init();
    recovery_manager_tick(); /* IDLE */
    
    RecoveryInputs in = { .recovery_start = true, .system_ready = false };
    recovery_manager_set_inputs(&in);
    recovery_manager_tick();
    
    RecoveryOutputs out = recovery_manager_get_outputs();
    ASSERT_TEST(out.reset_request, "Test 4a: reset_request high in ASSERT_RESET");
    ASSERT_TEST(out.recovery_busy, "Test 4b: recovery_busy high in ASSERT_RESET");
}

/* Test 5: Reset hold timing */
static void test_05_reset_hold_timing(void) {
    recovery_manager_init();
    recovery_manager_tick(); /* IDLE */
    
    RecoveryInputs in = { .recovery_start = true, .system_ready = false };
    recovery_manager_set_inputs(&in);
    recovery_manager_tick(); /* ASSERT_RESET (Cycle 1) */
    
    in.recovery_start = false;
    recovery_manager_set_inputs(&in);
    
    /* Step remaining RESET_HOLD_CYCLES - 1 cycles in HOLD_RESET */
    for (uint32_t i = 2; i <= RESET_HOLD_CYCLES; i++) {
        recovery_manager_tick();
        ASSERT_TEST(recovery_manager_get_state() == RM_STATE_HOLD_RESET, "Test 5a: In HOLD_RESET");
        ASSERT_TEST(recovery_manager_get_outputs().reset_request, "Test 5b: reset_request held");
    }
    
    recovery_manager_tick();
    ASSERT_TEST(recovery_manager_get_state() == RM_STATE_RELEASE_RESET, "Test 5c: Transition to RELEASE_RESET");
}

/* Test 6: Reset release transition */
static void test_06_reset_release(void) {
    recovery_manager_init();
    recovery_manager_tick(); /* IDLE */
    
    RecoveryInputs in = { .recovery_start = true, .system_ready = false };
    step_cycles(1 + RESET_HOLD_CYCLES, in); /* Reaches RELEASE_RESET */
    
    RecoveryOutputs out = recovery_manager_get_outputs();
    ASSERT_TEST(recovery_manager_get_state() == RM_STATE_RELEASE_RESET, "Test 6a: State is RELEASE_RESET");
    ASSERT_TEST(!out.reset_request, "Test 6b: reset_request drops low");
    ASSERT_TEST(out.recovery_busy, "Test 6c: recovery_busy remains high");
}

/* Test 7: Stabilization delay timing */
static void test_07_stabilization_delay(void) {
    recovery_manager_init();
    recovery_manager_tick(); /* IDLE */
    
    RecoveryInputs in = { .recovery_start = true, .system_ready = false };
    step_cycles(1 + RESET_HOLD_CYCLES, in); /* Reaches RELEASE_RESET */
    
    in.recovery_start = false;
    recovery_manager_set_inputs(&in);
    
    recovery_manager_tick(); /* Enters WAIT_STABILIZE (Cycle 1) */
    ASSERT_TEST(recovery_manager_get_state() == RM_STATE_WAIT_STABILIZE, "Test 7a: Enters WAIT_STABILIZE");
    
    for (uint32_t i = 2; i <= STABILIZATION_CYCLES; i++) {
        recovery_manager_tick();
        ASSERT_TEST(recovery_manager_get_state() == RM_STATE_WAIT_STABILIZE, "Test 7b: Waiting stabilization");
    }
    
    recovery_manager_tick();
    ASSERT_TEST(recovery_manager_get_state() == RM_STATE_VERIFY_READY, "Test 7c: Transitions to VERIFY_READY");
}

/* Test 8: Immediate ready upon reaching VERIFY_READY */
static void test_08_immediate_ready(void) {
    recovery_manager_init();
    recovery_manager_tick(); /* IDLE */
    
    RecoveryInputs in = { .recovery_start = true, .system_ready = false };
    step_cycles(1 + RESET_HOLD_CYCLES + 1 + STABILIZATION_CYCLES, in); /* VERIFY_READY */
    
    ASSERT_TEST(recovery_manager_get_state() == RM_STATE_VERIFY_READY, "Test 8a: Reached VERIFY_READY");
    
    in.recovery_start = false;
    in.system_ready = true;
    recovery_manager_set_inputs(&in);
    recovery_manager_tick();
    
    ASSERT_TEST(recovery_manager_get_state() == RM_STATE_COMPLETE, "Test 8b: Immediate transition to COMPLETE");
}

/* Test 9: Delayed system_ready assertion */
static void test_09_delayed_ready(void) {
    recovery_manager_init();
    recovery_manager_tick(); /* IDLE */
    
    RecoveryInputs in = { .recovery_start = true, .system_ready = false };
    step_cycles(1 + RESET_HOLD_CYCLES + 1 + STABILIZATION_CYCLES, in); /* VERIFY_READY */
    
    in.recovery_start = false;
    step_cycles(READY_TIMEOUT_CYCLES - 3, in);
    ASSERT_TEST(recovery_manager_get_state() == RM_STATE_VERIFY_READY, "Test 9a: Still in VERIFY_READY");
    
    in.system_ready = true;
    recovery_manager_set_inputs(&in);
    recovery_manager_tick();
    
    ASSERT_TEST(recovery_manager_get_state() == RM_STATE_COMPLETE, "Test 9b: Transitions to COMPLETE after delay");
}

/* Test 10: Ready timeout detection */
static void test_10_ready_timeout(void) {
    recovery_manager_init();
    recovery_manager_tick(); /* IDLE */
    
    RecoveryInputs in = { .recovery_start = true, .system_ready = false };
    step_cycles(1 + RESET_HOLD_CYCLES + 1 + STABILIZATION_CYCLES, in); /* VERIFY_READY */
    
    in.recovery_start = false;
    step_cycles(READY_TIMEOUT_CYCLES, in);
    
    ASSERT_TEST(recovery_manager_get_state() == RM_STATE_FAILED, "Test 10: State transitions to FAILED on timeout");
}

/* Test 11: Recovery failure output assertion */
static void test_11_recovery_failure(void) {
    recovery_manager_init();
    recovery_manager_tick(); /* IDLE */
    
    RecoveryInputs in = { .recovery_start = true, .system_ready = false };
    step_cycles(1 + RESET_HOLD_CYCLES + 1 + STABILIZATION_CYCLES + READY_TIMEOUT_CYCLES, in);
    
    RecoveryOutputs out = recovery_manager_get_outputs();
    ASSERT_TEST(out.recovery_failed, "Test 11a: recovery_failed is high");
    ASSERT_TEST(!out.recovery_done, "Test 11b: recovery_done is low");
}

/* Test 12: External reset via recovery_manager_init */
static void test_12_external_reset(void) {
    recovery_manager_init();
    recovery_manager_tick(); /* IDLE */
    
    RecoveryInputs in = { .recovery_start = true, .system_ready = false };
    step_cycles(3, in); /* In HOLD_RESET */
    
    recovery_manager_init();
    ASSERT_TEST(recovery_manager_get_state() == RM_STATE_RESET, "Test 12a: Reset forces state to RESET");
    
    RecoveryOutputs out = recovery_manager_get_outputs();
    ASSERT_TEST(!out.reset_request && !out.recovery_busy, "Test 12b: Outputs cleared on reset");
}

/* Test 13: Recovery request while busy ignored */
static void test_13_recovery_request_while_busy(void) {
    recovery_manager_init();
    recovery_manager_tick(); /* IDLE */
    
    RecoveryInputs in = { .recovery_start = true, .system_ready = false };
    step_cycles(1 + RESET_HOLD_CYCLES, in); /* RELEASE_RESET */
    
    in.recovery_start = true; /* Assert start again while busy */
    recovery_manager_set_inputs(&in);
    recovery_manager_tick();
    
    ASSERT_TEST(recovery_manager_get_state() == RM_STATE_WAIT_STABILIZE, "Test 13: Request ignored while busy");
}

/* Test 14: Multiple consecutive recoveries */
static void test_14_multiple_consecutive_recoveries(void) {
    RecoveryInputs in = { .recovery_start = true, .system_ready = true };
    
    for (int run = 0; run < 3; run++) {
        recovery_manager_init();
        recovery_manager_tick(); /* IDLE */
        
        in.recovery_start = true;
        in.system_ready = false;
        step_cycles(1 + RESET_HOLD_CYCLES + 1 + STABILIZATION_CYCLES, in); /* VERIFY_READY */
        
        in.recovery_start = false;
        in.system_ready = true;
        recovery_manager_set_inputs(&in);
        recovery_manager_tick(); /* COMPLETE */
        
        ASSERT_TEST(recovery_manager_get_state() == RM_STATE_COMPLETE, "Test 14a: Run completed");
        
        in.recovery_start = false;
        recovery_manager_set_inputs(&in);
        recovery_manager_tick(); /* IDLE */
        
        ASSERT_TEST(recovery_manager_get_state() == RM_STATE_IDLE, "Test 14b: Successfully returned to IDLE");
    }
}

/* Test 15: Single-cycle recovery_done pulse assertion */
static void test_15_done_pulse(void) {
    recovery_manager_init();
    recovery_manager_tick(); /* IDLE */
    
    RecoveryInputs in = { .recovery_start = true, .system_ready = true };
    step_cycles(1 + RESET_HOLD_CYCLES + 1 + STABILIZATION_CYCLES, in); /* VERIFY_READY */
    
    in.recovery_start = false;
    recovery_manager_set_inputs(&in);
    recovery_manager_tick(); /* COMPLETE */
    
    ASSERT_TEST(recovery_manager_get_outputs().recovery_done, "Test 15a: recovery_done high on COMPLETE cycle");
    
    recovery_manager_tick(); /* IDLE */
    ASSERT_TEST(!recovery_manager_get_outputs().recovery_done, "Test 15b: recovery_done drops low next cycle");
}

/* Test 16: Single-cycle recovery_failed pulse assertion */
static void test_16_failed_pulse(void) {
    recovery_manager_init();
    recovery_manager_tick(); /* IDLE */
    
    RecoveryInputs in = { .recovery_start = true, .system_ready = false };
    step_cycles(1 + RESET_HOLD_CYCLES + 1 + STABILIZATION_CYCLES + READY_TIMEOUT_CYCLES, in); /* FAILED */
    
    ASSERT_TEST(recovery_manager_get_outputs().recovery_failed, "Test 16a: recovery_failed high on FAILED cycle");
    
    in.recovery_start = false;
    recovery_manager_set_inputs(&in);
    recovery_manager_tick(); /* IDLE */
    
    ASSERT_TEST(!recovery_manager_get_outputs().recovery_failed, "Test 16b: recovery_failed drops low next cycle");
}

/* ========================================================================= */
/* Test Runner                                                               */
/* ========================================================================= */

int main(void) {
    printf("==================================================\n");
    printf("Running HMD-006 Recovery Manager Unit Test Suite\n");
    printf("==================================================\n");

    test_01_power_up_reset();
    test_02_idle_state();
    test_03_recovery_request();
    test_04_reset_assertion();
    test_05_reset_hold_timing();
    test_06_reset_release();
    test_07_stabilization_delay();
    test_08_immediate_ready();
    test_09_delayed_ready();
    test_10_ready_timeout();
    test_11_recovery_failure();
    test_12_external_reset();
    test_13_recovery_request_while_busy();
    test_14_multiple_consecutive_recoveries();
    test_15_done_pulse();
    test_16_failed_pulse();

    printf("==================================================\n");
    printf("Test Results: %u/%u Passed\n", g_tests_passed, g_tests_run);
    printf("==================================================\n");

    return (g_tests_passed == g_tests_run) ? 0 : 1;
}