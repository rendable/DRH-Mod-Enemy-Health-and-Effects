package mods.enemy_health;

import openfl.display.Sprite;
import openfl.display.DisplayObject;
import openfl.display.DisplayObjectContainer;
import openfl.display.MovieClip;
import openfl.text.TextField;
import openfl.text.TextFormat;
import openfl.filters.GlowFilter;
import brain.assetRepository.AssetLoadingComponent;
import brain.assetRepository.SwfAsset;
import facade.DBFacade;
import gameMasterDictionary.GMBuff;

class EffectIcon extends Sprite {
    public var alive:Bool = true;
    public var seen:Bool = false;
    public var revision:Int = 0;
    var artHolder:Sprite;
    var stacks:TextField;
    var fallback:TextField;

    public function new(loader:AssetLoadingComponent, gm:GMBuff) {
        super();
        mouseEnabled = false;
        mouseChildren = false;
        graphics.lineStyle(1, 0xB8B8B8, 0.9);
        graphics.beginFill(0x121212, 0.95);
        graphics.drawRoundRect(0, 0, 30, 30, 4, 4);
        graphics.endFill();
        artHolder = new Sprite();
        addChild(artHolder);
        fallback = new TextField();
        fallback.defaultTextFormat = new TextFormat("_sans", 15, 0xFFFFFF, true);
        fallback.text = gm.Name != null && gm.Name.length > 0 ? gm.Name.substr(0, 2).toUpperCase() : "?";
        fallback.width = 30;
        fallback.height = 24;
        fallback.x = (30 - fallback.textWidth) / 2 - 2;
        fallback.y = 4;
        fallback.selectable = false;
        fallback.mouseEnabled = false;
        artHolder.addChild(fallback);
        stacks = new TextField();
        stacks.defaultTextFormat = new TextFormat("_sans", 11, 0xFFFF99, true);
        stacks.filters = [new GlowFilter(0x000000, 1, 3, 3, 4)];
        stacks.width = 30;
        stacks.height = 18;
        stacks.y = 16;
        stacks.selectable = false;
        stacks.mouseEnabled = false;
        addChild(stacks);
        if (gm.IconSwf != null && gm.IconSwf.length > 0 && gm.IconName != null && gm.IconName.length > 0) {
            var name = gm.IconName;
            loader.getSwfAsset(DBFacade.buildFullDownloadPath(gm.IconSwf), function(asset:SwfAsset) {
                if (!alive) return;
                var icon:DisplayObject = cast asset.instantiateRuntimeSymbol(name, []);
                if (icon == null) return;
                stopArt(icon);
                var box = icon.getBounds(icon);
                if (!(box.width > 0 && box.height > 0)) return;
                var scale = Math.min(26 / box.width, 26 / box.height);
                icon.scaleX = icon.scaleY = scale;
                icon.x = 15 - (box.x + box.width / 2) * scale;
                icon.y = 15 - (box.y + box.height / 2) * scale;
                fallback.visible = false;
                artHolder.addChild(icon);
                revision++;
            });
        }
    }

    function stopArt(art:DisplayObject):Void {
        if (Std.isOfType(art, MovieClip)) cast(art, MovieClip).stop();
        if (Std.isOfType(art, DisplayObjectContainer)) {
            var container:DisplayObjectContainer = cast art;
            for (index in 0...container.numChildren) stopArt(container.getChildAt(index));
        }
    }

    public function updateStacks(count:Int):Void {
        var text = count > 1 ? "x" + count : "";
        if (stacks.text != text) {
            stacks.text = text;
            revision++;
        }
        stacks.x = 30 - stacks.textWidth - 3;
    }

    public function dispose():Void {
        alive = false;
        if (parent != null) parent.removeChild(this);
        while (numChildren > 0) removeChildAt(numChildren - 1);
    }
}
