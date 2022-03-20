#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include "pico/stdlib.h"
#include "pico/float.h"     // Required for using single-precision variables.
#include "pico/double.h"    // Required for using double-precision variables.
#include "pico/multicore.h" // Required for using multiple cores on the RP2040.


float Wallis_Float_Par(int ITER_MAX);
double Wallis_Double_Par(int ITER_MAX);

/**
 * @brief This function acts as the main entry-point for core #1.
 *        A function pointer is passed in via the FIFO with one
 *        incoming int32_t used as a parameter. The function will
 *        provide an int32_t return value by pushing it back on 
 *        the FIFO, which also indicates that the result is ready.
 */
void core1_entry() {
    while (1) {
        // 
        int32_t (*func)() = (int32_t(*)()) multicore_fifo_pop_blocking();
        int32_t p = multicore_fifo_pop_blocking();
        
        absolute_time_t time4 = get_absolute_time();    //    Take snapshot of timer and store
        int32_t result = (*func)(p);
        absolute_time_t time5 = get_absolute_time();    //    Take snapshot of timer and store
        int32_t diff = (int32_t) absolute_time_diff_us (time4, time5);    // Difference in time for Float on other core

        //multicore_fifo_push_blocking(result);
        multicore_fifo_push_blocking(diff);
    }
}

// Main code entry point for core0.
int main() {

    const int    ITER_MAX   = 100000;

    stdio_init_all();
    multicore_launch_core1(core1_entry); // start core 1
    
    // Code for sequential run goes here…
    absolute_time_t time1 = get_absolute_time();    //    Take snapshot of timer and store
    Wallis_Float_Par(ITER_MAX);                     //    Run the single-precision Wallis approximation
    absolute_time_t time2 = get_absolute_time();    //    Take snapshot of timer and store
    uint64_t diff = absolute_time_diff_us (time1, time2);   // Difference in time for single precision
    int cast = (int) diff;                          // Cast uinnt64_t to integer
    printf("The single-precision function execution time when using a single-core: %d\n", cast); //    Display time taken for application to run in sequential mode
    Wallis_Double_Par(ITER_MAX);                    //    Run the double-precision Wallis approximation
    absolute_time_t time3 = get_absolute_time();    //    Take snapshot of timer and store
    diff = absolute_time_diff_us (time2, time3);    // Difference in time for double precision
    cast = (int) diff;                              // Cast uinnt64_t to integer
    printf("The double-precision function execution time when using a single-core: %d\n", cast); //    Display time taken for both functions to run in sequential mode
    diff = absolute_time_diff_us (time1, time3);    // Difference in time for squentially running both functions
    cast = (int) diff;                              // Cast uinnt64_t to integer
    printf("Total execution time for running the single-precision and double-precision functions in sequentially using a single CPU core: %d\n", cast);


    // Code for parallel run goes here…
    uint32_t address = (uint32_t) * Wallis_Float_Par;
    multicore_fifo_push_blocking(address);          // Send address of Wallis_Float function
    multicore_fifo_push_blocking(ITER_MAX);         // Send parameter

    // runs core 1

    absolute_time_t timeX = get_absolute_time();    //    Take snapshot of timer and store (Start of Parallel)
    absolute_time_t time6 = get_absolute_time();    //    Take snapshot of timer and store
    Wallis_Double_Par(ITER_MAX);                    //    Run the double-precision Wallis approximation on the other core
    absolute_time_t time7 = get_absolute_time();    //    Take snapshot of timer and store
    diff = absolute_time_diff_us (time6, time7);    // Difference in time for double precision on core0

    cast = (int) multicore_fifo_pop_blocking();     // Cast uinnt32_t to integer
    absolute_time_t timeY = get_absolute_time();    // End of parralel timer
    printf("The single-precision function execution time when using both cores: %d\n", cast);//    Display time taken for application to run in parallel mode

    cast = (int) diff;                              // Cast uinnt64_t to integer
    printf("The double-precision function execution time when using both cores: %d\n", cast);//    Display time taken for application to run in parallel mode
    diff = absolute_time_diff_us (timeX, timeY);    // Difference in time for both cores
    cast = (int) diff;                              // Cast uinnt64_t to integer
    printf("Total execution time for running the single-precision and double-precision functions in parallel across both CPU core: %d\n", cast); // Total time taken Parralel

    return 0;
}

//Calculates a double Pi approximation using Wallis algorithm
double Wallis_Double_Par(int ITER_MAX){
    double out = 1.0;
    double tmp;
    for(double i=1.0;i<=ITER_MAX;i++){
      tmp = 4.0*(i*i);
      out *= tmp/(tmp-1.0);
    }
    out = out*2.0;
    return out;   
}

//Calculates a float Pi approximation using Wallis algorithm
float Wallis_Float_Par(int ITER_MAX){
    float out = 1.0f;
    float tmp;
    for(float i=1.0f;i<=ITER_MAX;i++){
      tmp = 4.0f*(i*i);
      out *= tmp/(tmp-1.0f);
    }
    out = out*2.0f;
    return out;
}