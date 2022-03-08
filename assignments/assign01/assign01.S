#include "hardware/regs/addressmap.h"
#include "hardware/regs/io_bank0.h"
#include "hardware/regs/timer.h"
#include "hardware/regs/m0plus.h"

.syntax unified
.cpu    cortex-m0plus
.thumb
.global main_asm
.align  4

.equ    DFLT_STATE_STRT, 1            @ Specify the value to start flashing
.equ    DFLT_STATE_STOP, 0            @ Specify the value to stop flashing
.equ    DFLT_ALARM_TIME, 1000000      @ Specify the default alarm timeout

.equ    GPIO_BTN_DN_MSK, 0x00040000   @ Bit-18 for falling-edge event on GP20
.equ    GPIO_BTN_EN_MSK, 0x00400000   @ Bit-22 for falling-edge event on GP21
.equ    GPIO_BTN_UP_MSK, 0x04000000   @ Bit-26 for falling-edge event on GP22

.equ    GPIO_BTN_DN,  20              @ Specify pin for the "down" button
.equ    GPIO_BTN_EN,  21              @ Specify pin for the "enter" button
.equ    GPIO_BTN_UP,  22              @ Specify pin for the "up" button
.equ    GPIO_LED_PIN, 25              @ Specify pin for the built-in LED
.equ    GPIO_DIR_IN,   0              @ Specify input direction for a GPIO pin
.equ    GPIO_DIR_OUT,  1              @ Specify output direction for a GPIO pin

.equ    LED_VAL_ON,    1              @ Specify value that turns the LED "on"
.equ    LED_VAL_OFF,   0              @ Specify value that turns the LED "off"

.equ    GPIO_ISR_OFFSET, 0x74         @ GPIO is int #13 (vector table entry 29)
.equ    ALRM_ISR_OFFSET, 0x40         @ ALARM0 is int #0 (vector table entry 16)

@ Entry point to the ASM portion of the program
main_asm:
        ldr     r0, =msg
        bl      printf
        //initialise LED
        movs    r0, #GPIO_LED_PIN           @ This value is the GPIO LED pin on the PI PICO board
        bl      asm_gpio_init               @ Call the subroutine to initialise the GPIO pin specified by r0
        movs    r0, #GPIO_LED_PIN           @ This value is the GPIO LED pin on the PI PICO board
        movs    r1, #GPIO_DIR_OUT           @ We want this GPIO pin to be setup as an output pin
        bl      asm_gpio_set_dir            @ Call the subroutine to set the GPIO pin specified by r0 to state specified by r1
       
        //initialise buttons
        movs    r0, #GPIO_BTN_DN            @ This is the value of pin 20 (button)
        bl      asm_gpio_init               @ Subroutine to initialize pin
        
        movs    r0, #GPIO_BTN_EN            @ This is the value of pin 21 (button)
        bl      asm_gpio_init               @ Subroutine to initialize pin
        
        movs    r0, #GPIO_BTN_UP            @ This is the value of pin 22 (button)
        bl      asm_gpio_init               @ Subroutine to initialize pin

        bl    install_alrm_isr    // See below
        bl    install_gpio_isr    // See below

main_loop:
        bl    set_alarm           @ Set new alarm
        wfi                       @ Wait until interrupt
        b       main_loop         @ branch back to loop

//
// Enable alarm timer interrupts and set an alarm
//


set_alarm:
        movs    r1, #1  //Set R1 to 1
        ldr     r2, =(TIMER_BASE + TIMER_INTE_OFFSET)  // load address of the (TIMER_BASE + TIMER_INTE_OFFSET) register
        str     r1, [r2]     // Enable alarm timer interrupts using the (TIMER_BASE + TIMER_INTE_OFFSET) register                           
        ldr     r1, [TIMER_BASE + TIMER_TIMELR_OFFSET]  // Get the current timer count from (TIMER_BASE + TIMER_TIMELR_OFFSET) register !!!
        @ do something Compare values...
        @ CMP r1, #X
        @ BNE ...
        movs    r1, #DFLT_ALARM_TIME    // Add the time delay you want to wait for to the current timer count
        ldr     r2, =(TIMER_BASE + TIMER_ALARM0_OFFSET) // load value at TIMER_BASE + TIMER_ALARM0_OFFSET  //Write 1 to this?
        str     r1, [r2] // Push the updated value to (TIMER_BASE + TIMER_ALARM0_OFFSET)
        bx      lr      // Exit subroutine

