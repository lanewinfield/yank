/*
 * Yank! Pull Switch Firmware
 *
 * Hardware: Seeed XIAO nRF54L15
 * Pull switch on D3 (gpio1 pin 7), active low with internal pull-up.
 *
 * Power strategy:
 *   - CONFIG_PM=y lets the CPU sleep between events (System ON idle)
 *   - GPIO interrupt wakes CPU instantly on pull
 *   - Relaxed BLE connection interval (30-50ms) with slave latency 4
 *   - On pull: request fast interval (7.5-15ms) for reliable delivery,
 *     then relax back after 2 seconds
 *   - Advertising slows down after 30s of no connection
 *   - Battery read every 60s instead of 30s
 *   - UART disabled in production build
 */

#include <zephyr/kernel.h>
#include <zephyr/drivers/gpio.h>
#include <zephyr/bluetooth/bluetooth.h>
#include <zephyr/bluetooth/conn.h>
#include <zephyr/bluetooth/gatt.h>
#include <zephyr/bluetooth/uuid.h>
#include <zephyr/bluetooth/services/bas.h>
#include <zephyr/drivers/adc.h>
#include <zephyr/sys/printk.h>

/* ── UUIDs ─────────────────────────────────────────────── */

#define BT_UUID_YANK_SVC_VAL \
	BT_UUID_128_ENCODE(0xb26f59c7, 0x68f1, 0x48c8, 0xa4d1, 0x676648080123)
#define BT_UUID_YANK_SVC    BT_UUID_DECLARE_128(BT_UUID_YANK_SVC_VAL)

#define BT_UUID_YANK_PULL_VAL \
	BT_UUID_128_ENCODE(0xb26f59c7, 0x68f1, 0x48c8, 0xa4d1, 0x676648080124)
#define BT_UUID_YANK_PULL   BT_UUID_DECLARE_128(BT_UUID_YANK_PULL_VAL)

/* ── Connection parameter profiles ─────────────────────── */

/* Fast: used briefly after a pull for reliable notification delivery */
static const struct bt_le_conn_param conn_param_fast =
	BT_LE_CONN_PARAM_INIT(6, 12, 0, 400);   /* 7.5-15ms, no latency */

/* Idle: relaxed for power savings. Latency 4 = radio skips 4 events. */
static const struct bt_le_conn_param conn_param_idle =
	BT_LE_CONN_PARAM_INIT(24, 40, 4, 400);  /* 30-50ms, latency 4 */

/* ── Hardware ──────────────────────────────────────────── */

static const struct gpio_dt_spec pull_switch =
	GPIO_DT_SPEC_GET(DT_ALIAS(yank_switch), gpios);

static const struct gpio_dt_spec led =
	GPIO_DT_SPEC_GET(DT_ALIAS(led0), gpios);

/* ── BLE state ─────────────────────────────────────────── */

static bool notify_enabled;
static bool is_connected;
static bool is_advertising;
static uint8_t pull_count;
static struct bt_conn *current_conn;

/* ── GATT service ──────────────────────────────────────── */

static void ccc_changed(const struct bt_gatt_attr *attr, uint16_t value)
{
	notify_enabled = (value == BT_GATT_CCC_NOTIFY);
	printk("Notifications %s\n", notify_enabled ? "on" : "off");
}

BT_GATT_SERVICE_DEFINE(yank_svc,
	BT_GATT_PRIMARY_SERVICE(BT_UUID_YANK_SVC),
	BT_GATT_CHARACTERISTIC(BT_UUID_YANK_PULL,
		BT_GATT_CHRC_NOTIFY,
		BT_GATT_PERM_NONE,
		NULL, NULL, NULL),
	BT_GATT_CCC(ccc_changed,
		BT_GATT_PERM_READ | BT_GATT_PERM_WRITE),
);

/* ── Connection parameter management ──────────────────── */

static struct k_work_delayable relax_conn_work;

static void relax_conn_handler(struct k_work *work)
{
	if (current_conn) {
		bt_conn_le_param_update(current_conn, &conn_param_idle);
		printk("Conn params -> idle\n");
	}
}

