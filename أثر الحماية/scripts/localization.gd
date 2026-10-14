extends RefCounted
## Shared text catalog for the playable Godot slice.

const STRINGS := {
	"title": {"ar": "ATHAR  |  أثر", "en": "ATHAR  |  أثر"},
	"chapter": {"ar": "غابة الأمل  ·  الفصل الأول", "en": "Hope Forest  ·  Chapter I"},
	"objective": {"ar": "اجمع ٣ بذور قمرية وأيقظ الجسر الجذري.", "en": "Gather 3 moonseeds and wake the root bridge."},
	"objective_restored": {"ar": "عاد النور! اعبر الجسر واتبع اليراعات.", "en": "The grove is waking. Cross the bridge and follow the fireflies."},
	"seeds": {"ar": "بذور القمر", "en": "MOONSEEDS"},
	"language_button": {"ar": "العربية / EN", "en": "العربية / EN"},
	"jump": {"ar": "قفز", "en": "Jump"},
	"use": {"ar": "تفاعل", "en": "Use"},
	"pause_title": {"ar": "استراحة بين الأشجار", "en": "A quiet clearing"},
	"pause_body": {"ar": "تتحرك الغابة عندما تعود.", "en": "The forest will wait for you here."},
	"resume": {"ar": "متابعة الرحلة", "en": "Return to the trail"},
	"restart": {"ar": "إعادة من البداية", "en": "Start this trail again"},
	"win_title": {"ar": "عاد الأثر إلى الغابة!", "en": "The forest remembers"},
	"win_body": {"ar": "عادت الجذور إلى الحياة، وصار للطريق أثر أخضر جديد.", "en": "You restored the root bridge and brought the first colors back to Hope Forest."},
	"play_again": {"ar": "العب من جديد", "en": "Walk the trail again"},
	"need_seeds": {"ar": "اجمع كل البذور أولًا.", "en": "Gather all three moonseeds first."},
	"bridge_first": {"ar": "أعد الحياة إلى الجسر أولًا.", "en": "Restore the root bridge first."},
	"bridge_awake": {"ar": "الجسر عاد للحياة!", "en": "The bridge is alive again!"},
	"prompt_plant": {"ar": "اقترب واضغط E لإيقاظ البذرة", "en": "Press E to wake the root"},
	"prompt_need": {"ar": "هذه البذرة تحتاج إلى ٣ بذور قمرية", "en": "This sprout needs all 3 moonseeds"},
	"prompt_gate": {"ar": "اضغط E لعبور البوابة", "en": "Press E to pass the lantern gate"},
	"prompt_gate_wait": {"ar": "البوابة تنتظر عودة الجسر", "en": "The gate waits for the root bridge"},
	"controls": {"ar": "A / D أو الأسهم للحركة  ·  Space للقفز  ·  E للتفاعل", "en": "A / D or arrows to move  ·  Space to leap  ·  E to interact"}
}


static func text(key: String, language: String) -> String:
	var entry: Dictionary = STRINGS.get(key, {})
	return str(entry.get(language, entry.get("en", key)))

