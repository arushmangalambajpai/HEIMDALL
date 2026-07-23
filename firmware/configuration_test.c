/**
 * @file configuration_test.c
 * @brief Verification Suite for HEIMDALL HMD-001 Configuration Manager
 */

#include <stdio.h>
#include <stdbool.h>
#include "configuration.h"

/**
 * @brief Executes test sequence for register bank initialization, read/write accuracy,
 *        bit masking, and read-only protections.
 *
 * @return int 0 on success, 1 on failure.
 */
int main(void)
{
    bool test_passed = true;
    uint32_t read_val;

    printf("========================================\n");
    printf(" PROJECT HEIMDALL - HMD-001 TEST SUITE  \n");
    printf("========================================\n\n");

    /* 1. Initialization Test */
    printf("[TEST 1] Initializing Register Bank...\n");
    cfg_init();

    read_val = cfg_read(REG_HEARTBEAT_CFG_ADDR);
    if (read_val != HEARTBEAT_CFG_DEFAULT)
    {
        printf("  FAIL: HEARTBEAT_CFG Default. Expected: %u, Got: %u\n", HEARTBEAT_CFG_DEFAULT, read_val);
        test_passed = false;
    }

    read_val = cfg_read(REG_STATUS_ADDR);
    if ((read_val & STATUS_INITIALIZED_MASK) == 0U)
    {
        printf("  FAIL: STATUS Initialized Bit not set. Got: 0x%08X\n", read_val);
        test_passed = false;
    }

    /* 2. CONTROL Register Test */
    printf("[TEST 2] CONTROL Register Read/Write...\n");
    cfg_write(REG_CONTROL_ADDR, 0xFFFFFFFFU);
    read_val = cfg_read(REG_CONTROL_ADDR);
    if (read_val != CONTROL_HEIMDALL_ENABLE_MASK)
    {
        printf("  FAIL: CONTROL Mask. Expected: 0x%08X, Got: 0x%08X\n", CONTROL_HEIMDALL_ENABLE_MASK, read_val);
        test_passed = false;
    }

    /* 3. HEARTBEAT_CFG Register Test */
    printf("[TEST 3] HEARTBEAT_CFG Register Read/Write...\n");
    cfg_write(REG_HEARTBEAT_CFG_ADDR, 0x0001FFFFU);
    read_val = cfg_read(REG_HEARTBEAT_CFG_ADDR);
    if (read_val != 0x0000FFFFU)
    {
        printf("  FAIL: HEARTBEAT_CFG Mask. Expected: 0x0000FFFF, Got: 0x%08X\n", read_val);
        test_passed = false;
    }

    /* 4. CHALLENGE_CFG Register Test */
    printf("[TEST 4] CHALLENGE_CFG Register Read/Write...\n");
    cfg_write(REG_CHALLENGE_CFG_ADDR, (0xA5U << CHALLENGE_TIMEOUT_POS) | 0x05U);
    read_val = cfg_read(REG_CHALLENGE_CFG_ADDR);
    if (read_val != 0x0000A505U)
    {
        printf("  FAIL: CHALLENGE_CFG Value. Expected: 0x0000A505, Got: 0x%08X\n", read_val);
        test_passed = false;
    }

    /* 5. PROTOCOL_ENABLE Register Test */
    printf("[TEST 5] PROTOCOL_ENABLE Register Read/Write...\n");
    cfg_write(REG_PROTOCOL_ENABLE_ADDR, PROTOCOL_SPI_MASK | PROTOCOL_UART_MASK | PROTOCOL_I2C_MASK | PROTOCOL_GPIO_MASK);
    read_val = cfg_read(REG_PROTOCOL_ENABLE_ADDR);
    if (read_val != 0x0000000FU)
    {
        printf("  FAIL: PROTOCOL_ENABLE Value. Expected: 0x0000000F, Got: 0x%08X\n", read_val);
        test_passed = false;
    }

    /* 6. RECOVERY_CFG Register Test */
    printf("[TEST 6] RECOVERY_CFG Register Read/Write...\n");
    cfg_write(REG_RECOVERY_CFG_ADDR, RECOVERY_AUTO_RECOVERY_MASK | RECOVERY_SAFE_MODE_MASK);
    read_val = cfg_read(REG_RECOVERY_CFG_ADDR);
    if (read_val != 0x00000003U)
    {
        printf("  FAIL: RECOVERY_CFG Value. Expected: 0x00000003, Got: 0x%08X\n", read_val);
        test_passed = false;
    }

    /* 7. STATUS Read-Only Register Write Protection Test */
    printf("[TEST 7] STATUS Read-Only Protection...\n");
    uint32_t status_before = cfg_read(REG_STATUS_ADDR);
    cfg_write(REG_STATUS_ADDR, 0xFFFFFFFFU);
    uint32_t status_after = cfg_read(REG_STATUS_ADDR);
    if (status_before != status_after)
    {
        printf("  FAIL: STATUS register modified by write access. Before: 0x%08X, After: 0x%08X\n", status_before, status_after);
        test_passed = false;
    }

    /* Final Result */
    printf("\n----------------------------------------\n");
    if (test_passed)
    {
        printf("RESULT: PASS\n");
    }
    else
    {
        printf("RESULT: FAIL\n");
    }
    printf("----------------------------------------\n");

    return test_passed ? 0 : 1;
}