static void request_fast_conn(void)
{
	if (!current_conn) {
		return;
	}
	bt_conn_le_param_update(current_conn, &conn_param_fast);
	printk("Conn params -> fast\n");

	/* Relax back to idle after 2 seconds */
	k_work_reschedule(&relax_conn_work, K_SECONDS(2));
}

/* ── Notification ──────────────────────────────────────── */

static int64_t last_pull_time;

static void send_pull_notification(void)
{
	if (!is_connected || !notify_enabled) {
		return;
	}

	/* Switch to fast connection interval for reliable delivery */
	request_fast_conn();

	pull_count++;
	if (pull_count == 0) {
		pull_count = 1;
	}

	int64_t now = k_uptime_get();
	uint8_t elapsed_ds = 0;
	if (last_pull_time > 0) {
		int64_t ds = (now - last_pull_time) / 100;
		elapsed_ds = (ds > 255) ? 255 : (uint8_t)ds;
	}
	last_pull_time = now;

	uint8_t data[2] = { pull_count, elapsed_ds };
	bt_gatt_notify(NULL, &yank_svc.attrs[1], data, sizeof(data));
}

/* ── Advertising ───────────────────────────────────────── */

#define DEVICE_NAME     CONFIG_BT_DEVICE_NAME
#define DEVICE_NAME_LEN (sizeof(DEVICE_NAME) - 1)

static const struct bt_data ad[] = {
	BT_DATA_BYTES(BT_DATA_FLAGS, (BT_LE_AD_GENERAL | BT_LE_AD_NO_BREDR)),
	BT_DATA(BT_DATA_NAME_COMPLETE, DEVICE_NAME, DEVICE_NAME_LEN),
};

static const struct bt_data sd[] = {
	BT_DATA_BYTES(BT_DATA_UUID128_ALL, BT_UUID_YANK_SVC_VAL),
};

/* Fast advertising for initial 30s, then slow down */
static struct k_work_delayable slow_adv_work;

/* Fast: 100ms interval. Slow: 1s interval. */
#define ADV_FAST_PARAMS BT_LE_ADV_PARAM(BT_LE_ADV_OPT_CONNECTABLE, \
	BT_GAP_ADV_FAST_INT_MIN_2, BT_GAP_ADV_FAST_INT_MAX_2, NULL)

#define ADV_SLOW_PARAMS BT_LE_ADV_PARAM(BT_LE_ADV_OPT_CONNECTABLE, \
	0x0640, 0x0640, NULL)  /* 1000ms */

static void start_advertising_with_params(const struct bt_le_adv_param *params)
{
	if (is_advertising) {
		bt_le_adv_stop();
		is_advertising = false;
	}
	int err = bt_le_adv_start(params, ad, ARRAY_SIZE(ad),
				  sd, ARRAY_SIZE(sd));
	if (err) {
		printk("Adv failed (%d)\n", err);
		return;
	}
	is_advertising = true;
}

static void slow_adv_handler(struct k_work *work)
{
	if (is_advertising && !is_connected) {
		printk("Adv -> slow\n");
		start_advertising_with_params(ADV_SLOW_PARAMS);
	}
}

static void start_advertising(void)
{
	start_advertising_with_params(ADV_FAST_PARAMS);
	/* Switch to slow advertising after 30 seconds */
	k_work_schedule(&slow_adv_work, K_SECONDS(30));
}

/* ── Connection callbacks ──────────────────────────────── */

static void connected_cb(struct bt_conn *conn, uint8_t err)
{
	if (err) {
		printk("Connect failed (0x%02x)\n", err);
		return;
	}
	printk("Connected\n");
	current_conn = bt_conn_ref(conn);
	is_connected = true;
	is_advertising = false;
	gpio_pin_set_dt(&led, 1);

	/* Cancel slow-adv timer */
	k_work_cancel_delayable(&slow_adv_work);
}

static void disconnected_cb(struct bt_conn *conn, uint8_t reason)
{
	printk("Disconnected (0x%02x)\n", reason);
	if (current_conn) {
		bt_conn_unref(current_conn);
		current_conn = NULL;
	}
	is_connected = false;
	notify_enabled = false;
	gpio_pin_set_dt(&led, 0);

	/* Cancel any pending relax timer */
	k_work_cancel_delayable(&relax_conn_work);

	start_advertising();
}

