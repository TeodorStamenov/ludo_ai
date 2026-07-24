class_name TestCase
extends GutTest
## Обратно-съвместим alias на GutTest за съществуващите тестови файлове.
##
## Всички тестове, наследяващи TestCase, автоматично получават пълния
## GUT 9.6.1 API от реалния framework (bitwes/Gut).
##
## setUp() / tearDown() продължават да работят — runner-ите ги извикват
## преди/след before_each() / after_each().


## Псевдоним за обратна съвместимост с тестове написани под fake-GUT.
## Реалният GUT 9.x метод е assert_string_starts_with().
func assert_string_begins_with(
		value: String, prefix: String,
		match_case: bool = true, _msg: String = "") -> void:
	assert_string_starts_with(value, prefix, match_case)
