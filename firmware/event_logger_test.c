/**
 * @file event_logger_test.c
 * @brief Test suite for HMD-002 Event Logger Module.
 */

#include <stdio.h>
#include <stdbool.h>
#include <stdint.h>
#include "event_logger.h"

static uint32_t test_passed_count = 0U;
static uint32_t test_failed_count = 0U;

static void assert_test(bool condition, const char *test_name)
{
    if (condition)
    {
        printf("[PASS] %s\n", test_name);
        test_passed_count++;
    }
    else
    {
        printf("[FAIL] %s\n", test_name);
        test_failed_count++;
    }
}

static void test_initialization(void)
{
    logger_init();
    assert_test(logger_is_empty() == true, "Init: FIFO should be empty");
    assert_test(logger_is_full() == false, "Init: FIFO should not be full");
}

static void test_single_push_pop(void)
{
    logger_init();
    uint32_t test_event = 0xDEADBEEFU;
    uint32_t popped_event = 0U;

    bool push_status = logger_push(test_event);
    assert_test(push_status == true, "Single Push: Successful return");
    assert_test(logger_is_empty() == false, "Single Push: FIFO not empty");

    bool pop_status = logger_pop(&popped_event);
    assert_test(pop_status == true, "Single Pop: Successful return");
    assert_test(popped_event == test_event, "Single Pop: Value integrity check");
    assert_test(logger_is_empty() == true, "Single Pop: FIFO empty after pop");
}

static void test_full_and_overflow(void)
{
    logger_init();

    /* Fill FIFO to capacity */
    for (uint32_t i = 0U; i < LOGGER_FIFO_DEPTH; i++)
    {
        bool pushed = logger_push(0x10000000U | i);
        if (!pushed)
        {
            assert_test(false, "Full Fill: Premature failure during push");
            return;
        }
    }

    assert_test(logger_is_full() == true, "FIFO Full: Is full flag high");
    assert_test(logger_is_empty() == false, "FIFO Full: Is empty flag low");

    /* Attempt Overflow Push (17th item) */
    bool overflow_pushed = logger_push(0xFFFFFFFFU);
    assert_test(overflow_pushed == false, "Overflow Rejection: 17th item push rejected");
}

static void test_empty_and_underflow(void)
{
    /* Draining from previous full state */
    uint32_t popped_val = 0U;
    bool all_drained = true;

    for (uint32_t i = 0U; i < LOGGER_FIFO_DEPTH; i++)
    {
        bool popped = logger_pop(&popped_val);
        if (!popped || (popped_val != (0x10000000U | i)))
        {
            all_drained = false;
            break;
        }
    }

    assert_test(all_drained == true, "FIFO Draining: All items retrieved in order");
    assert_test(logger_is_empty() == true, "FIFO Empty: Is empty flag high");

    /* Attempt Underflow Pop */
    bool underflow_popped = logger_pop(&popped_val);
    assert_test(underflow_popped == false, "Underflow Rejection: Pop on empty rejected");
}

static void test_wraparound(void)
{
    logger_init();
    uint32_t val = 0U;

    /* Offset pointers by pushing and popping 10 items */
    for (uint32_t i = 0U; i < 10U; i++)
    {
        (void)logger_push(0xA0000000U | i);
        (void)logger_pop(&val);
    }

    /* Fill 16 items across boundary */
    bool fill_ok = true;
    for (uint32_t i = 0U; i < LOGGER_FIFO_DEPTH; i++)
    {
        if (!logger_push(0xB0000000U | i))
        {
            fill_ok = false;
        }
    }
    assert_test(fill_ok && logger_is_full(), "Wrap-around: Fill across array boundary");

    /* Read back across boundary and verify order */
    bool match_ok = true;
    for (uint32_t i = 0U; i < LOGGER_FIFO_DEPTH; i++)
    {
        if (!logger_pop(&val) || (val != (0xB0000000U | i)))
        {
            match_ok = false;
        }
    }
    assert_test(match_ok && logger_is_empty(), "Wrap-around: Data integrity & ordering verified");
}

int main(void)
{
    printf("=========================================\n");
    printf("  HEIMDALL HMD-002 Event Logger Test Harness\n");
    printf("=========================================\n");

    test_initialization();
    test_single_push_pop();
    test_full_and_overflow();
    test_empty_and_underflow();
    test_wraparound();

    printf("=========================================\n");
    printf(" SUMMARY: PASS = %u | FAIL = %u\n", test_passed_count, test_failed_count);
    printf("=========================================\n");

    return (test_failed_count == 0U) ? 0 : 1;
}