BT_CONN_CB_DEFINE(conn_cbs) = {
	.connected = connected_cb,
	.disconnected = disconnected_cb,
};

/* ── Pull switch handling (trailing-edge debounce) ─────── */

static struct k_work_delayable debounce_work;
static struct gpio_callback switch_cb_data;
static volatile bool pull_pending;

static void debounce_handler(struct k_work *work)
{
	if (pull_pending) {
		pull_pending = false;
		printk("Pull!\n");
		send_pull_notification();

		if (!is_connected) {
			start_advertising();
		}
	}
}

static void switch_isr(const struct device *dev, struct gpio_callback *cb,
		       uint32_t pins)
{
	pull_pending = true;
	/* Reset the 50ms timer on every bounce edge */
	k_work_reschedule(&debounce_work, K_MSEC(50));
}

/* ── Battery ───────────────────────────────────────────── */

static const struct adc_dt_spec adc_chan =
	ADC_DT_SPEC_GET_BY_IDX(DT_PATH(zephyr_user), 0);

static bool adc_ready;
static int16_t adc_buf;
static struct k_work_delayable battery_work;

#define BATTERY_READ_INTERVAL_S 60

static void battery_work_handler(struct k_work *work)
{
	if (!adc_ready) {
		goto resched;
	}

	struct adc_sequence seq = {
		.buffer = &adc_buf,
		.buffer_size = sizeof(adc_buf),
		.channels = BIT(adc_chan.channel_id),
		.resolution = 12,
	};

	if (adc_read(adc_chan.dev, &seq) < 0) {
		goto resched;
	}

	int32_t mv = adc_buf;
	adc_raw_to_millivolts_dt(&adc_chan, &mv);

	/* 2:1 voltage divider on board */
	mv *= 2;

	uint8_t pct;
	if (mv >= 4200) {
		pct = 100;
	} else if (mv <= 3300) {
		pct = 0;
	} else {
		pct = (uint8_t)(((mv - 3300) * 100) / 900);
	}

	bt_bas_set_battery_level(pct);
	printk("Battery: %d mV -> %d%%\n", mv, pct);

resched:
	k_work_schedule(&battery_work, K_SECONDS(BATTERY_READ_INTERVAL_S));
}

static void init_adc(void)
{
	if (!adc_is_ready_dt(&adc_chan)) {
		printk("ADC not ready\n");
		return;
	}
	if (adc_channel_setup_dt(&adc_chan) < 0) {
		printk("ADC channel setup failed\n");
		return;
	}
	adc_ready = true;
}

/* ── Main ──────────────────────────────────────────────── */

int main(void)
{
	/* Brief delay to let HFXO stabilize before radio init.
	 * Some nRF54L15 units need this when UART/console is disabled
	 * (the UART init normally provides enough startup time). */
	k_msleep(100);

	int err = bt_enable(NULL);
	if (err) {
		return err;
	}

	/* LED */
	if (gpio_is_ready_dt(&led)) {
		gpio_pin_configure_dt(&led, GPIO_OUTPUT_INACTIVE);
	}

	/* Pull switch */
	gpio_pin_configure_dt(&pull_switch, GPIO_INPUT);
	gpio_pin_interrupt_configure_dt(&pull_switch, GPIO_INT_EDGE_BOTH);
	gpio_init_callback(&switch_cb_data, switch_isr, BIT(pull_switch.pin));
	gpio_add_callback(pull_switch.port, &switch_cb_data);
	k_work_init_delayable(&debounce_work, debounce_handler);

	/* Connection parameter management */
	k_work_init_delayable(&relax_conn_work, relax_conn_handler);

	/* Advertising slow-down timer */
	k_work_init_delayable(&slow_adv_work, slow_adv_handler);

	/* Battery ADC */
	init_adc();
	k_work_init_delayable(&battery_work, battery_work_handler);

	start_advertising();
	k_work_schedule(&battery_work, K_SECONDS(5));

	return 0;
}
