extends GutTest
## The Revision B lessons (new tiles for the second playthrough) stay out of
## the tutorial until the game has been finished once, and finishing says so.

const MAIN_SCENE := preload("res://scenes/main.tscn")

var game


func before_all() -> void:
	Save.persist = false
	Dev.persist = false
	Dev.enabled = false


func before_each() -> void:
	Save.has_completed = false
	Save.new_lessons = false
	game = MAIN_SCENE.instantiate()
	add_child_autofree(game)


func after_all() -> void:
	Save.has_completed = false
	Save.new_lessons = false


func _rev_b_count() -> int:
	return (
		game.tutorial_all.filter(func(l: Dictionary) -> bool: return l.get("rev_b", false)).size()
	)


func test_tutorial_json_has_revision_b_lessons() -> void:
	assert_gt(_rev_b_count(), 0, "the crumble lesson is marked rev_b")


func test_revision_b_lessons_wait_for_a_finished_game() -> void:
	assert_eq(game.lessons().size(), game.tutorial_all.size() - _rev_b_count())
	Save.has_completed = true
	assert_eq(game.lessons().size(), game.tutorial_all.size(), "all lessons once finished")


func test_the_tutorial_counts_only_the_lessons_on_offer() -> void:
	game.menus.close()
	game.new_game(1, true)
	assert_eq(game.tutorial_levels.size(), game.tutorial_all.size() - _rev_b_count())
	for lesson in game.tutorial_levels:
		assert_false(lesson.get("rev_b", false), "no rev_b lesson before the finish")


func test_finishing_the_first_time_announces_the_new_lessons() -> void:
	game._mark_completed()
	assert_true(Save.has_completed)
	assert_true(Save.new_lessons, "the news is set on the first finish")
	assert_eq(game.tutorial_levels.size(), game.tutorial_all.size(), "lessons added at once")


func test_finishing_again_is_not_news() -> void:
	Save.has_completed = true
	game._mark_completed()
	assert_false(Save.new_lessons)


func test_starting_the_tutorial_reads_the_news() -> void:
	game._mark_completed()
	game.menus.close()
	game.new_game(1, true)
	assert_false(Save.new_lessons, "NEW goes once the tutorial is opened")
	assert_eq(game.tutorial_levels.size(), game.tutorial_all.size())
