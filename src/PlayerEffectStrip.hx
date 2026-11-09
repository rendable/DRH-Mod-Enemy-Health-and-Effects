package mods.enemy_health;

import distributedObjects.HeroGameObject;
import openfl.display.BitmapData;
import openfl.display.Sprite;
import openfl.geom.Matrix;
import starling.display.Image;
import starling.textures.Texture;

/** Actor-bound effects in the same render layer as the player's nametag. */
class PlayerEffectStrip {
    public var effects:Map<Int, EffectIcon> = new Map();
    public var layer:Sprite;
    var hero:HeroGameObject;
    var image:Image;
    var snapshot:BitmapData;
    var lastStamp:String = "";

    public function new(hero:HeroGameObject) {
        this.hero = hero;
        layer = new Sprite();
        layer.mouseEnabled = false;
        layer.mouseChildren = false;
    }

    public function hide():Void {
        layer.visible = false;
        if (image != null) image.visible = false;
    }

    public function update(hidden:Bool):Void {
        hide();
        var tag = hero.actorNametag;
        if (hidden || hero.isDestroyed || hero.isDead() || tag == null || !tag.shownOnScreen || layer.numChildren == 0) return;
        var bar = tag.hpBar;
        if (bar == null || bar.parent == null) return;
        var parent = bar.parent;
        var border = bar.getChildByName("hpBarBg");
        var bounds = border == null ? bar.getBounds(parent) : border.getBounds(parent);
        var top = bounds.y;
        // Keep icons above the player's name and AFK line, not on top of them.
        for (name in ["mTextField", "mAFKText"]) {
            var text:openfl.text.TextField = cast Reflect.field(tag, name);
            if (text != null && text.text != "") top = Math.min(top, text.getBounds(parent).y);
        }
        var local = layer.getBounds(layer);
        var x = bounds.x + bounds.width / 2;
        var y = top - 5 - local.bottom;
        var backend:Dynamic = Reflect.field(tag, "mStarlingNametag");
        var view:Dynamic = backend == null ? null : Reflect.field(backend, "mView");
        var usingStarling = backend != null && Reflect.field(backend, "mFlashHidden") == true && view != null;
        if (usingStarling) {
            var types:Array<Int> = [for (type in effects.keys()) type];
            types.sort(function(a:Int, b:Int):Int { return a - b; });
            var stamp = "";
            for (type in types) stamp += type + ":" + effects.get(type).revision + ";";
            if (image == null || stamp != lastStamp) {
                clearImage();
                var density:Float = 2;
                snapshot = new BitmapData(Std.int(Math.ceil(local.width * density)), Std.int(Math.ceil(local.height * density)), true, 0);
                // Snapshot only when membership, stacks, or asynchronously loaded art changes.
                layer.visible = true;
                snapshot.draw(layer, new Matrix(density, 0, 0, density, -local.x * density, -local.y * density), null, null, null, true);
                layer.visible = false;
                image = new Image(Texture.fromBitmapData(snapshot, false));
                image.touchable = false;
                image.width = local.width;
                image.height = local.height;
                lastStamp = stamp;
            }
            var starlingParent:starling.display.Sprite = cast view.art;
            if (image.parent != starlingParent) starlingParent.addChild(image);
            image.x = x + local.x;
            image.y = y + local.y;
            image.visible = true;
        } else {
            if (layer.parent != parent) parent.addChild(layer);
            layer.x = x;
            layer.y = y;
            layer.visible = true;
        }
    }

    function clearImage():Void {
        if (image != null) {
            var texture = image.texture;
            image.removeFromParent(true);
            texture.dispose();
            image = null;
        }
        if (snapshot != null) {
            snapshot.dispose();
            snapshot = null;
        }
    }

    public function dispose():Void {
        for (icon in effects) icon.dispose();
        effects.clear();
        clearImage();
        if (layer.parent != null) layer.parent.removeChild(layer);
    }
}
