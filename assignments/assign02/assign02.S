#include "hardware/regs/addressmap.h"
#include "hardware/regs/io_bank0.h"
#include "hardware/regs/timer.h"
#include "hardware/regs/m0plus.h"


.syntax unified                                                 @ Specify unified assembly syntax
.cpu    cortex-m0plus                                           @ Specify CPU type is Cortex M0+
.thumb                                                          @ Specify thumb assembly for RP2040
.global main_asm                                                @ Provide program starting address to the linker
.global wait_for_input                                          @ ADDRESS FOR WAIT LOOP
.global input_array
.global arrayIndex                                                   @ address for arrayIndex
.align 4                                                        @ Specify code alignment

//Offsets
.equ    GPIO_ISR_OFFSET, 0x74         @ GPIO is int #13 (vector table entry 29)
.equ    ALRM_ISR_OFFSET, 0x40         @ ALARM0 is int #0 (vector table entry 16)
.equ    TIMELR_OFFSET,   0x0c
.equ    TIMEHR_OFFSET,   0x08

// Mask for falling edge gp21
.equ    GPIO_BTN_EN_MSK, 0x00400000   @ Bit-22 for falling-edge event on GP21
.equ    GPIO_BTN_RISE_MSK, 0x00800000 // Bit 23 for rising edge


.equ    GPIO_BTN_EN,  21              @ Specify pin for the "enter" button
.equ    GPIO_DIR_IN,   0              @ Specify input direction for a GPIO pin
.equ    GPIO_DIR_OUT,  1              @ Specify output direction for a GPIO pin
.equ    DFLT_ALARM_TIME, 1000000      @ Specify the default alarm timeout 1000000 (SET TO 1 SECOND)

@ Entry point to the ASM portion of the program
// Setup pins and interrupts
main_asm:
    push    {lr}
    bl    init_btns           //initialise buttons
    bl    install_alrm_isr    // install alarm interrupt
    bl    install_gpio_isr    // install gpio interrupt
    pop     {pc}                   // return to main()

@  Entry point registers inputs of gp21
// Wait for a button interrupt
wait_for_input:
    push    {lr}
    LDR R0, =arrayIndex
    LDR r1, =#0      // load 0
    STR r1, [r0]    // reset arrayIndex to 0
start_new_alarm:
    LDR R0, =#arrayIndex 
    LDR R0, [R0]    // load value of arrayIndex
    CMP R0,#0       //if (arrayIndex >0) start alarm timer
    BLE wait_for_interrupt
    LDR r0, =interval
    LDR r1, =#1000000   // set interval to 1++ DEBUGGING second
    STR r1, [r0]
    bl set_alarm
wait_for_interrupt:
    wfi                       @ Wait until interrupt (rising edge)
    // If bttn dn wait for bttn up
    LDR r0, =button_state   // Load button state
    LDR r0, [r0]
    CMP R0, #1              // 1 if bttn pressed
    BEQ wait_for_interrupt

    //if array[arrayIndex-1] && array[arrayIndex-2] == -1 then return to main
    LDR r0, =arrayIndex  // load arrayIndex
    LDR r0, [r0]    // get value of arrayIndex
    CMP r0, #8      // if arrayIndex >= 8
    BLT start_new_alarm  // else loop
    LDR r1, =input_array     // get input array
    SUBS r0, #4     // arrayIndex value --
    LDR r2, [r1, r0]    // Load array[arrayIndex-1]
    LDR r3, =#-1        // load -1
    CMP r2, r3     // if array[arrayIndex-1]== -1
    BNE start_new_alarm
    SUBS r0, #4     // arrayIndex value --
    LDR r2, [r1, r0]    // Load array[arrayIndex-1]
    CMP r2, r3     // if array[arrayIndex-1]== -1
    BNE start_new_alarm

    pop     {pc}                   // return to main()

// Initialize gp21
init_btns:
        push    {lr}

        movs    r0, #GPIO_BTN_EN            @ This is the value of pin 21 (button)
        bl      asm_gpio_init               @ Subroutine to initialize pin

        ldr     r0, =#GPIO_BTN_EN           @ pin 21
        ldr     r1, =#4                     @ load falling edge value // NEED TO FIGURE HOW TO ENABLE FOR RISING EDGE!!!
        ldr     r2, =#1  
        bl      gpio_set_irq_enabled        @ function to enable interrupt
        ldr     r0, =#GPIO_BTN_EN           // pin 21
        bl      asm_gpio_set_irq_rise       // set rising edge gp21

        pop     {pc}

