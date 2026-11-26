extends OmniLight3D
## Fire light: energy wobbles with smooth noise so torches and candles feel alive.

var amount := 0.22
var speed := 7.0

var _base_energy := 1.0
var _noise := FastNoiseLite.new()
var _time := 0.0


func _ready() -> void:
	_base_energy = light_energy
	_noise.seed = randi()
	_noise.frequency = 1.0
	_time = randf() * 100.0


func _process(delta: float) -> void:
	_time += delta * speed
	light_energy = _base_energy * (1.0 + _noise.get_noise_1d(_time) * amount * 2.0)
