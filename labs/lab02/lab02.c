#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include "pico/stdlib.h"
#include "pico/float.h"     // Required for using single-precision variables.
#include "pico/double.h"    // Required for using double-precision variables.

float Wallis_Float();
double Wallis_Double();

int main() {

#ifndef WOKWI
    // Initialise the IO as we will be using the UART
    // Only required for hardware and not needed for Wokwi
    stdio_init_all();
#endif
    float pifloat = 3.14159265359;
    double pidouble = 3.14159265359;
    float faccuracy;
    double daccuracy;
    float fout = Wallis_Float();
    printf("Float output: %f\n", fout);
    faccuracy = pifloat - fout;
    printf("Float output %f off PI\n", faccuracy);
    double dout = Wallis_Double();
    printf("Double output: %f\n", dout);
    daccuracy = pidouble - dout;
    printf("Double output %f off PI\n", daccuracy);

    // Returning zero indicates everything went okay.
    return 0;
}

//Calculates a float Pi approximation using Wallis algorithm
float Wallis_Float(){
    float out = 1.0f;
    float tmp;
    for(float i=1.0f;i<=100000.0f;i++){
      tmp = 4.0f*(i*i);
      out *= tmp/(tmp-1.0f);
    }
    out = out*2.0f;
    return out;
}

//Calculates a double Pi approximation using Wallis algorithm
double Wallis_Double(){
    double out = 1.0;
    double tmp;
    for(double i=1.0;i<=100000.0;i++){
      tmp = 4.0*(i*i);
      out *= tmp/(tmp-1.0);
    }
    out = out*2.0;
    return out;   
}

