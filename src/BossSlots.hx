package mods.enemy_health_and_effects;

/** Stable row assignment, with at most one replacement for a newly damaged boss. */
class BossSlots {
    public var ids:Array<Int> = [];
    public function new() {}

    public function select(visible:Array<Int>, priority:Int):Array<Int> {
        var retained:Array<Int> = [];
        for (id in ids) if (visible.indexOf(id) >= 0) retained.push(id);
        ids = retained;
        for (id in visible) if (ids.length < 3 && ids.indexOf(id) < 0) ids.push(id);
        if (priority >= 0 && visible.indexOf(priority) >= 0 && ids.indexOf(priority) < 0) {
            if (ids.length < 3) ids.push(priority);
            else ids[ids.length - 1] = priority;
        }
        return ids.copy();
    }

    public function clear():Void { ids = []; }
}
