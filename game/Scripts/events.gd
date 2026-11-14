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

# --- Network (backend Node: lobby y móviles). Los emite el autoload Net ---
signal net_connected
signal net_disconnected
signal net_connection_failed
signal room_created(code: String)
signal lobby_updated(players: Array, status: String)
signal game_started(players: Array)
signal player_choice_received(player_id: String, role: String, action_id: String, event_id: String, option_id: String)
signal room_closed(reason: String)
signal net_error(code: String, request_type: String)
