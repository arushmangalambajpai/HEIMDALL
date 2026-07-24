/* challenge_engine.h */

#ifndef CHALLENGE_ENGINE_H
#define CHALLENGE_ENGINE_H

#include <stdbool.h>
#include <stdint.h>

typedef enum {
    CHALLENGE_IDLE,
    CHALLENGE_WAIT_RESPONSE,
    CHALLENGE_COMPARE,
    CHALLENGE_DONE
} challenge_state_t;

void challenge_init(void);
void challenge_start(void);
void challenge_tick(
    bool response_valid,
    uint32_t expected_response,
    uint32_t received_response
);

bool challenge_busy(void);
bool challenge_done(void);
bool challenge_ok(void);

#endif /* CHALLENGE_ENGINE_H */