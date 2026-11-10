package mods.enemy_health_and_effects;

import brain.assetRepository.AssetLoadingComponent;
import openfl.display.BitmapData;
import openfl.display.DisplayObjectContainer;
import openfl.display.Sprite;
import openfl.geom.Matrix;
import openfl.geom.Rectangle;
import openfl.text.TextField;
import starling.display.Image;
import starling.textures.Texture;

/** Values over both player strips, preserving the existing player name. */
class PlayerBarNumbers {
    var font:NativeHpText;
    var layer:Sprite;
    var hp:TextField;
    var mana:TextField;
    var image:Image;
    var snapshot:BitmapData;
    var lastStamp:String = "";

    public function new(loader:AssetLoadingComponent) {
        font = new NativeHpText(loader);
        layer = new Sprite();
        layer.mouseEnabled = false;
        layer.mouseChildren = false;
        hp = new TextField();
        mana = new TextField();
        hp.selectable = mana.selectable = false;
        hp.mouseEnabled = mana.mouseEnabled = false;
        layer.addChild(hp);
        layer.addChild(mana);
    }

    function fit(field:TextField, value:String, width:Float, height:Float, y:Float):Void {
        font.applyStyle(field, value);
        var scale = Math.min(1.15, Math.min(height * 1.12 / Math.max(1, field.textHeight - 4),
            width * 0.96 / Math.max(1, field.textWidth + 4)));
        field.scaleX = field.scaleY = scale;
        field.x = width / 2 - (field.textWidth / 2 + 2) * scale;
        field.y = y + height / 2 - (field.textHeight / 2 + 2) * scale;
    }

    public function update(parent:DisplayObjectContainer, box:Rectangle, view:Dynamic, usingStarling:Bool, health:Float, mp:Float):Void {
        var hpValue = NativeHpText.formatHP(health);
        var manaValue = NativeHpText.formatHP(mp);
        var stamp = hpValue + "|" + manaValue + "|" + box.width + "|" + box.height + "|" + font.styleReady;
        if (stamp != lastStamp) {
            fit(hp, hpValue, box.width, box.height, 0);
            fit(mana, manaValue, box.width, box.height, box.height + 2);
            clearImage();
            lastStamp = stamp;
        }
        if (usingStarling) {
            if (image == null) {
                var bounds = layer.getBounds(layer);
                var density:Float = 2;
                snapshot = new BitmapData(Std.int(Math.ceil(bounds.width * density)), Std.int(Math.ceil(bounds.height * density)), true, 0);
                layer.visible = true;
                snapshot.draw(layer, new Matrix(density, 0, 0, density, -bounds.x * density, -bounds.y * density), null, null, null, true);
                layer.visible = false;
                image = new Image(Texture.fromBitmapData(snapshot, false));
                image.touchable = false;
                image.width = bounds.width;
                image.height = bounds.height;
            }
            var bounds = layer.getBounds(layer);
            var starlingParent:starling.display.Sprite = cast view.art;
            // Bring values above both bars even when a pooled nametag is reused.
            starlingParent.addChild(image);
            image.x = box.x + bounds.x;
            image.y = box.y + bounds.y;
            image.visible = true;
        } else {
            parent.addChild(layer);
            layer.x = box.x;
            layer.y = box.y;
            layer.visible = true;
        }
    }

    public function hide():Void {
        layer.visible = false;
        if (image != null) image.visible = false;
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
        clearImage();
        font.dispose();
        if (layer.parent != null) layer.parent.removeChild(layer);
    }
}
