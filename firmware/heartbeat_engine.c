#include "heartbeat_engine.h"

static uint32_t counter = 0;
static uint32_t timeout_limit = 0;
static bool timeout_flag = false;

void heartbeat_init(uint32_t limit) {
    counter = 0;
    timeout_flag = false;
    timeout_limit = limit;
}

void heartbeat_tick(void) {
    counter++;
    if (counter >= timeout_limit) {
        timeout_flag = true;
    }
}

void heartbeat_receive(void) {
    counter = 0;
    timeout_flag = false;
}

bool heartbeat_timeout(void) {
    return timeout_flag;
}