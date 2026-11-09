package mods.enemy_health;

import openfl.display.Sprite;
import openfl.display.MovieClip;
import brain.assetRepository.AssetLoadingComponent;
import brain.assetRepository.SwfAsset;
import brain.uI.UIProgressBar;
import facade.DBFacade;

/** Larger version of the game's HP strip, only for bosses. */
class HealthPanel extends Sprite {
    public var effects:Sprite;
    public var barWidth:Float = 450;
    public var barHeight:Float = 18;
    var frame:MovieClip;
    var progress:UIProgressBar;
    var hpText:NativeHpText;
    var title:NativeHpText;
    var alive:Bool = true;
    var objectives:Bool;
    var segmentFrames:Array<MovieClip> = [];
    var segmentProgress:Array<UIProgressBar> = [];

    public function new(facade:DBFacade, loader:AssetLoadingComponent, name:String, objectives:Bool = false) {
        super();
        this.objectives = objectives;
        mouseEnabled = false;
        mouseChildren = false;
        hpText = new NativeHpText(loader, 1);
        hpText.scaleX = hpText.scaleY = 0.75;
        hpText.visible = !objectives;
        addChild(hpText);
        title = new NativeHpText(loader, 1, 0xFFDD55);
        title.setValue(name.toUpperCase());
        title.y = -12;
        title.scaleX = title.scaleY = 0.65;
        addChild(title);
        effects = new Sprite();
        effects.y = barHeight + 2;
        effects.scaleX = effects.scaleY = 0.7;
        addChild(effects);
        loader.getSwfAsset(DBFacade.buildFullDownloadPath("Resources/Art2D/UI/db_UI_nametag.swf"), function(asset:SwfAsset) {
            if (!alive) return;
            if (objectives) {
                for (i in 0...3) {
                    var segmentClip:MovieClip = cast asset.instantiateRuntimeSymbol("UI_nametag", []);
                    if (segmentClip == null) return;
                    var segment:MovieClip = cast segmentClip.getChildByName("hp");
                    if (segment == null) segment = cast Reflect.getProperty(segmentClip, "hp");
                    if (segment == null) return;
                    var segmentFill:MovieClip = cast segment.getChildByName("hpBar");
                    if (segmentFill == null) segmentFill = cast Reflect.getProperty(segment, "hpBar");
                    if (segmentFill == null) return;
                    var strip = new UIProgressBar(facade, segmentFill);
                    strip.visible = true;
                    strip.value = 1;
                    segment.visible = true;
                    segment.alpha = 1;
                    segmentFrames.push(segment);
                    segmentProgress.push(strip);
                    addChildAt(segment, 0);
                }
                return;
            }
            var clip:MovieClip = cast asset.instantiateRuntimeSymbol("UI_nametag", []);
            if (clip == null) return;
            frame = cast clip.getChildByName("hp");
            if (frame == null) frame = cast Reflect.getProperty(clip, "hp");
            if (frame == null) return;
            var fill:MovieClip = cast frame.getChildByName("hpBar");
            if (fill == null) fill = cast Reflect.getProperty(frame, "hpBar");
            if (fill == null) return;
            progress = new UIProgressBar(facade, fill);
            frame.visible = true;
            frame.alpha = 1;
            progress.visible = true;
            addChildAt(frame, 0);
        });
    }

    public function isReady():Bool {
        return objectives ? segmentProgress.length == 3 : progress != null;
    }

    public function effectColumns():Int {
        return Std.int(Math.max(1, Math.min(16, Math.floor((barWidth + 8 * effects.scaleX) / (38 * effects.scaleX)))));
    }

    public function updateObjectives(remaining:Int, width:Float):Void {
        barWidth = width;
        hpText.visible = false;
        title.x = width / 2;
        effects.x = width / 2;
        var gap:Float = 6;
        var segmentWidth = (width - gap * 2) / 3;
        remaining = Std.int(Math.max(0, Math.min(3, remaining)));
        for (i in 0...segmentFrames.length) {
            var segment = segmentFrames[i];
            segment.scaleX = segment.scaleY = 1;
            var background = segment.getChildByName("hpBarBg");
            var box = background == null ? segment.getBounds(segment) : background.getBounds(segment);
            if (box.width > 0 && box.height > 0) {
                segment.scaleX = segmentWidth / box.width;
                segment.scaleY = barHeight / box.height;
                segment.x = i * (segmentWidth + gap) - box.x * segment.scaleX;
                segment.y = -box.y * segment.scaleY;
            }
            segmentProgress[i].value = i < remaining ? 1 : 0;
        }
    }

    public function updateHP(hp:Float, maxHP:Float, width:Float):Void {
        barWidth = width;
        if (frame != null) {
            frame.scaleX = frame.scaleY = 1;
            var box = frame.getBounds(frame);
            if (box.width > 0 && box.height > 0) {
                frame.scaleX = width / box.width;
                frame.scaleY = barHeight / box.height;
                frame.x = -box.x * frame.scaleX;
                frame.y = -box.y * frame.scaleY;
            }
            if (progress != null) progress.value = maxHP > 0 ? Math.max(0, Math.min(1, hp / maxHP)) : 0;
        }
        var value = NativeHpText.formatHP(hp);
        hpText.setValue(value);
        hpText.x = width / 2;
        hpText.y = barHeight / 2;
        title.x = width / 2;
        effects.x = width / 2;
    }

    public function dispose():Void {
        alive = false;
        if (progress != null) progress.destroy();
        for (strip in segmentProgress) strip.destroy();
        hpText.dispose();
        title.dispose();
        if (parent != null) parent.removeChild(this);
    }
}
