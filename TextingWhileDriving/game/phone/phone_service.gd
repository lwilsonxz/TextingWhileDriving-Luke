extends Node
## Plays conversations on the phone in the car. Autoloaded as `PhoneService`.
##
## Levels (through TextTrigger) and conversations (through <<start_thread>>)
## ask for a conversation by thread and node:
##   PhoneService.start_thread("Mom", "Mom_L1_Start")
## The thread name is the contact shown at the top of the phone; the node is
## where the conversation starts in the Yarn files.
##
## For the prototype the phone shows one conversation at a time. A thread
## started while another is playing waits its turn (first come, first served).
## Roadmap A5 later gives each contact its own runner and history so several
## threads can be live at once.
##
## Story variables live here, not in the level, so they carry over between
## levels (the seed of saving the story).

## A conversation started playing on the phone.
signal thread_started(thread: String, node: String)
## The conversation that was playing reached its end (or was stopped).
signal thread_finished(thread: String)

## The game's dialogue. Triggers can name another Yarn project instead (the test
## course uses the writing template's sample until real conversations exist).
const DEFAULT_PROJECT := "res://dialogue/Dialogue.yarnproject"

## Multiplies every #delay (tests use 0 so messages arrive at once).
var delay_scale := 1.0:
	set(value):
		delay_scale = value
		for project in _players:
			_players[project].presenter.delay_scale = value

## Every story variable ($mom_trust, ...), shared by all conversations. Variables
## not set yet read as their <<declare>> value. GameFlow saves and restores them.
var storage: YarnInMemoryVariableStorage

## Messages the player typed and sent in this level (for the results screen).
var messages_sent := 0
## Replies the player didn't pick in time, so the conversation moved on without them.
var replies_missed := 0

# One dialogue runner and presenter per Yarn project (Yarn ties a runner to one
# project): project path -> {runner, presenter}.
var _players := {}
# The phone screen in the car, once the car's phone has registered itself.
var _view: ChatView
# Threads waiting to play: [{thread, node, project}], oldest first.
var _queue: Array[Dictionary] = []
# The thread playing now ({thread, node, project}), or empty when the phone is idle.
var _playing := {}


func _ready() -> void:
	storage = YarnInMemoryVariableStorage.new()
	storage.name = "StoryVariables"
	add_child(storage)


## Called by the car's phone when it appears: conversations will play on `view`.
func attach_view(view: ChatView) -> void:
	_view = view
	# A new phone means a new level: start its counts from zero.
	messages_sent = 0
	replies_missed = 0
	for project in _players:
		_players[project].presenter.view = view
	_play_next()


## Called by the car's phone when it goes away (the level ends). Anything playing
## or waiting is dropped, since there's no screen to show it on.
func detach_view(view: ChatView) -> void:
	if view != _view:
		return
	_view = null
	_queue.clear()
	stop()
	for project in _players:
		_players[project].presenter.view = null


## Loads a Yarn project ahead of time. Triggers call this when the level starts,
## because loading mid-drive stalls a frame and throws the next few timers off.
func prepare(project := DEFAULT_PROJECT) -> void:
	if _players.has(project):
		return
	var runner := YarnDialogueRunner.new()
	runner.name = "Runner_" + project.get_file().get_basename()
	runner.yarn_project = load(project)
	runner.auto_start = false
	runner.show_selected_option_as_line = false  # the player already typed it
	runner.variable_storage = storage
	add_child(runner)
	var presenter := ChatPresenter.new()
	presenter.view = _view
	presenter.delay_scale = delay_scale
	presenter.line_presented.connect(func(sender: String, _text: String):
		if sender == ChatPresenter.PLAYER:
			messages_sent += 1)
	presenter.reply_timed_out.connect(func(): replies_missed += 1)
	runner.add_child(presenter)
	runner.add_presenter(presenter)
	runner.dialogue_completed.connect(_on_finished)
	_players[project] = {"runner": runner, "presenter": presenter}


## Starts a conversation, or queues it if another one is playing. `project`
## defaults to the project of the conversation playing now (so <<start_thread>>
## stays in the same files), otherwise the game's dialogue.
func start_thread(thread: String, node: String, project := "") -> void:
	if project == "":
		project = _playing.get("project", DEFAULT_PROJECT)
	_queue.append({"thread": thread, "node": node, "project": project})
	_play_next()


## True while a conversation is on the phone.
func is_playing() -> bool:
	return not _playing.is_empty()


## The contact of the conversation playing now ("" when idle).
func current_thread() -> String:
	return _playing.get("thread", "")


## How many threads are waiting for the phone.
func queued_count() -> int:
	return _queue.size()


## Stops the conversation that's playing. Threads waiting in the queue stay.
func stop() -> void:
	if _playing.is_empty():
		return
	var runner: YarnDialogueRunner = _players[_playing.project].runner
	var thread: String = _playing.thread
	_playing = {}
	if runner.is_running():
		runner.stop_dialogue()
	thread_finished.emit(thread)


# Starts the oldest waiting thread, if the phone is free and on screen.
func _play_next() -> void:
	if not _playing.is_empty() or _queue.is_empty() or _view == null:
		return
	_playing = _queue.pop_front()
	prepare(_playing.project)
	# A different contact gets a fresh screen; the same contact carries on below
	# their earlier messages.
	if _view.get_meta("thread", "") != _playing.thread:
		_view.clear()
		_view.set_title(_playing.thread)
		_view.set_meta("thread", _playing.thread)
	thread_started.emit(_playing.thread, _playing.node)
	_players[_playing.project].runner.start_dialogue(_playing.node)


# A conversation reached its end: free the phone and play the next one.
func _on_finished() -> void:
	if _playing.is_empty():
		return
	var thread: String = _playing.thread
	_playing = {}
	thread_finished.emit(thread)
	# Wait a frame: the runner finishes tidying up after this signal.
	await get_tree().process_frame
	_play_next()
