/**
 * @file configuration.h
 * @brief Configuration Manager Register Bank Header
 * @project HEIMDALL
 * @module HMD-001
 *
 * Defines the register map, bit masks, and public API for the
 * memory-mapped configuration register bank hardware reference model.
 */

#ifndef CONFIGURATION_H
#define CONFIGURATION_H

#include <stdint.h>

/* ========================================================================== */
/* Register Offsets                                                           */
/* ========================================================================== */

#define REG_CONTROL_ADDR          (0x00U)
#define REG_HEARTBEAT_CFG_ADDR    (0x04U)
#define REG_CHALLENGE_CFG_ADDR    (0x08U)
#define REG_PROTOCOL_ENABLE_ADDR  (0x0CU)
#define REG_RECOVERY_CFG_ADDR     (0x10U)
#define REG_STATUS_ADDR           (0x14U)

/* ========================================================================== */
/* Register Bit Definitions & Masks                                           */
/* ========================================================================== */

/* 0x00 CONTROL Register */
#define CONTROL_HEIMDALL_ENABLE_POS  (0U)
#define CONTROL_HEIMDALL_ENABLE_MASK (1U << CONTROL_HEIMDALL_ENABLE_POS)

/* 0x04 HEARTBEAT_CFG Register */
#define HEARTBEAT_TIMEOUT_POS        (0U)
#define HEARTBEAT_TIMEOUT_MASK       (0xFFFFU << HEARTBEAT_TIMEOUT_POS)
#define HEARTBEAT_CFG_DEFAULT        (100U)

/* 0x08 CHALLENGE_CFG Register */
#define CHALLENGE_RETRY_COUNT_POS    (0U)
#define CHALLENGE_RETRY_COUNT_MASK   (0x00FFU << CHALLENGE_RETRY_COUNT_POS)
#define CHALLENGE_TIMEOUT_POS        (8U)
#define CHALLENGE_TIMEOUT_MASK       (0xFF00U)

/* 0x0C PROTOCOL_ENABLE Register */
#define PROTOCOL_SPI_POS             (0U)
#define PROTOCOL_SPI_MASK            (1U << PROTOCOL_SPI_POS)
#define PROTOCOL_UART_POS            (1U)
#define PROTOCOL_UART_MASK           (1U << PROTOCOL_UART_POS)
#define PROTOCOL_I2C_POS             (2U)
#define PROTOCOL_I2C_MASK            (1U << PROTOCOL_I2C_POS)
#define PROTOCOL_GPIO_POS            (3U)
#define PROTOCOL_GPIO_MASK           (1U << PROTOCOL_GPIO_POS)
#define PROTOCOL_ENABLE_MASK         (0x0FU)

/* 0x10 RECOVERY_CFG Register */
#define RECOVERY_AUTO_RECOVERY_POS   (0U)
#define RECOVERY_AUTO_RECOVERY_MASK  (1U << RECOVERY_AUTO_RECOVERY_POS)
#define RECOVERY_SAFE_MODE_POS       (1U)
#define RECOVERY_SAFE_MODE_MASK      (1U << RECOVERY_SAFE_MODE_POS)
#define RECOVERY_CFG_MASK            (0x03U)

/* 0x14 STATUS Register (Read-Only) */
#define STATUS_INITIALIZED_POS       (0U)
#define STATUS_INITIALIZED_MASK      (1U << STATUS_INITIALIZED_POS)
#define STATUS_CFG_VALID_POS         (1U)
#define STATUS_CFG_VALID_MASK        (1U << STATUS_CFG_VALID_POS)
#define STATUS_ERROR_POS             (2U)
#define STATUS_ERROR_MASK            (1U << STATUS_ERROR_POS)
#define STATUS_MASK                  (0x07U)

/* ========================================================================== */
/* Public Function Prototypes                                                 */
/* ========================================================================== */

/**
 * @brief Resets all configuration registers to hardware default states and sets
 *        the STATUS Initialized bit.
 */
void cfg_init(void);

/**
 * @brief Performs a 32-bit write operation to the specified register address.
 *        Applies valid write-masks and ignores writes to Read-Only registers or
 *        invalid/unaligned addresses.
 *
 * @param address 8-bit memory offset relative to base address.
 * @param data 32-bit register write value.
 */
void cfg_write(uint8_t address, uint32_t data);

/**
 * @brief Performs a 32-bit read operation from the specified register address.
 *
 * @param address 8-bit memory offset relative to base address.
 * @return uint32_t Register data value, or 0 if address is invalid/unaligned.
 */
uint32_t cfg_read(uint8_t address);

#endif /* CONFIGURATION_H */