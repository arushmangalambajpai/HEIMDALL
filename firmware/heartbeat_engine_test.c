#include <stdio.h>
#include <assert.h>
#include <stdbool.h>
#include "heartbeat_engine.h"

static void test_initialization(void) {
    heartbeat_init(5);
    assert(heartbeat_timeout() == false);
    printf("[PASS] Initialization\n");
}

static void test_counter_increment(void) {
    heartbeat_init(5);
    heartbeat_tick();
    assert(heartbeat_timeout() == false);
    heartbeat_tick();
    assert(heartbeat_timeout() == false);
    printf("[PASS] Counter Increment\n");
}

static void test_boundary_condition(void) {
    heartbeat_init(3);
    heartbeat_tick(); /* counter = 1 */
    assert(heartbeat_timeout() == false);
    heartbeat_tick(); /* counter = 2 */
    assert(heartbeat_timeout() == false);
    heartbeat_tick(); /* counter = 3 (counter == timeout_limit) */
    assert(heartbeat_timeout() == true);
    printf("[PASS] Boundary Condition\n");
}

static void test_timeout_detection(void) {
    heartbeat_init(2);
    heartbeat_tick(); /* counter = 1 */
    assert(heartbeat_timeout() == false);
    heartbeat_tick(); /* counter = 2 */
    assert(heartbeat_timeout() == true);
    heartbeat_tick(); /* counter = 3 (exceeds limit) */
    assert(heartbeat_timeout() == true);
    printf("[PASS] Timeout Detection\n");
}

static void test_heartbeat_reception(void) {
    heartbeat_init(5);
    heartbeat_tick();
    heartbeat_tick();
    heartbeat_receive(); /* Resets counter to 0 */
    assert(heartbeat_timeout() == false);
    
    heartbeat_tick();
    assert(heartbeat_timeout() == false);
    printf("[PASS] Heartbeat Reception\n");
}

static void test_multiple_heartbeat_resets(void) {
    heartbeat_init(3);
    for (int i = 0; i < 5; i++) {
        heartbeat_tick();
        heartbeat_tick();
        assert(heartbeat_timeout() == false);
        heartbeat_receive();
    }
    assert(heartbeat_timeout() == false);
    printf("[PASS] Multiple Heartbeat Resets\n");
}

static void test_timeout_recovery(void) {
    heartbeat_init(2);
    heartbeat_tick();
    heartbeat_tick(); /* Timeout triggered */
    assert(heartbeat_timeout() == true);

    heartbeat_receive(); /* Recover from timeout */
    assert(heartbeat_timeout() == false);

    heartbeat_tick();
    assert(heartbeat_timeout() == false);
    printf("[PASS] Timeout Recovery\n");
}

int main(void) {
    printf("--- HEIMDALL HMD-003 Heartbeat Engine Test Suite ---\n\n");

    test_initialization();
    test_counter_increment();
    test_boundary_condition();
    test_timeout_detection();
    test_heartbeat_reception();
    test_multiple_heartbeat_resets();
    test_timeout_recovery();

    printf("\nAll unit tests completed successfully.\n");
    return 0;
}