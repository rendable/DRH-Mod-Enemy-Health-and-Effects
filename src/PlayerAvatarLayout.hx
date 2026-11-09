package mods.enemy_health;

import openfl.display.DisplayObject;
import openfl.display.DisplayObjectContainer;
import openfl.geom.Point;
import openfl.geom.Rectangle;

/** Keep the native temporary profile slot clear of the added mana strip. */
class PlayerAvatarLayout {
    var slot:DisplayObject;
    var originalY:Float = 0;

    public function new() {}

    public function update(current:DisplayObject, parent:DisplayObjectContainer, hp:Rectangle):Void {
        if (slot != current) {
            restore();
            slot = current;
            if (slot != null) originalY = slot.y;
        }
        if (slot == null) return;
        // Always measure at the unmodified position, avoiding cumulative drift.
        slot.y = originalY;
        if (!slot.visible || slot.alpha <= 0 || slot.parent == null) return;
        var picture = slot.getBounds(parent);
        var manaBottom = hp.bottom + 2 + hp.height;
        var gap:Float = 4;
        if (picture.width <= 0 || picture.height <= 0 || picture.right <= hp.x || picture.x >= hp.right
            || picture.bottom <= hp.y || picture.y >= manaBottom + gap) return;
        var zero = parent.globalToLocal(slot.parent.localToGlobal(new Point(0, 0)));
        var unit = parent.globalToLocal(slot.parent.localToGlobal(new Point(0, 1)));
        var yScale = unit.y - zero.y;
        if (Math.abs(yScale) < 0.001) return;
        slot.y = originalY + (manaBottom + gap - picture.y) / yScale;
    }

    public function restore():Void {
        if (slot != null) slot.y = originalY;
        slot = null;
    }
}
