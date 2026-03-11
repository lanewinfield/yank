/*
 * GPIO interrupt test — trailing-edge debounce.
 * Wait for 50ms of no bouncing, then count as one pull.
 */

#include <zephyr/kernel.h>
#include <zephyr/drivers/gpio.h>
#include <zephyr/sys/printk.h>

static const struct gpio_dt_spec pull_switch =
	GPIO_DT_SPEC_GET(DT_ALIAS(yank_switch), gpios);

static struct gpio_callback switch_cb_data;
static struct k_work_delayable debounce_work;
static volatile uint32_t pull_count;
static volatile uint32_t isr_count;
static volatile bool pull_pending;

static void debounce_handler(struct k_work *work)
{
	/* Bouncing has stopped for 50ms — count this as one pull */
	if (pull_pending) {
		pull_pending = false;
		pull_count++;
		printk("Pull #%u (isr_total=%u)\n", pull_count, isr_count);
	}
}

static void switch_isr(const struct device *dev, struct gpio_callback *cb,
		       uint32_t pins)
{
	isr_count++;
	pull_pending = true;
	/* Reset the 50ms timer on every bounce */
	k_work_reschedule(&debounce_work, K_MSEC(50));
}

int main(void)
{
	printk("=== GPIO test (trailing debounce) ===\n");

	gpio_pin_configure_dt(&pull_switch, GPIO_INPUT);
	gpio_pin_interrupt_configure_dt(&pull_switch, GPIO_INT_EDGE_BOTH);
	gpio_init_callback(&switch_cb_data, switch_isr, BIT(pull_switch.pin));
	gpio_add_callback(pull_switch.port, &switch_cb_data);
	k_work_init_delayable(&debounce_work, debounce_handler);

	printk("Ready — pull the switch!\n");

	while (1) {
		k_msleep(1000);
	}
	return 0;
}
