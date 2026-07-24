#ifndef HEARTBEAT_ENGINE_H
#define HEARTBEAT_ENGINE_H

#include <stdint.h>
#include <stdbool.h>

void heartbeat_init(uint32_t timeout_limit);
void heartbeat_tick(void);
void heartbeat_receive(void);
bool heartbeat_timeout(void);

#endif /* HEARTBEAT_ENGINE_H */