// Install alarm Interrupt
install_alrm_isr:
    ldr      r2, =(PPB_BASE + M0PLUS_VTOR_OFFSET)   // Get the address of the RAM vector table using the (PPB_BASE + M0PLUS_VTOR_OFFSET) register
    ldr      r1, =alrm_isr                          // Load value of alrm_isr address
    ldr      r2, [r2]                               // get address of vector table // get [r2]
    str      r1, [r2, #ALRM_ISR_OFFSET]             // Store the address of the alrm_isr handler to the correct offset for ALARM0 in the vector table
    
    ldr      r2, =(PPB_BASE + M0PLUS_NVIC_ICPR_OFFSET) // (Interupt clear pending reg) (Disable waiting interrupt in queue) Disable the ALARM0 IRQ by writing the correct value to (PPB_BASE + M0PLUS_NVIC_ICPR_OFFSET)                       
    ldr      r1, =#1                                // write 1 to disable bit0 is the alarm0 interrupt
    str      r1, [r2]           
     

    ldr      r2, =(PPB_BASE + M0PLUS_NVIC_ISER_OFFSET)  //(Interrupt set enable register) Enables the interrupt Enable the ALARM0 IRQ by writing the correct value to (PPB_BASE + M0PLUS_NVIC_ISER_OFFSET)                  
    ldr      r1, =#1                                    // write 1 to enable
    str      r1, [r2]                                   // store 1 in address
    bx       lr                                         // Exit subroutine

//
// Enable alarm timer interrupts and set an alarm
//
set_alarm:
        push {lr}
        movs    r1, #1                                  //Set R1 to 1
        ldr     r2, =(TIMER_BASE + TIMER_INTE_OFFSET)   // load address of the (TIMER_BASE + TIMER_INTE_OFFSET) register
        str     r1, [r2]                                // Enable alarm timer interrupts using the (TIMER_BASE + TIMER_INTE_OFFSET) register                           
        ldr     r1, =(TIMER_BASE + TIMER_TIMELR_OFFSET) // load address from (TIMER_BASE + TIMER_TIMELR_OFFSET) register
        ldr     r1, [r1]                                // Get the current timer count from (TIMER_BASE + TIMER_TIMELR_OFFSET) register // Current time
        ldr     r2, =interval                           // load interval address
        ldr     r2, [r2]                                // load interval value
        adds    r1, r1, r2                              // Add current and default time
        ldr     r2, =(TIMER_BASE + TIMER_ALARM0_OFFSET) // load value at TIMER_BASE + TIMER_ALARM0_OFFSET  // when alarm0 = timeLR_offset cause interrupt
        str     r1, [r2]                                // Push the updated value to (TIMER_BASE + TIMER_ALARM0_OFFSET)
        pop  {pc}                                       // Exit subroutine


//
// Service the pending interrupt from the ALARM0 TIMER
//
.thumb_func     // ISR
alrm_isr:                                       // Write this to vector table position
    push        {lr}                            // Push link register onto stack
    bl alrm_write_space                         // BRANCH TO SUBROUTINE writes -1 to input array
    movs r1, #1                                 
    ldr  r0, =(TIMER_BASE + TIMER_INTR_OFFSET)  // load address of (TIMER_BASE + TIMER_INTR_OFFSET)
    str  r1, [r0]                               // Disable pending interrupt from TIMER by writing correct value to (TIMER_BASE + TIMER_INTR_OFFSET)
    bl   watchdog_update_arm                    // Update watchdog timer in c file
    pop  {pc}                                   // Exit ISRInterrupt Service Routine

//
// Writes a space to the input array (-1)
//
alrm_write_space:
    push        {lr}
    LDR r0, =arrayIndex     // Load arrayIndex
    LDR r3, [r0]            // get value of arrayIndex
    LDR r1, =input_array    // Load input array
    LDR r2, =#-1
    STR r2, [r1, r3]        // store -1 at input array + arrayIndex
    ADDS r3, r3, #4         // arrayIndex++
    STR r3, [r0]            // store arrayIndex value
    pop         {pc}



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
    ldr r2, =#0x2000                            // bit 13
    str  r2, [r1]

    
    ldr r1, =(PPB_BASE + M0PLUS_NVIC_ISER_OFFSET) // Enable the GPIO IRQ by writing the correct value to (PPB_BASE + M0PLUS_NVIC_ISER_OFFSET)
    ldr r0, [r1]                                  // Load value in reg
    ldr r2, =#0x2000                              //bit 13
    adds r2, r0                                   //value in r0 + value of bit 13
    str  r2, [r1]
    
    pop {pc}                                      // Exit subroutine

//
// Service the pending interrupt from the GPIO
//
.thumb_func             // ISR
gpio_isr:
    push    {lr}
    bl      watchdog_update_arm                    // Update watchdog timer in c file
    LDR r1, =interval
    LDR r2, =#1000000000            // New long time interval (so alarm will not go off)
    STR r2, [r1]                    // Store new time interval
    bl set_alarm                    // set new alarm  VERY IMPORTANT FOR LONG PRESSES
    ldr r1, =(IO_BANK0_BASE + IO_BANK0_PROC0_INTS2_OFFSET)   // Read the interrupt status event from the (IO_BANK0_BASE + IO_BANK0_PROC0_INTS2_OFFSET) register
    ldr r1, [r1]                                             // get value of interrupt status event


gp21_rise:
    ldr r2, =#GPIO_BTN_RISE_MSK       // load button rise mask bit 23
    ands r2, r1                     // mask value              
    cmp  r2, #0                     // check if gp21 enabled
    beq  gp21_fall               // do nothing if not enabled
    bl get_time_rise  // Send to loop and wait until button is released
    bl check_time_pressed   //Branch to read times pressed
    LDR r0, =button_state   // get button state
    LDR r3, =#0
    STR r3, [r0]            // set to 0 disabled
    b rise_disable//Disable interrupt


    // Detect which button was pressed by comparing to GPIO_BTN_DN_MSK, GPIO_BTN_EN_MSK and GPIO_BTN_UP_MSK
    //gp 21
gp21_fall:
    ldr r2, =#GPIO_BTN_EN_MSK       // load button en mask
    ands r2, r1                     // mask value              
    cmp  r2, #0                     // check if gp21 enabled
    beq  fall_disable               // do nothing if not enabled
    bl get_time_fall  // Send to loop and wait until button is released
    LDR r0, =button_state   // get button state
    LDR r3, =#1
    STR r3, [r0]            // set to 1 enabled

fall_disable:
    ldr r3, =(IO_BANK0_BASE + IO_BANK0_INTR2_OFFSET) // Disable the pending interrupt from GPIO by writing the correct value to (IO_BANK0_BASE + IO_BANK0_INTR2_OFFSET)
    ldr r0, =0x00400000             // override gpio 21 falling edge
    str r0, [r3]
    b endbttncheck
rise_disable:
    ldr r3, =(IO_BANK0_BASE + IO_BANK0_INTR2_OFFSET) // Disable the pending interrupt from GPIO by writing the correct value to (IO_BANK0_BASE + IO_BANK0_INTR2_OFFSET)
    ldr r0, =#GPIO_BTN_RISE_MSK
    str r0, [r3]
    
endbttncheck:
    pop {pc}    // Exit ISR

// Check how long button pressed for
get_time_fall:
    push {lr}
    // CALCULATE SYSTEM TIME
    LDR r4, =(TIMER_BASE + TIMELR_OFFSET)       //Load timeLW
    ldr r4, [r4]                                // load value of timeLW 
    LDR r5, =(TIMER_BASE + TIMEHR_OFFSET)       // Load timeHW
    ldr r5, [r5]                                // Load value of timeHW
    // store in memory
    LDR r6, =stime                        // load syst time
    STR r4, [r6, #0]                                // store Lower value in system_time
    STR r5, [r6, #4]                            // store Uppervalue in system_time + 4

    pop {pc}

// Check how long button pressed for
get_time_rise:
    push {lr}
    // CALCULATE SYSTEM TIME
    LDR r4, =(TIMER_BASE + TIMELR_OFFSET)       //Load timeLW
    ldr r4, [r4]                                // load value of timeLW 
    LDR r5, =(TIMER_BASE + TIMEHR_OFFSET)       // Load timeHW
    ldr r5, [r5]                                // Load value of timeHW
    // store in memory
    LDR r6, =stime                      // load syst time
    STR r4, [r6, #8]                                // store Lower value in system_time + 8
    STR r5, [r6, #12]                            // store Uppervalue in system_time + 12

    pop {pc}


// Checks times and see what we write to memory dash or dot
check_time_pressed:
    push        {lr}
    LDR r3, =stime
    LDR r4, [r3]   //load lower value of old time
    LDR r5, [r3, #4]    //load upper value of old time
    LDR r6, [r3, #8]    //load lower value of current time
    LDR r7, [r3, #12]   //load upper value of current time 
    SUBS r6, r6, r4  // Time button held for
    LDR r3, =#400000    // Load time between button press
    CMP r6, r3 // if current time - past time > 200000 dash (1)
    BLT dot
dash:
    LDR r6, =arrayIndex
    LDR r6, [r6] //load value stored in arrayIndex
    LDR r5, =#1 // Load a 1 (dash)
    LDR r4, =input_array
    str r5, [r4, r6]  //store a dot in array offset by arrayIndex
    ADDS r6, r6, #4 // increment arrayIndex
    LDR r3, =arrayIndex  // load arrayIndex address
    str r6, [r3]    // store into arrayIndex address
    bl end_check
dot:
    LDR r6, =arrayIndex
    LDR r6, [r6] //load value stored in arrayIndex
    LDR r5, =#2 // Load a 2 (dot)
    LDR r4, =input_array
    str r5, [r4, r6]  //store a dot in array offset by arrayIndex  // was an ldr here
    ADDS r6, r6, #4 // increment arrayIndex
    LDR r3, =arrayIndex  // load arrayIndex address
    str r6, [r3]  
end_check:
    pop         {pc}

@ Set data alignment
.data
    .align 4
    // dash == 2 dot == 1 (64 bytes space)
    input_array:
        .space 64           // Space in memory declared for array

    button_state:           // Is  button pressed or not
        .space 4



    // stores array arrayIndex
    arrayIndex:
        .space 4

    stime:
        .space 8    // may need more

    alarm_set:
        .space 4    // store 1 if alarm has been triggered

    interval:   // alarm interval
        .space 4
    .end
