/**
 * @file event_logger.h
 * @brief PROJECT: HEIMDALL | MODULE: HMD-002 (Event Logger)
 * 
 * Static Ring-Buffer Event Logger Interface.
 */

#ifndef EVENT_LOGGER_H
#define EVENT_LOGGER_H

#include <stdint.h>
#include <stdbool.h>

/**
 * @brief Maximum depth of the event logger FIFO.
 */
#define LOGGER_FIFO_DEPTH (16U)

/**
 * @brief Initializes or resets the event logger FIFO module.
 */
void logger_init(void);

/**
 * @brief Pushes a 32-bit event into the FIFO.
 * 
 * @param event 32-bit event code to log.
 * @return true if successful, false if the FIFO is full.
 */
bool logger_push(uint32_t event);

/**
 * @brief Pops a 32-bit event from the FIFO.
 * 
 * @param event Pointer to storage where popped value will be written.
 * @return true if successful, false if the FIFO is empty or pointer is NULL.
 */
bool logger_pop(uint32_t *event);

/**
 * @brief Checks if the FIFO is empty.
 * 
 * @return true if empty, false otherwise.
 */
bool logger_is_empty(void);

/**
 * @brief Checks if the FIFO is full.
 * 
 * @return true if full, false otherwise.
 */
bool logger_is_full(void);

#endif /* EVENT_LOGGER_H */