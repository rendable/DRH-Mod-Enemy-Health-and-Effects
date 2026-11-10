package mods.enemy_health_and_effects;

/** Map plus custom-floor signature, never a monster-name substring. */
class BossRules {
    public static function qualifies(constant:String, map:String, tiles:Array<String>, nativeBoss:Bool):Bool {
        switch (constant) {
            case "MINOTAUR_TUTORIAL": return map == "TUTORIAL" && tiles.indexOf("9.1318154724467") >= 0;
            case "JUGGERNAUT": return map == "ARENA_BOSS" && tiles.indexOf("70.1334872172452") >= 0;
            case "PAPA_YETI": return map == "ICE_CAVES_BOSS" && tiles.indexOf("435.1327521552662") >= 0;
            case "TOUGH_JUGGERNAUT": return false;
            case "ELITE_JUGGERNAUT":
                return map == "PRISON_BOSS" && tiles.indexOf("454.1334956026168") >= 0;
            case "FROST_TROLL": return map == "TEMPLE_BOSS" && tiles.indexOf("271.1333708475942") >= 0;
            case "MINOTAUR", "MINOTAUR_CHAMPION": return false;
            case "RIVAL_BERSERKER": return map == "ARENA_BOSS_2" && tiles.indexOf("2.1337645062987") >= 0;
            default: return nativeBoss || constant == "BLUE_DRAGON";
        }
    }

    public static function title(constant:String, name:String):String {
        if (constant == "ELITE_JUGGERNAUT") return "Elite Juggernaut";
        if (constant == "TOUGH_JUGGERNAUT") return "Tough Juggernaut";
        return name == null ? "BOSS" : name;
    }
}
