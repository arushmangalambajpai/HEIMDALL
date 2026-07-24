/* challenge_engine_test.c */

#include <stdio.h>
#include <stdbool.h>
#include <stdint.h>
#include "challenge_engine.h"

static int g_tests_run = 0;
static int g_tests_passed = 0;
static int g_tests_failed = 0;

#define TEST_ASSERT(cond, msg) \
    do { \
        if (cond) { \
            printf("  [PASS] %s\n", msg); \
        } else { \
            printf("  [FAIL] %s (Line %d)\n", msg, __LINE__); \
            *test_passed = false; \
        } \
    } while (0)

#define RUN_TEST(test_func, test_name) \
    do { \
        printf("Running %s...\n", test_name); \
        bool test_passed = true; \
        g_tests_run++; \
        test_func(&test_passed); \
        if (test_passed) { \
            g_tests_passed++; \
        } else { \
            g_tests_failed++; \
        } \
    } while (0)

static void test_initial_state(bool *test_passed) {
    challenge_init();
    TEST_ASSERT(!challenge_busy(), "Engine should not be busy initially");
    TEST_ASSERT(!challenge_done(), "Engine should not be done initially");
    TEST_ASSERT(!challenge_ok(), "Engine OK flag should be false initially");
}

static void test_start_transition(bool *test_passed) {
    challenge_init();
    challenge_start();
    TEST_ASSERT(challenge_busy(), "Engine should be busy after challenge_start()");
    TEST_ASSERT(!challenge_done(), "Engine should not be done after challenge_start()");
    TEST_ASSERT(!challenge_ok(), "Engine OK flag should be false after start");
}

static void test_wait_response_holds_state(bool *test_passed) {
    challenge_init();
    challenge_start();
    
    for (int i = 0; i < 3; i++) {
        challenge_tick(false, 0x12345678, 0x12345678);
        TEST_ASSERT(challenge_busy(), "Engine must stay busy while waiting");
        TEST_ASSERT(!challenge_done(), "Engine must not be done while waiting");
    }
}

static void test_matching_response_success(bool *test_passed) {
    challenge_init();
    challenge_start();
    
    challenge_tick(true, 0xABCDEF01, 0xABCDEF01);
    TEST_ASSERT(challenge_done(), "Engine should be done after valid response");
    TEST_ASSERT(challenge_ok(), "Engine OK flag should be true for matching response");
    TEST_ASSERT(challenge_busy(), "Engine should still be busy in DONE state");
}

static void test_mismatching_response_failure(bool *test_passed) {
    challenge_init();
    challenge_start();
    
    challenge_tick(true, 0xABCDEF01, 0x12345678);
    TEST_ASSERT(challenge_done(), "Engine should be done after valid response");
    TEST_ASSERT(!challenge_ok(), "Engine OK flag should be false for mismatching response");
    TEST_ASSERT(challenge_busy(), "Engine should still be busy in DONE state");
}

static void test_auto_return_to_idle(bool *test_passed) {
    challenge_init();
    challenge_start();
    challenge_tick(true, 0x100, 0x100);
    
    TEST_ASSERT(challenge_done(), "Engine in DONE state before next tick");
    
    /* Next tick should trigger automatic transition: DONE -> IDLE */
    challenge_tick(false, 0, 0);
    
    TEST_ASSERT(!challenge_done(), "Engine should no longer be done after returning to IDLE");
    TEST_ASSERT(!challenge_busy(), "Engine should no longer be busy after returning to IDLE");
    TEST_ASSERT(challenge_ok(), "Engine OK flag should retain last transaction result");
}

static void test_ticks_in_idle_do_nothing(bool *test_passed) {
    challenge_init();
    
    challenge_tick(true, 0x1234, 0x1234);
    TEST_ASSERT(!challenge_busy(), "Ticks while IDLE should be ignored");
    TEST_ASSERT(!challenge_done(), "Ticks while IDLE should not trigger DONE");
}

static void test_restart_during_wait_response(bool *test_passed) {
    challenge_init();
    challenge_start();
    challenge_tick(false, 1, 1);
    
    /* Restart transaction mid-wait */
    challenge_start();
    TEST_ASSERT(challenge_busy(), "Engine busy after restart");
    
    challenge_tick(true, 0x55555555, 0x55555555);
    TEST_ASSERT(challenge_done(), "Engine done after valid response post-restart");
    TEST_ASSERT(challenge_ok(), "Engine OK status true post-restart");
}

int main(void) {
    printf("==========================================\n");
    printf(" PROJECT HEIMDALL: HMD-004 Challenge Engine\n");
    printf(" Unit Test Suite\n");
    printf("==========================================\n\n");

    RUN_TEST(test_initial_state, "Test 1: Initial State");
    RUN_TEST(test_start_transition, "Test 2: Start Transition");
    RUN_TEST(test_wait_response_holds_state, "Test 3: Wait Response State Holding");
    RUN_TEST(test_matching_response_success, "Test 4: Matching Response Success");
    RUN_TEST(test_mismatching_response_failure, "Test 5: Mismatching Response Failure");
    RUN_TEST(test_auto_return_to_idle, "Test 6: Automatic Return to IDLE");
    RUN_TEST(test_ticks_in_idle_do_nothing, "Test 7: Idle Ticks Ignored");
    RUN_TEST(test_restart_during_wait_response, "Test 8: Restart Mid-Transaction");

    printf("\n------------------------------------------\n");
    printf(" Test Results: %d Passed, %d Failed (Total %d)\n",
           g_tests_passed, g_tests_failed, g_tests_run);
    printf("==========================================\n");

    return (g_tests_failed == 0) ? 0 : 1;
}