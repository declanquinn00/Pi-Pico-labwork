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
.equ    DFLT_ALARM_TIME, 1000000      @ Specify the default alarm timeout 1000000

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
        //ldr     r0, =msg
        //bl      printf
        ldr r0, =#interval
        ldr r3, [r0]
        ldr r1, =#DFLT_ALARM_TIME
        str r1, [r0]
        ldr r3, [r0]
        bl    init_leds           //initialise LED
        bl    init_btns                    //initialise buttons
        bl    install_alrm_isr    // See below
        //bl    install_gpio_isr    // See below

main_loop:
        bl    set_alarm           @ Set new alarm
        wfi                       @ Wait until interrupt
        b       main_loop         @ branch back to loop

init_btns:
        push    {lr}
        movs    r0, #GPIO_BTN_DN            @ This is the value of pin 20 (button)
        bl      asm_gpio_init               @ Subroutine to initialize pin
        
        movs    r0, #GPIO_BTN_EN            @ This is the value of pin 21 (button)
        bl      asm_gpio_init               @ Subroutine to initialize pin
        
        movs    r0, #GPIO_BTN_UP            @ This is the value of pin 22 (button)
        bl      asm_gpio_init               @ Subroutine to initialize pin
        pop     {pc}

init_leds:
        push    {lr}
        movs    r0, #GPIO_LED_PIN           @ This value is the GPIO LED pin on the PI PICO board
        bl      asm_gpio_init               @ Call the subroutine to initialise the GPIO pin specified by r0
        movs    r0, #GPIO_LED_PIN           @ This value is the GPIO LED pin on the PI PICO board
        movs    r1, #GPIO_DIR_OUT           @ We want this GPIO pin to be setup as an output pin
        bl      asm_gpio_set_dir            @ Call the subroutine to set the GPIO pin specified by r0 to state specified by r1
        pop     {pc}
//
// Enable alarm timer interrupts and set an alarm
//
set_alarm:
        push {lr}
        movs    r1, #1  //Set R1 to 1
        ldr     r2, =(TIMER_BASE + TIMER_INTE_OFFSET)  // load address of the (TIMER_BASE + TIMER_INTE_OFFSET) register
        str     r1, [r2]     // Enable alarm timer interrupts using the (TIMER_BASE + TIMER_INTE_OFFSET) register                           
        ldr     r1, =(TIMER_BASE + TIMER_TIMELR_OFFSET)  // load address from (TIMER_BASE + TIMER_TIMELR_OFFSET) register
        ldr     r1, [r1]        // Get the current timer count from (TIMER_BASE + TIMER_TIMELR_OFFSET) register // Current time
        @ do something Compare values...    // set flashing state
        @ CMP r1, #X
        @ BNE ...
        ldr     r2, =interval
        ldr     r2, [r2]
        //ldr     r2, =DFLT_ALARM_TIME    // Add the time delay you want to wait for to the current timer count //DEFAULT
        adds r1, r1, r2 //Add current and default time
        ldr     r2, =(TIMER_BASE + TIMER_ALARM0_OFFSET) // load value at TIMER_BASE + TIMER_ALARM0_OFFSET  // when alarm0 = timeLR_offset cause interrupt
        str     r1, [r2] // Push the updated value to (TIMER_BASE + TIMER_ALARM0_OFFSET)
        pop  {pc}      // Exit subroutine

