package mods.enemy_health;

import distributedObjects.HeroGameObject;
import openfl.display.Bitmap;
import openfl.display.Sprite;
import starling.display.Image;
import brain.assetRepository.AssetLoadingComponent;

/** Follows the existing player nametag in either rendering backend. */
class PlayerManaEntry {
    public var seen:Bool = false;
    public var effectStrip:PlayerEffectStrip;
    var hero:HeroGameObject;
    var art:ManaBarArt;
    var flashBar:Sprite;
    var flashBackground:Bitmap;
    var flashFill:Bitmap;
    var starlingBar:starling.display.Sprite;
    var starlingBackground:Image;
    var starlingFill:Image;
    var numbers:PlayerBarNumbers;
    var avatarLayout:PlayerAvatarLayout;

    public function new(hero:HeroGameObject, art:ManaBarArt, loader:AssetLoadingComponent) {
        this.hero = hero;
        this.art = art;
        effectStrip = new PlayerEffectStrip(hero);
        numbers = new PlayerBarNumbers(loader);
        avatarLayout = new PlayerAvatarLayout();
    }

    public function update(hidden:Bool):Void {
        hide();
        effectStrip.update(hidden);
        var tag = hero.actorNametag;
        if (!art.ready() || hero.isDestroyed || hero.isDead() || tag == null || !tag.shownOnScreen
            || !tag.hpBarVisible || hidden || !(hero.maxManaPoints > 0)) return;
        var bar = tag.hpBar;
        if (bar == null || bar.parent == null) return;
        var border = bar.getChildByName("hpBarBg");
        var box = border == null ? bar.getBounds(bar.parent) : border.getBounds(bar.parent);
        if (box.width <= 0 || box.height <= 0) return;
        avatarLayout.update(cast Reflect.field(tag, "mNametagFBPicSlot"), bar.parent, box);
        var ratio = Math.max(0, Math.min(1, hero.manaPoints / hero.maxManaPoints));
        var backend:Dynamic = Reflect.field(tag, "mStarlingNametag");
        var view:Dynamic = backend == null ? null : Reflect.field(backend, "mView");
        var usingStarling = backend != null && Reflect.field(backend, "mFlashHidden") == true && view != null;
        if (usingStarling) {
            art.prepareTextures();
            if (starlingBar == null) {
                starlingBar = new starling.display.Sprite();
                starlingBar.touchable = false;
                starlingBackground = new Image(art.backgroundTexture);
                starlingFill = new Image(art.fillTexture);
                starlingBar.addChild(starlingBackground);
                starlingBar.addChild(starlingFill);
            }
            var parent:starling.display.Sprite = cast view.art;
            if (starlingBar.parent != parent) parent.addChild(starlingBar);
            starlingBar.visible = true;
            starlingBar.x = box.x;
            starlingBar.y = box.bottom + 2;
            starlingBackground.width = box.width;
            starlingBackground.height = box.height;
            starlingFill.x = box.width * art.fillBox.x;
            starlingFill.y = box.height * art.fillBox.y;
            starlingFill.visible = ratio > 0;
            if (ratio > 0) starlingFill.width = box.width * art.fillBox.width * ratio;
            starlingFill.height = box.height * art.fillBox.height;
        } else {
            if (flashBar == null) {
                flashBar = new Sprite();
                flashBar.mouseEnabled = false;
                flashBar.mouseChildren = false;
                flashBackground = new Bitmap(art.background);
                flashFill = new Bitmap(art.fill);
                flashBackground.smoothing = flashFill.smoothing = true;
                flashBar.addChild(flashBackground);
                flashBar.addChild(flashFill);
            }
            if (flashBar.parent != bar.parent) bar.parent.addChild(flashBar);
            flashBar.visible = true;
            flashBar.x = box.x;
            flashBar.y = box.bottom + 2;
            flashBackground.width = box.width;
            flashBackground.height = box.height;
            flashFill.x = box.width * art.fillBox.x;
            flashFill.y = box.height * art.fillBox.y;
            flashFill.visible = ratio > 0;
            flashFill.width = box.width * art.fillBox.width * ratio;
            flashFill.height = box.height * art.fillBox.height;
        }
        numbers.update(bar.parent, box, view, usingStarling, hero.hitPoints, hero.manaPoints);
    }

    public function hide():Void {
        effectStrip.hide();
        numbers.hide();
        if (flashBar != null) flashBar.visible = false;
        if (starlingBar != null) starlingBar.visible = false;
    }

    public function dispose():Void {
        effectStrip.dispose();
        numbers.dispose();
        avatarLayout.restore();
        if (flashBar != null && flashBar.parent != null) flashBar.parent.removeChild(flashBar);
        if (starlingBar != null) starlingBar.removeFromParent(true);
        flashBar = null;
        starlingBar = null;
    }
}
