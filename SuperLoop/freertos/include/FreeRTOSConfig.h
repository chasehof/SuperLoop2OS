/* Minimal FreeRTOSConfig for RP2040 demo */
#ifndef FREERTOS_CONFIG_H
#define FREERTOS_CONFIG_H

#include <stdint.h>

/* Application specific definitions. */
/* Basic kernel behavior */
#define configUSE_PREEMPTION                    1
#define configUSE_IDLE_HOOK                     0
#define configUSE_TICK_HOOK                     0
#define configCPU_CLOCK_HZ                      ( ( uint32_t ) 125000000 )
#define configTICK_RATE_HZ                      ( 1000 )
#define configMAX_PRIORITIES                    5
#define configMINIMAL_STACK_SIZE                ( ( uint16_t ) 256 )
#define configTOTAL_HEAP_SIZE                   ( ( size_t ) ( 32 * 1024 ) )
#define configMAX_TASK_NAME_LEN                 16
/* Do NOT define configUSE_16_BIT_TICKS when using configTICK_TYPE_WIDTH_IN_BITS */

/* Port & MPU settings required by the ARM CM0+ portheader */
#define configENABLE_MPU                        0
#define configUSE_MPU_WRAPPERS_V1               0
/* Use 32-bit tick type for this port (use kernel symbolic constant) */
#define configTICK_TYPE_WIDTH_IN_BITS           TICK_TYPE_WIDTH_32_BITS

/* API function inclusion */
#define INCLUDE_vTaskDelay                      1
#define INCLUDE_vTaskDelayUntil                 1
#define INCLUDE_vTaskDelete                     1
#define INCLUDE_vTaskSuspend                    1

/* Allocation support */
#define configSUPPORT_DYNAMIC_ALLOCATION        1
#define configSUPPORT_STATIC_ALLOCATION         1

/* Software timer definitions (timers.c is part of the build) */
#define configUSE_TIMERS                        1
#define INCLUDE_xTimerPendFunctionCall          1
#define configTIMER_TASK_PRIORITY               ( configMAX_PRIORITIES - 1 )
#define configTIMER_QUEUE_LENGTH                10

/* RP2040 port (portable/ThirdParty/GCC/RP2040) requirements */

/* Use static exception handlers. With this at 1 the port's portmacro.h does NOT
 * alias vPortSVCHandler/xPortPendSVHandler/xPortSysTickHandler onto the SDK's
 * isr_svcall/isr_pendsv/isr_systick, so the vector table keeps the SDK defaults
 * and vTaskStartScheduler() faults before the first task ever runs. */
#define configUSE_DYNAMIC_EXCEPTION_HANDLERS    0

/* Single core, and no pico_sync interop. Sync interop pulls in an event group +
 * multicore FIFO interrupt path that needs configUSE_TIMERS and
 * INCLUDE_xTimerPendFunctionCall; this demo has no SDK primitives shared with
 * tasks, so turning it off keeps the port's dependencies minimal. */
#define configNUMBER_OF_CORES                   1
#define configSUPPORT_PICO_SYNC_INTEROP         0

/* Timer task stack depth (words) */
#define configTIMER_TASK_STACK_DEPTH            ( configMINIMAL_STACK_SIZE * 2 )

#endif /* FREERTOS_CONFIG_H */
