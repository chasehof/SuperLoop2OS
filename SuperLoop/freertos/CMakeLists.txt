
cmake_minimum_required(VERSION 3.13)

# == Do not edit: Pico VSCode toolchain hint (mimic top-level) ==
if(WIN32)
	set(USERHOME $ENV{USERPROFILE})
else()
	set(USERHOME $ENV{HOME})
endif()
set(sdkVersion 2.3.0)
set(toolchainVersion 15_2_Rel1)
set(picotoolVersion 2.3.0)
set(picoVscode ${USERHOME}/.pico-sdk/cmake/pico-vscode.cmake)
if (EXISTS ${picoVscode})
	include(${picoVscode})
endif()
# ==========================================================

# Include pico SDK import from project root
include(${CMAKE_CURRENT_LIST_DIR}/../pico_sdk_import.cmake)

project(SuperLoop_FreeRTOS C CXX ASM)

set(FREERTOS_THIRD_PARTY ${CMAKE_CURRENT_LIST_DIR}/third_party/FreeRTOS-Kernel)

# Initialise the Raspberry Pi Pico SDK
pico_sdk_init()

# Collect project sources (C and C++)
file(GLOB_RECURSE FREERTOS_APP_SOURCES
	${CMAKE_CURRENT_LIST_DIR}/src/*.c
	${CMAKE_CURRENT_LIST_DIR}/src/*.cpp
	${CMAKE_CURRENT_LIST_DIR}/src/*.h
	${CMAKE_CURRENT_LIST_DIR}/../src/cpp/drivers/*.cpp
	${CMAKE_CURRENT_LIST_DIR}/../src/cpp/drivers/*.h
)

if(EXISTS ${FREERTOS_THIRD_PARTY})
	message(STATUS "Found FreeRTOS kernel at ${FREERTOS_THIRD_PARTY}")
	# FreeRTOS kernel layout may place headers in 'include' and sources at repo root
	set(FREERTOS_INCLUDE_DIR ${FREERTOS_THIRD_PARTY}/include)
	# Prefer explicit kernel source list to avoid pulling unrelated ports/examples
	set(FREERTOS_KERNEL_SOURCES
		${FREERTOS_THIRD_PARTY}/list.c
		${FREERTOS_THIRD_PARTY}/event_groups.c
		${FREERTOS_THIRD_PARTY}/stream_buffer.c
		${FREERTOS_THIRD_PARTY}/tasks.c
		${FREERTOS_THIRD_PARTY}/queue.c
		${FREERTOS_THIRD_PARTY}/timers.c
		${FREERTOS_THIRD_PARTY}/croutine.c
		${FREERTOS_THIRD_PARTY}/portable/MemMang/heap_4.c
	)
	list(APPEND FREERTOS_APP_SOURCES ${FREERTOS_KERNEL_SOURCES})
	# Use the RP2040 port, NOT the generic GCC/ARM_CM0 port. The RP2040 port maps
	# vPortSVCHandler/xPortPendSVHandler/xPortSysTickHandler onto the Pico SDK's weak
	# isr_svcall/isr_pendsv/isr_systick so the vector table picks them up. With the
	# generic CM0+ port those handlers are unreferenced and get dropped by
	# --gc-sections, so vTaskStartScheduler() faults before any task runs.
	set(FREERTOS_RP2040_PORT ${FREERTOS_THIRD_PARTY}/portable/ThirdParty/GCC/RP2040)
	if(NOT EXISTS ${FREERTOS_RP2040_PORT}/port.c)
		message(FATAL_ERROR "RP2040 FreeRTOS port missing at ${FREERTOS_RP2040_PORT}. Re-run ../scripts/fetch_freertos.sh")
	endif()
	list(APPEND FREERTOS_APP_SOURCES ${FREERTOS_RP2040_PORT}/port.c)
	# RP2040 port ships its headers in include/ (portmacro.h, rp2040_config.h, ...)
	set(FREERTOS_PORT_INCLUDE ${FREERTOS_RP2040_PORT}/include)
else()
	message(WARNING "FreeRTOS kernel not found in ${FREERTOS_THIRD_PARTY}. Run ../scripts/fetch_freertos.sh to download it.")
endif()

add_executable(SuperLoop_FreeRTOS ${FREERTOS_APP_SOURCES})

# Add Pico libs. hardware_clocks/hardware_exception/pico_multicore are required
# by the RP2040 FreeRTOS port.
target_link_libraries(SuperLoop_FreeRTOS
	pico_stdlib
	hardware_adc
	hardware_i2c
	hardware_pwm
	hardware_clocks
	hardware_exception
	pico_multicore
)

# Definitions the RP2040 port's own library.cmake would normally apply
target_compile_definitions(SuperLoop_FreeRTOS PRIVATE
	LIB_FREERTOS_KERNEL=1
	FREE_RTOS_KERNEL_SMP=1
	PICO_CONFIG_RTOS_ADAPTER_HEADER=${FREERTOS_PORT_INCLUDE}/freertos_sdk_config.h
)

# Include paths
target_include_directories(SuperLoop_FreeRTOS PRIVATE
	${CMAKE_CURRENT_LIST_DIR}/src
	${CMAKE_CURRENT_LIST_DIR}/include
	${CMAKE_CURRENT_LIST_DIR}/../src/cpp
	${CMAKE_CURRENT_LIST_DIR}/../src/cpp/drivers
	${FREERTOS_INCLUDE_DIR}
	${FREERTOS_PORT_INCLUDE}
)

# Enable USB stdio so `printf`/`stdio` is visible over USB CDC when running
pico_enable_stdio_usb(SuperLoop_FreeRTOS 1)
# Disable UART stdio by default (we use dedicated UART object if needed)
pico_enable_stdio_uart(SuperLoop_FreeRTOS 0)

# Create UF2 / extra outputs
pico_add_extra_outputs(SuperLoop_FreeRTOS)