//
// Sets up the alrm_isr in the RAM vector table and enables the correct interrupt
//
install_alrm_isr:
    ldr      r2, =(PPB_BASE + M0PLUS_VTOR_OFFSET)   // Get the address of the RAM vector table using the (PPB_BASE + M0PLUS_VTOR_OFFSET) register
    ldr      r1, =alrm_isr                          // Load value of alrm_isr address
    ldr      r2, [r2]   // get address of vector table // get [r2]
    str      r1, [r2, #ALRM_ISR_OFFSET]              // Store the address of the alrm_isr handler to the correct offset for ALARM0 in the vector table
    
    ldr      r2, =(PPB_BASE + M0PLUS_NVIC_ICPR_OFFSET) // (Interupt clear pending reg) (Disable waiting interrupt in queue) Disable the ALARM0 IRQ by writing the correct value to (PPB_BASE + M0PLUS_NVIC_ICPR_OFFSET)                           
    ldr      r1, =#1             // write 1 to disable bit0 is the alarm0 interrupt
    str      r1, [r2]           
    
    ldr      r2, =(PPB_BASE + M0PLUS_NVIC_ISER_OFFSET)          //(Interrupt set enable register) Enables the interrupt Enable the ALARM0 IRQ by writing the correct value to (PPB_BASE + M0PLUS_NVIC_ISER_OFFSET)                  
    ldr      r1, =#1             // write 1 to enable
    str      r1, [r2]   
    bx       lr         // Exit subroutine


//
// Service the pending interrupt from the ALARM0 TIMER
//
.thumb_func     // ISR
alrm_isr:       // Write this to vector table position
    push        {lr}    // Push link register onto stack
    bl   sub_toggle     // Perform required functionality (e.g. toggle the LED)
    movs r1, #1         // Move 0 to r1 //Write 1
    ldr  r0, =(TIMER_BASE + TIMER_INTR_OFFSET) // load address of (TIMER_BASE + TIMER_INTR_OFFSET)
    str  r1, [r0] // Disable pending interrupt from TIMER by writing correct value to (TIMER_BASE + TIMER_INTR_OFFSET)
    pop  {pc}     // Exit ISRInterrupt Service Routine


@ Subroutine to toggle the LED GPIO pin value
sub_toggle:
    push    {lr}                        @ Store the link register to the stack as we will call nested subroutines
    movs    r0, #GPIO_LED_PIN           @ Set the LED GPIO pin number to r0 for use by asm_gpio_get
    bl      asm_gpio_get                @ Get current the value of the LED GPIO pin (returns to r0)
    cmp     r0, #LED_VAL_OFF          @ Check if the LED GPIO pin value is "off"
    beq     led_set_on                  @ If it is "off" then then jump code to to turn it on
led_set_off:
    movs    r1, #LED_VAL_OFF          @ The LED is currently "on" so we want to turn it "off"
    b       led_set_state               @ Jump to portion of code where we set the state of the LED
led_set_on:
    movs    r1, #LED_VAL_ON           @ The LED is currently "off" so we want to turn it "on"
led_set_state:
    movs    r0, #GPIO_LED_PIN           @ Set the LED GPIO pin number to r0 for use by asm_gpio_put
    bl      asm_gpio_put                @ Update the the value of the LED GPIO pin (based on value in r1)
exit_toggle:
    
    //ldr     r0, =alarmToggle // load message into r0
    //bl      printf // print alarmToggle message//messes up r0-r3
    pop     {pc}                        @ Pop the link register from the stack to the program counter

//
// Sets up the gpio_isr in the RAM vector table and enables the correct interrupt
//
install_gpio_isr:
    push {lr}
    ldr r1, =(PPB_BASE + M0PLUS_VTOR_OFFSET)    // Get the address of the RAM vector table using the (PPB_BASE + M0PLUS_VTOR_OFFSET) register
    ldr r2, =gpio_isr                           // load address of subroutine
    ldr r1, [r1]                                // get address stored in r1
    str r2, [r1, GPIO_ISR_OFFSET]               // Store the address of the gpio_isr handler to the correct offset for GPIO in the vector table
    ldr r1, =(PPB_BASE + M0PLUS_NVIC_ICPR_OFFSET) // Disable the GPIO IRQ by writing the correct value to (PPB_BASE + M0PLUS_NVIC_ICPR_OFFSET)
    ldr r2, =#0x2000
    adds r2, #1 //bit 13 and bit 0
    //ldr  r0, =#13
    //lsl  r2, r0
    str  r2, [r1]

    
    ldr r1, =(PPB_BASE + M0PLUS_NVIC_ISER_OFFSET)// Enable the GPIO IRQ by writing the correct value to (PPB_BASE + M0PLUS_NVIC_ISER_OFFSET)
    ldr r2, =#0x2000 //bit 13 and bit 0
    adds r2, #1
    //ldr  r0, =#13
    //lsl  r2, r0
    str  r2, [r1]
    
    pop {pc}    // Exit subroutine

//
// Service the pending interrupt from the GPIO
//
.thumb_func             // ISR
gpio_isr:
    push    {lr}
    //ldr r1, [IO_BANK0_BASE, IO_BANK0_PROC0_INTS2_OFFSET]   // Read the interrupt status event from the (IO_BANK0_BASE + IO_BANK0_PROC0_INTS2_OFFSET) register
    // Detect which button was pressed by comparing to GPIO_BTN_DN_MSK, GPIO_BTN_EN_MSK and GPIO_BTN_UP_MSK
    //gp20
    ldr r2, =#GPIO_BTN_DN_MSK // load buttn down mask
    ands r2, r1  // mask value              ////////////
    cmp  r2, #0 //check if gp20 enabled
    beq  gp21   // branch to next if not
    ldr  r0, =interval  //load time interval
    ldr  r3, [r0]   
    movs r3, r3, lsr #1 // divide interval by 2 

    //gp 21
    gp21:
    ldr r2, =#GPIO_BTN_EN_MSK // load button en mask
    ands r2, r1  // mask value              ////////////
    cmp  r2, #0 // check if gp21 enabled
    beq  gp22
    
    //gp 22
    gp22:
    ldr r2, =#GPIO_BTN_UP_MSK // load button up mask
    ands r2, r1     //mask value            //////////////
    cmp  r2, #0 // check if gp22 enabled
    beq  endbttncheck   // end if not enabled
    ldr  r0, =interval  // load interval value
    ldr  r3, [r0]
    movs r3, r3, lsl #1    //multiply inverval by 2

    endbttncheck:
    // Perform required functionality based on the button press event that was detected
    // Disable the pending interrupt from GPIO by writing the correct value to (IO_BANK0_BASE + IO_BANK0_INTR2_OFFSET)
    pop {pc}    // Exit ISR


.align 4
msg:    .asciz "Hello World!\n"
alarmToggle: .asciz "Toggled alarm\n"
.data

interval:
    .space 4
    .end
flashing_state:
    .space 4
    .end

lstate: .word   DFLT_STATE_STRT
ltimer: .word   DFLT_ALARM_TIME