//
// Sets up the alrm_isr in the RAM vector table and enables the correct interrupt
//
install_alrm_isr:
    ldr      r2, =(PPB_BASE + M0PLUS_VTOR_OFFSET)   // Get the address of the RAM vector table using the (PPB_BASE + M0PLUS_VTOR_OFFSET) register
    ldr      r1, =alrm_isr                          // Load value of alrm_isr address
    str      r1, [r2, #ALRM_ISR_OFFSET]              // Store the address of the alrm_isr handler to the correct offset for ALARM0 in the vector table
    
    ldr      r2, =(PPB_BASE + M0PLUS_NVIC_ICPR_OFFSET) // Disable the ALARM0 IRQ by writing the correct value to (PPB_BASE + M0PLUS_NVIC_ICPR_OFFSET)                           
    mov      r1, #1             // 
    str      r1, [r2]           
    
    ldr      r2, =(PPB_BASE + M0PLUS_NVIC_ICPR_OFFSET)          // Enable the ALARM0 IRQ by writing the correct value to (PPB_BASE + M0PLUS_NVIC_ISER_OFFSET)                  
    mov      r1, #1             // 
    str      r1, [r2]   
    bx       lr         // Exit subroutine


//
// Service the pending interrupt from the ALARM0 TIMER
//
.thumb_func     // Interrupt Service Routine
alrm_isr:
    push        {lr}    // Push link register onto stack
    bl   sub_toggle     // Perform required functionality (e.g. toggle the LED)
    movs r1, #0         // Move 0 to r1
    ldr  r0, =(TIMER_BASE + TIMER_INTR_OFFSET) // load address of (TIMER_BASE + TIMER_INTR_OFFSET)
    str  r1, [r0] // Disable pending interrupt from TIMER by writing correct value to (TIMER_BASE + TIMER_INTR_OFFSET)
    pop  {pc}     // Exit ISR


@ Subroutine to toggle the LED GPIO pin value
sub_toggle:
    push    {lr}                        @ Store the link register to the stack as we will call nested subroutines
    movs    r0, #LED_GPIO_PIN           @ Set the LED GPIO pin number to r0 for use by asm_gpio_get
    bl      asm_gpio_get                @ Get current the value of the LED GPIO pin (returns to r0)
    cmp     r0, #LED_VALUE_OFF          @ Check if the LED GPIO pin value is "off"
    beq     led_set_on                  @ If it is "off" then then jump code to to turn it on
led_set_off:
    movs    r1, #LED_VALUE_OFF          @ The LED is currently "on" so we want to turn it "off"
    b       led_set_state               @ Jump to portion of code where we set the state of the LED
led_set_on:
    movs    r1, #LED_VALUE_ON           @ The LED is currently "off" so we want to turn it "on"
led_set_state:
    movs    r0, #LED_GPIO_PIN           @ Set the LED GPIO pin number to r0 for use by asm_gpio_put
    bl      asm_gpio_put                @ Update the the value of the LED GPIO pin (based on value in r1)
exit_toggle:
    pop     {pc}                        @ Pop the link register from the stack to the program counter







//
// Sets up the gpio_isr in the RAM vector table and enables the correct interrupt
//
install_gpio_isr:
    // Get the address of the RAM vector table using the (PPB_BASE + M0PLUS_VTOR_OFFSET) register
    // Store the address of the gpio_isr handler to the correct offset for GPIO in the vector table
    // Disable the GPIO IRQ by writing the correct value to (PPB_BASE + M0PLUS_NVIC_ICPR_OFFSET)
    // Enable the GPIO IRQ by writing the correct value to (PPB_BASE + M0PLUS_NVIC_ISER_OFFSET)
    // Exit subroutine

//
// Service the pending interrupt from the GPIO
//
gpio_isr:
    // Read the interrupt status event from the (IO_BANK0_BASE + IO_BANK0_PROC0_INTS2_OFFSET) register
    // Detect which button was pressed by comparing to GPIO_BTN_DN_MSK, GPIO_BTN_EN_MSK and GPIO_BTN_UP_MSK
    // Perform required functionality based on the button press event that was detected
    // Disable the pending interrupt from GPIO by writing the correct value to (IO_BANK0_BASE + IO_BANK0_INTR2_OFFSET)
    // Exit ISR

.align 4
msg:    .asciz "Hello World!\n"

.data
lstate: .word   DFLT_STATE_STRT
ltimer: .word   DFLT_ALARM_TIME