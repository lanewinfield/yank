#include <zephyr/kernel.h>
#include <zephyr/sys/printk.h>

int main(void)
{
	printk("Hello from Yank!\n");
	while (1) {
		printk("alive\n");
		k_msleep(1000);
	}
	return 0;
}
