extends Node
@warning_ignore_start("unused_signal")

# --- Scene & Flow Management ---
signal scene_change_requested(scene_key: String)
signal scene_transition_finished

# --- External Systems (NASA API & Mobile Control Panel) ---
signal nasa_data_received(data: Dictionary)
signal nasa_api_failed(error_code: int)
signal mobile_client_connected(device_id: String)
signal nfc_tag_scanned(tag_id: String, action_payload: Dictionary)

# --- Outpost Simulation Gameplay ---
signal oxygen_level_changed(current_level: float, max_level: float)
signal system_alert_triggered(system_name: String, severity: String)

# --- Audio ---
signal sfx_requested(sfx_key: String, pitch_variance: float)
