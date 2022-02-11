#include "pico/stdlib.h"

 void LEDloop(const uint LED_PIN, const uint LED_DELAY);

int main() {

    // Specify the PIN number and sleep delay
    const uint LED_PIN   =  25;
    const uint LED_DELAY = 500;

    // Setup the LED pin as an output.
    gpio_init(LED_PIN);
    gpio_set_dir(LED_PIN, GPIO_OUT);

    // Do forever...
    while (true) {
        LEDloop(LED_PIN, LED_DELAY);
    }

    // Should never get here due to infinite while-loop.
    return 0;

}

//toggles LED on waits, then toggles LED off and waits
void LEDloop( const uint LED_PIN, const uint LED_DELAY){
        // Toggle the LED on and then sleep for delay period
        gpio_put(LED_PIN, 1);
        sleep_ms(LED_DELAY);

        // Toggle the LED off and then sleep for delay period
        gpio_put(LED_PIN, 0);
        sleep_ms(LED_DELAY);
}

