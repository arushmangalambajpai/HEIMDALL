/**
 * @file configuration.c
 * @brief Implementation of Configuration Manager Memory-Mapped Register Bank
 * @project HEIMDALL
 * @module HMD-001
 */

#include "configuration.h"

#define NUM_REGISTERS (6U)

/**
 * @brief Hardware Register Bank Storage
 * Represents physical memory-mapped 32-bit registers.
 */
static uint32_t s_reg_bank[NUM_REGISTERS];

/**
 * @brief Helper function to convert address offset to internal array index.
 * 
 * @param address Offset address.
 * @return int8_t Index in array or -1 if invalid address or non-aligned.
 */
static int8_t address_to_index(uint8_t address)
{
    if ((address % 4U != 0U) || (address > REG_STATUS_ADDR))
    {
        return -1;
    }
    return (int8_t)(address / 4U);
}

/**
 * @brief Resets configuration registers to default hardware values.
 */
void cfg_init(void)
{
    uint8_t i;
    for (i = 0U; i < NUM_REGISTERS; i++)
    {
        s_reg_bank[i] = 0U;
    }

    /* Set default register values */
    s_reg_bank[address_to_index(REG_HEARTBEAT_CFG_ADDR)] = (HEARTBEAT_CFG_DEFAULT & HEARTBEAT_TIMEOUT_MASK);
    
    /* Set Initialized status bit in STATUS register */
    s_reg_bank[address_to_index(REG_STATUS_ADDR)] |= STATUS_INITIALIZED_MASK;
}

/**
 * @brief Performs a write access to the memory-mapped register bank.
 */
void cfg_write(uint8_t address, uint32_t data)
{
    int8_t idx = address_to_index(address);

    if (idx < 0)
    {
        /* Invalid or unaligned address access ignored */
        return;
    }

    switch (address)
    {
        case REG_CONTROL_ADDR:
            s_reg_bank[idx] = data & CONTROL_HEIMDALL_ENABLE_MASK;
            break;

        case REG_HEARTBEAT_CFG_ADDR:
            s_reg_bank[idx] = data & HEARTBEAT_TIMEOUT_MASK;
            break;

        case REG_CHALLENGE_CFG_ADDR:
            s_reg_bank[idx] = data & (CHALLENGE_RETRY_COUNT_MASK | CHALLENGE_TIMEOUT_MASK);
            break;

        case REG_PROTOCOL_ENABLE_ADDR:
            s_reg_bank[idx] = data & PROTOCOL_ENABLE_MASK;
            break;

        case REG_RECOVERY_CFG_ADDR:
            s_reg_bank[idx] = data & RECOVERY_CFG_MASK;
            break;

        case REG_STATUS_ADDR:
            /* Read-Only Register: Writes are ignored by hardware */
            break;

        default:
            /* No action for out-of-bounds */
            break;
    }
}

/**
 * @brief Performs a read access to the memory-mapped register bank.
 */
uint32_t cfg_read(uint8_t address)
{
    int8_t idx = address_to_index(address);

    if (idx < 0)
    {
        return 0U;
    }

    return s_reg_bank[idx];
}