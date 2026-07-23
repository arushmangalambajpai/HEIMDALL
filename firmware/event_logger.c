/**
 * @file event_logger.c
 * @brief PROJECT: HEIMDALL | MODULE: HMD-002 (Event Logger)
 * 
 * Embedded C reference implementation using static circular buffer.
 */

#include "event_logger.h"
#include <stddef.h>

/* Static Memory Allocation - No Dynamic Memory Used */
static uint32_t fifo_buffer[LOGGER_FIFO_DEPTH];
static uint8_t write_ptr = 0U;
static uint8_t read_ptr  = 0U;
static uint8_t count     = 0U;

void logger_init(void)
{
    write_ptr = 0U;
    read_ptr  = 0U;
    count     = 0U;

    for (uint8_t i = 0U; i < LOGGER_FIFO_DEPTH; i++)
    {
        fifo_buffer[i] = 0U;
    }
}

bool logger_is_empty(void)
{
    return (count == 0U);
}

bool logger_is_full(void)
{
    return (count == LOGGER_FIFO_DEPTH);
}

bool logger_push(uint32_t event)
{
    if (logger_is_full())
    {
        return false;
    }

    fifo_buffer[write_ptr] = event;
    write_ptr = (uint8_t)((write_ptr + 1U) % LOGGER_FIFO_DEPTH);
    count++;

    return true;
}

bool logger_pop(uint32_t *event)
{
    if ((event == NULL) || logger_is_empty())
    {
        return false;
    }

    *event = fifo_buffer[read_ptr];
    read_ptr = (uint8_t)((read_ptr + 1U) % LOGGER_FIFO_DEPTH);
    count--;

    return true;
}