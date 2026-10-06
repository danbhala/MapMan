extends RefCounted
## The AdMob side of Ads (scripts/ads.gd), through Poing Studios' plugin
## (addons/admob, see its MAPMAN.md). Loaded only on a phone: the plugin's
## classes make editor mock nodes on the desktop.

## A failed load is tried again after this long (seconds), backing off.
const RETRY_SECONDS := [10.0, 30.0, 60.0, 120.0]

var _ads: Node  # the Ads autoload: units, the tree for timers, `changed`
var _sdk_ready := false
var _loaded := {}  # unit key -> RewardedAd or InterstitialAd
var _loading := {}  # unit key -> true while a load is out
var _retries := {}  # unit key -> failed loads in a row


func _init(ads: Node) -> void:
	_ads = ads


## Google's consent form first where the law asks for one, then the SDK,
## then every ad loads.
func start() -> void:
	var params := ConsentRequestParameters.new()
	params.tag_for_under_age_of_consent = false
	UserMessagingPlatform.consent_information.update(
		params, _on_consent_info, func(_e: FormError) -> void: _init_sdk()
	)


func _on_consent_info() -> void:
	var info := UserMessagingPlatform.consent_information
	if not info.get_is_consent_form_available():
		_init_sdk()
		return
	UserMessagingPlatform.load_consent_form(
		func(form: ConsentForm) -> void:
			if info.get_consent_status() == ConsentInformation.ConsentStatus.REQUIRED:
				form.show(func(_e: FormError) -> void: _init_sdk())
			else:
				_init_sdk(),
		func(_e: FormError) -> void: _init_sdk()
	)


func _init_sdk() -> void:
	var config := RequestConfiguration.new()
	config.max_ad_content_rating = RequestConfiguration.MAX_AD_CONTENT_RATING_PG
	MobileAds.set_request_configuration(config)
	var listener := OnInitializationCompleteListener.new()
	listener.on_initialization_complete = func(_s: InitializationStatus) -> void:
		_sdk_ready = true
		load_all()
	MobileAds.initialize(listener)


func load_all() -> void:
	for key in _ads.TEST_UNITS:
		_load(key)


func has(key: String) -> bool:
	return _loaded.has(key)


func _load(key: String) -> void:
	if not _sdk_ready or _ads.off or _loaded.has(key) or _loading.get(key, false):
		return
	_loading[key] = true
	if key == "level_clear":
		var callback := InterstitialAdLoadCallback.new()
		callback.on_ad_loaded = func(ad: InterstitialAd) -> void: _on_loaded(key, ad)
		callback.on_ad_failed_to_load = func(_e: LoadAdError) -> void: _on_failed(key)
		InterstitialAdLoader.new().load(_ads.unit(key), AdRequest.new(), callback)
	else:
		var callback := RewardedAdLoadCallback.new()
		callback.on_ad_loaded = func(ad: RewardedAd) -> void: _on_loaded(key, ad)
		callback.on_ad_failed_to_load = func(_e: LoadAdError) -> void: _on_failed(key)
		RewardedAdLoader.new().load(_ads.unit(key), AdRequest.new(), callback)


func _on_loaded(key: String, ad: RefCounted) -> void:
	_loading[key] = false
	_retries[key] = 0
	_loaded[key] = ad
	_ads.changed.emit()


func _on_failed(key: String) -> void:
	_loading[key] = false
	var n: int = _retries.get(key, 0)
	_retries[key] = n + 1
	var wait: float = RETRY_SECONDS[mini(n, RETRY_SECONDS.size() - 1)]
	await _ads.get_tree().create_timer(wait).timeout
	_load(key)


## `done(earned)` runs once the ad has closed. One that fails to play
## counts as earned (see Ads.show_rewarded).
func show_rewarded(key: String, done: Callable) -> void:
	var ad: RewardedAd = _loaded[key]
	_loaded.erase(key)
	var earned := [false]
	var finish := func(reward: bool) -> void:
		ad.destroy()
		_load(key)
		done.call(reward)
	ad.full_screen_content_callback.on_ad_dismissed_full_screen_content = func() -> void:
		finish.call(earned[0])
	ad.full_screen_content_callback.on_ad_failed_to_show_full_screen_content = (func(
		_e: AdError
	) -> void:
		finish.call(true))
	var listener := OnUserEarnedRewardListener.new()
	listener.on_user_earned_reward = func(_item: RewardedItem) -> void: earned[0] = true
	ad.show(listener)


func show_interstitial(done: Callable) -> void:
	var ad: InterstitialAd = _loaded["level_clear"]
	_loaded.erase("level_clear")
	var finish := func() -> void:
		ad.destroy()
		_load("level_clear")
		done.call()
	ad.full_screen_content_callback.on_ad_dismissed_full_screen_content = finish
	ad.full_screen_content_callback.on_ad_failed_to_show_full_screen_content = (func(
		_e: AdError
	) -> void:
		finish.call())
	ad.show()


func privacy_options_required() -> bool:
	var status := UserMessagingPlatform.consent_information.get_privacy_options_requirement_status()
	return status == ConsentInformation.PrivacyOptionsRequirementStatus.REQUIRED


func show_privacy_options() -> void:
	UserMessagingPlatform.show_privacy_options_form()


func reset_consent() -> void:
	UserMessagingPlatform.consent_information.reset()


func drop_all() -> void:
	for ad in _loaded.values():
		ad.destroy()
	_loaded.clear()
