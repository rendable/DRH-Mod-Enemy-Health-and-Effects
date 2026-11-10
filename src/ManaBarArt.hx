package mods.enemy_health_and_effects;

import brain.assetRepository.AssetLoadingComponent;
import brain.assetRepository.SwfAsset;
import facade.DBFacade;
import openfl.display.BitmapData;
import openfl.display.MovieClip;
import openfl.geom.Matrix;
import openfl.geom.Point;
import openfl.geom.Rectangle;
import starling.textures.Texture;

/** One shared pair of textures, shaped from the native nametag HP strip. */
class ManaBarArt {
    public var background:BitmapData;
    public var fill:BitmapData;
    public var backgroundTexture:Texture;
    public var fillTexture:Texture;
    public var fillBox:Rectangle;
    public var width:Float;
    public var height:Float;
    var alive:Bool = true;

    public function new(loader:AssetLoadingComponent) {
        loader.getSwfAsset(DBFacade.buildFullDownloadPath("Resources/Art2D/UI/db_UI_nametag.swf"), function(asset:SwfAsset) {
            if (!alive) return;
            var clip:MovieClip = cast asset.instantiateRuntimeSymbol("UI_nametag", []);
            if (clip == null) return;
            var frame:MovieClip = cast clip.getChildByName("hp");
            if (frame == null) frame = cast Reflect.getProperty(clip, "hp");
            if (frame == null) return;
            var red:MovieClip = cast frame.getChildByName("hpBar");
            if (red == null) red = cast Reflect.getProperty(frame, "hpBar");
            if (red == null) return;
            var border = frame.getChildByName("hpBarBg");
            var box = border == null ? frame.getBounds(frame) : border.getBounds(frame);
            var redBox = red.getBounds(frame);
            if (box.width <= 0 || box.height <= 0 || redBox.width <= 0 || redBox.height <= 0) return;
            width = box.width;
            height = box.height;
            fillBox = new Rectangle((redBox.x - box.x) / width, (redBox.y - box.y) / height,
                redBox.width / width, redBox.height / height);
            var density:Float = 4;
            var bw = Std.int(Math.ceil(width * density));
            var bh = Std.int(Math.ceil(height * density));
            background = new BitmapData(bw, bh, true, 0);
            red.visible = false;
            var matrix = new Matrix(density, 0, 0, density, -box.x * density, -box.y * density);
            background.draw(frame, matrix, null, null, null, true);
            red.visible = true;

            var fw = Std.int(Math.ceil(redBox.width * density));
            var fh = Std.int(Math.ceil(redBox.height * density));
            var mask = new BitmapData(fw, fh, true, 0);
            var relative = red.transform.matrix.clone();
            var parent = red.parent;
            while (parent != null && parent != frame) {
                relative.concat(parent.transform.matrix);
                parent = parent.parent;
            }
            relative.concat(new Matrix(density, 0, 0, density, -redBox.x * density, -redBox.y * density));
            mask.draw(red, relative, null, null, null, true);
            fill = new BitmapData(fw, fh, true, 0);
            // Exact colors from the HUD's mana_bar gradient (symbol 181).
            // Rasterize rows directly. Drawing a script-created gradient Shape
            // through BitmapData.draw crashes the V17 native renderer.
            for (row in 0...fh) {
                var t = fh > 1 ? row / (fh - 1) : 0;
                var r = Std.int(Math.round(0x82 + (0x50 - 0x82) * t));
                var g = Std.int(Math.round(0x3B + (0x1A - 0x3B) * t));
                var b = Std.int(Math.round(0xC9 + (0x85 - 0xC9) * t));
                fill.fillRect(new Rectangle(0, row, fw, 1), 0xFF000000 | (r << 16) | (g << 8) | b);
            }
            // BitmapDataChannel.ALPHA = 8. Use its value because the mod loader
            // cannot link the abstract enum's static field as a runtime class.
            fill.copyChannel(mask, mask.rect, new Point(), 8, 8);
            mask.dispose();
        });
    }

    public function ready():Bool {
        return background != null && fill != null;
    }

    public function prepareTextures():Void {
        if (backgroundTexture == null && ready()) {
            backgroundTexture = Texture.fromBitmapData(background, false);
            fillTexture = Texture.fromBitmapData(fill, false);
        }
    }

    public function dispose():Void {
        alive = false;
        if (backgroundTexture != null) backgroundTexture.dispose();
        if (fillTexture != null) fillTexture.dispose();
        if (background != null) background.dispose();
        if (fill != null) fill.dispose();
    }
}
