extends ColorRect

## All TeleDot View does is create a server, let the 
## controller connect to it and then just receive and listen
## to the commands being send
##
## Each var that gets send should be [function_name, value]
## List of possible commands which can be send:
## [change_color_background, Color]
## [change_color_text, Color]
## [change_script, String]
## [change_alignment, int]
## [change_mirror, bool]
## [change_margin, int]
## [change_scroll_speed, int]
## [change_font_size, int]
##
## [command_play_pause, null]
## [command_move_up, null]
## [command_move_down, null]
## [command_jump_beginning, null]
## [command_jump_end, null]
## [command_page_up, null]
## [command_page_down, null]


# Connection variables:
const PORT := 55757
var broadcaster : PacketPeerUDP
var connection : StreamPeerTCP
var connected := false
var server: TCPServer
var client_status: int = connection.STATUS_NONE

# Script formatting variables:
var base_script: String
var formatted_script: String
var alignment: int = 1

# Playback variables:
var scroll_speed: float = 2
var play: bool = false
var intended_scroll: float = 0
var smooth_scroll_amount: float = 0.3

# Array of all script functions
var functions := []


func _ready() -> void:
	# Getting all script functions
	for function in get_method_list():
		functions.append(function.name)
	start_server()


func start_server() -> void:
	print("Starting server")
	$NoConnection.visible = true
	$Script.visible = false
	
	# Initialize server
	broadcaster = PacketPeerUDP.new()
	broadcaster.set_broadcast_enabled(true)
	server = TCPServer.new()
	var error := server.listen(PORT)
	if error != OK:
		print_debug("Error '%s' when listening on port %s" % [error, PORT])
	
	for x in IP.get_local_addresses():
		if !(x.count('.') == 3 and !x.begins_with("127")):
			continue
		%IPLabel.text = "IP: %s" % x
		break
	broadcaster.set_dest_address("255.255.255.255", PORT)


func _process(delta: float) -> void:
	# Make the script scroll on screen when play is pressed
	if play:
		intended_scroll += scroll_speed
	
	# Clamp intended scroll
	if intended_scroll <= 0:
		intended_scroll = 0
	if intended_scroll >= %ScriptBox.size.y:
		intended_scroll = %ScriptBox.size.y
	
	# Smooth scroll to intended scroll position
	%ScriptScroll.scroll_vertical += (intended_scroll - %ScriptScroll.scroll_vertical) * smooth_scroll_amount
	
	# Accept connection when client tries to connect 
	if server.is_connection_available(): 
		connection = server.take_connection()
		$NoConnection.visible = false
		$Script.visible = true
		#Broadcaster cleanup
		broadcaster.close()
		$BroadcastTimer.stop()
	
	# Starting from this point, things only get executed
	# when having a connection with a TeleDot controller
	if connection == null:
		return
	connection.poll()
	if client_status != connection.get_status():
		client_status = connection.get_status()
		$Script.visible = true
	
	# Check to see if the latest poll was able
	# to check if still connected.
	if client_status != connection.STATUS_CONNECTED:
		print("Connection got lost , restarting server!")
		connection = null
		start_server()
		client_status = connection.STATUS_NONE
		return
	if connection.get_available_bytes() != 0:
		var data: Array = connection.get_var()
		if data[0] not in functions:
			print_debug("This function does not exist: %s" % data[0])
			return
		self.call(data[0], data[1])
		if data[0] == "change_alignment":
			change_script()


func broadcast_ip():
	var data = JSON.stringify("TeleDot")
	var packet = data.to_utf8_buffer()
	broadcaster.put_packet(packet)


func _exit_tree():
	if !broadcaster == null:
		broadcaster.close()


## COMMANDS  #################################################

func command_play_pause(_value) -> void:
	play = !play


func command_move_up(_value) -> void:
	intended_scroll -= scroll_speed


func command_move_down(_value) -> void:
	intended_scroll += scroll_speed


func command_jump_beginning(_value):
	intended_scroll = 0


func command_jump_end(_value):
	intended_scroll = %ScriptBox.size.y + 100


func command_page_up(_value):
	intended_scroll -= get_window().size.y


func command_page_down(_value):
	intended_scroll += get_window().size.y


## CHANGE SETTING COMMANDS ###################################

func change_color_background(new_color: Color = Color8(0,0,0)) -> void:
	self.self_modulate = new_color


func change_color_text(new_color: Color = Color8(255,255,255)) -> void:
	%ScriptBox.self_modulate = new_color


func change_script(text: String = base_script) -> void:
	base_script = text
	change_alignment()
	%ScriptBox.text = formatted_script


func change_alignment(new_align: int = alignment) -> void:
	alignment = new_align
	match alignment:
		0: # Left
			formatted_script = "[left]%s[/left]" % base_script
		1: # Center
			formatted_script = "[center]%s[/center]" % base_script
		2: # Right
			formatted_script = "[right]%s[/right]" % base_script


func change_mirror(mirror: bool) -> void:
	$Script.flip_h = mirror


func change_margin(margin: int) -> void:
	%ScriptMargin.add_theme_constant_override("margin_left", margin*10)
	%ScriptMargin.add_theme_constant_override("margin_right", margin*10)


func change_scroll_speed(speed: int) -> void:
	scroll_speed = float(speed * speed) / 100


func change_font_size(value: int) -> void:
	%ScriptBox.add_theme_font_size_override("normal_font_size", value*5)
	%ScriptBox.add_theme_font_size_override("bold_font_size", value*5)
	%ScriptBox.add_theme_font_size_override("italics_font_size", value*5)
	%ScriptBox.add_theme_font_size_override("bold_italics_font_size", value*5)
	%ScriptBox.add_theme_font_size_override("mono_font_size", value*5)


func _on_get_controller_button_pressed() -> void:
	# Take people to the itch page to download controller
	# and to see the instructions
	OS.shell_open("https://voylin.itch.io/TeleDot")
