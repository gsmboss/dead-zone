@tool
extends EditorPlugin
## Плагин редактора Dead Zone: при экспорте Android вставляет в манифест <uses-permission … tools:node="remove">
## для разрешений, которые приносят чужие плагины, а игре не нужны (Google Play к ним придирается).
## Работает при каждой сборке Gradle — правка android/build/AndroidManifest.xml руками не нужна.

var _export_plugin: DeadZoneAndroidExport


func _enter_tree() -> void:
	_export_plugin = DeadZoneAndroidExport.new()
	add_export_plugin(_export_plugin)


func _exit_tree() -> void:
	if _export_plugin != null:
		remove_export_plugin(_export_plugin)
		_export_plugin = null


class DeadZoneAndroidExport extends EditorExportPlugin:
	## Notification Scheduler: точные будильники и игнор оптимизации батареи — напоминаниям игры не нужны
	## (без них плагин ставит обычные неточные уведомления)
	const REMOVED_PERMISSIONS: PackedStringArray = [
		"android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS",
		"android.permission.SCHEDULE_EXACT_ALARM",
		"android.permission.USE_EXACT_ALARM",
	]

	func _get_name() -> String:
		return "DeadZoneAndroidExport"

	func _supports_platform(platform: EditorExportPlatform) -> bool:
		return platform is EditorExportPlatformAndroid

	func _get_android_manifest_element_contents(_platform: EditorExportPlatform, _debug: bool) -> String:
		var lines := PackedStringArray()
		for permission: String in REMOVED_PERMISSIONS:
			lines.append('<uses-permission android:name="%s" tools:node="remove" />' % permission)
		return "\n".join(lines) + "\n"
