package mods.enemy_health;

import openfl.display.Sprite;
import openfl.display.MovieClip;
import openfl.text.TextField;
import openfl.filters.GlowFilter;
import brain.assetRepository.AssetLoadingComponent;
import brain.assetRepository.SwfAsset;
import facade.DBFacade;

/** Uses the exact exported floater_text symbol, including its embedded font. */
class NativeHpText extends Sprite {
    var clip:MovieClip;
    var label:TextField;
    var value:String = "";
    var textScale:Float;
    var color:Int;
    var alive:Bool = true;
    public var styleReady:Bool = false;

    public function new(loader:AssetLoadingComponent, scale:Float = 0.6, color:Int = 0xFFFFFF) {
        super();
        mouseEnabled = false;
        mouseChildren = false;
        this.textScale = scale;
        this.color = color;
        loader.getSwfAsset(DBFacade.buildFullDownloadPath("Resources/Art2D/UI/db_UI_HUD.swf"), function(asset:SwfAsset) {
            if (!alive) return;
            clip = cast asset.instantiateRuntimeSymbol("floater_text", []);
            if (clip == null) return;
            clip.stop();
            label = cast clip.getChildByName("label");
            if (label == null) label = cast Reflect.getProperty(clip, "label");
            if (label == null) return;
            label.selectable = false;
            label.mouseEnabled = false;
            label.wordWrap = false;
            label.multiline = false;
            var format = label.defaultTextFormat;
            format.align = "left";
            format.leading = 0;
            label.defaultTextFormat = format;
            styleReady = true;
            addChild(clip);
            render();
        });
    }

    public function applyStyle(target:TextField, text:String):Void {
        if (label != null) {
            var format = label.defaultTextFormat;
            format.align = "left";
            format.color = color;
            format.leading = 0;
            format.bold = true;
            target.defaultTextFormat = format;
            target.embedFonts = label.embedFonts;
            target.filters = [new GlowFilter(0x000000, 1, 2, 2, 4, 1)];
            target.text = text;
            target.setTextFormat(format);
        } else {
            target.text = text;
        }
        target.textColor = color;
        target.wordWrap = false;
        target.multiline = false;
        target.width = target.textWidth + 8;
        target.height = target.textHeight + 6;
    }

    public static function formatHP(value:Float):String {
        var text = Std.string(Math.max(0, Math.round(value)));
        var out = "";
        for (index in 0...text.length) {
            if (index > 0 && (text.length - index) % 3 == 0) out += ",";
            out += text.charAt(index);
        }
        return out;
    }

    public function setValue(text:String):Void {
        if (value == text && label != null) return;
        value = text;
        render();
    }

    function render():Void {
        if (label == null || clip == null) return;
        label.text = value;
        label.textColor = color;
        label.width = label.textWidth + 8;
        label.height = label.textHeight + 6;
        clip.scaleX = clip.scaleY = textScale;
        clip.x = -(label.x + label.textWidth / 2 + 2) * textScale;
        clip.y = -(label.y + label.textHeight / 2 + 2) * textScale;
    }

    public function dispose():Void {
        alive = false;
        if (parent != null) parent.removeChild(this);
    }
}
