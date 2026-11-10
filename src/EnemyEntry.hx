package mods.enemy_health_and_effects;

import distributedObjects.NPCGameObject;
import actor.ActorNametag;
import facade.DBFacade;
import brain.assetRepository.AssetLoadingComponent;
import brain.workLoop.LogicalWorkComponent;
import openfl.display.Sprite;
import openfl.display.DisplayObject;
import openfl.text.TextField;
import actor.starlingConvertedOverlay.StarlingNametag;
import events.HpEvent;
import events.GameObjectEvent;

class EnemyEntry {
    public var npc:NPCGameObject;
    public var panel:HealthPanel;
    public var decorations:Sprite;
    public var effectLayer:Sprite;
    public var hit:Bool = false;
    public var encountered:Bool = false;
    public var seen:Bool = false;
    public var boss:Bool = false;
    public var panelSelected:Bool = false;
    public var lastDamage:Float = -1;
    public var effects:Map<Int, EffectIcon> = new Map();
    public var hp:Float = 0;
    public var maxHP:Float = 0;
    public var tag:ActorNametag;
    var facade:DBFacade;
    var loader:AssetLoadingComponent;
    var eventName:String;
    var createdTag:Bool = false;
    var originalVisible:Bool = true;
    var originalName:String;
    var lastText:String = "";
    var number:NativeHpText;
    var lastLayout:String = "";
    var originalText:Dynamic;

    public function new(facade:DBFacade, loader:AssetLoadingComponent, npc:NPCGameObject, isBoss:Bool) {
        this.facade = facade;
        this.loader = loader;
        this.npc = npc;
        hp = npc.hitPoints;
        maxHP = npc.maxHitPoints;
        // Never infer damage from scaled initial HP being below max HP.
        var constant = npc.gmNpc == null || npc.gmNpc.Constant == null ? "" : npc.gmNpc.Constant;
        decorations = new Sprite();
        decorations.mouseEnabled = false;
        decorations.mouseChildren = false;
        effectLayer = decorations;
        setBoss(isBoss);
        eventName = GameObjectEvent.uniqueEvent("HpEvent_HP_UPDATE", npc.id);
        facade.eventManager.addEventListener(eventName, healthChanged);
        syncTag(false);
    }

    function healthChanged(event:HpEvent):Void {
        if (event.hp < hp) { hit = true; lastDamage = facade.gameClock.gameTime; }
        hp = event.hp;
        maxHP = event.maxHp;
    }

    public function setBoss(value:Bool):Void {
        if (boss == value) return;
        boss = value;
        if (boss && panel == null) panel = new HealthPanel(facade, loader,
            BossRules.title(npc.gmNpc.Constant, npc.gmNpc.Name), npc.gmNpc.Constant == "BOSS_GOLEM");
        selectPanel(false);
        if (!boss && panel != null) { panel.dispose(); panel = null; }
    }

    public function selectPanel(value:Bool):Void {
        panelSelected = value;
        effectLayer = value && panel != null ? panel.effects : decorations;
        for (icon in effects) if (icon.parent != effectLayer) effectLayer.addChild(icon);
    }

    public function syncTag(show:Bool):Void {
        if (npc.actorView == null || npc.actorView.root == null) return;
        var view = npc.actorView;
        var current = npc.actorNametag;
        // Panel selection must not suppress the actor's numerical HP strip.
        // The objective-only Golem has no meaningful actor HP to display.
        var objectives = npc.gmNpc.Constant == "BOSS_GOLEM";
        if (current == null && show && !objectives) {
            var work:LogicalWorkComponent = cast Reflect.field(view, "mLogicalWorkComponent");
            if (work == null) return;
            current = new ActorNametag(facade, loader, work, npc.gmNpc.NametagY);
            current.cacheAsBitmap = true;
            Reflect.setField(view, "mNametag", current);
            view.root.addChild(current);
            createdTag = true;
        }
        if (current == null) return;
        if (tag != current) {
            tag = current;
            originalVisible = tag.visible;
            originalName = npc.screenName;
        }
        tag.visible = show && !objectives;
        if (!show || objectives) return;
        tag.hpBarVisible = true;
        tag.setHp(npc.hitPoints, Std.int(npc.maxHitPoints));
        var bar = tag.hpBar;
        if (bar != null) {
            var scale = npc.gmNpc.HealthbarScale;
            if (!(scale > 0)) scale = 1;
            bar.scaleX = scale / Math.max(0.01, Math.abs(view.root.scaleX));
            bar.scaleY = scale / Math.max(0.01, Math.abs(view.root.scaleY));
            var background:DisplayObject = bar.getChildByName("hpBarBg");
            var box = background == null ? bar.getBounds(view.root) : background.getBounds(view.root);
            if (number == null) {
                number = new NativeHpText(loader, 0.6);
            }
            // The text must use the native nametag backend. A separate Flash
            // floater clip is not rendered with Starling's world nametags.
            var textField:TextField = cast Reflect.field(tag, "mTextField");
            if (textField != null && textField.parent != null) {
                if (originalText == null) originalText = {
                    x: textField.x, y: textField.y, sx: textField.scaleX, sy: textField.scaleY,
                    width: textField.width, height: textField.height, format: textField.defaultTextFormat,
                    color: textField.textColor, embed: textField.embedFonts, filters: textField.filters,
                    index: textField.parent.getChildIndex(textField)
                };
                var bounds = background == null ? bar.getBounds(textField.parent) : background.getBounds(textField.parent);
                var text = NativeHpText.formatHP(npc.hitPoints);
                var layout = text + "|" + bounds.x + "|" + bounds.y + "|" + bounds.width + "|" + bounds.height + "|" + number.styleReady;
                if (layout != lastLayout) {
                    tag.screenName = text;
                    number.applyStyle(textField, text);
                    // Let the visible numerals fill the strip, as in the
                    // reference, instead of shrinking them around line padding.
                    var heightScale = bounds.height * 1.12 / Math.max(1, textField.textHeight - 4);
                    var widthScale = bounds.width * 0.96 / Math.max(1, textField.textWidth + 4);
                    var textScale = Math.min(1.15, Math.min(heightScale, widthScale));
                    textField.scaleX = textField.scaleY = textScale;
                    textField.x = bounds.x + bounds.width / 2 - (textField.textWidth / 2 + 2) * textScale;
                    textField.y = bounds.y + bounds.height / 2 - (textField.textHeight / 2 + 2) * textScale;
                    textField.parent.setChildIndex(textField, textField.parent.numChildren - 1);
                    var backend:StarlingNametag = cast Reflect.field(tag, "mStarlingNametag");
                    if (backend != null) {
                        var order:Dynamic = Reflect.field(backend, "mOrder");
                        if (order != null) { order[0] = 0; order[1] = 2; order[2] = 1; }
                        var rendered:Dynamic = Reflect.field(backend, "mView");
                        if (rendered != null) rendered.order(0, 2, 1);
                        backend.contentChanged();
                    }
                    lastLayout = layout;
                }
            }
            decorations.x = box.x + box.width / 2;
            decorations.y = box.y - 46;
            if (decorations.parent != view.root) view.root.addChild(decorations);
        }
    }

    public function dispose():Void {
        facade.eventManager.removeEventListener(eventName, healthChanged);
        for (icon in effects) icon.dispose();
        effects.clear();
        if (panel != null) panel.dispose();
        if (number != null) number.dispose();
        if (decorations.parent != null) decorations.parent.removeChild(decorations);
        if (npc != null && !npc.isDestroyed && tag != null && npc.actorNametag == tag) {
            if (createdTag) {
                tag.destroy();
                Reflect.setField(npc.actorView, "mNametag", null);
            } else {
                tag.visible = originalVisible;
                tag.screenName = originalName;
                var field:TextField = cast Reflect.field(tag, "mTextField");
                if (field != null && originalText != null) {
                    field.defaultTextFormat = originalText.format;
                    field.setTextFormat(originalText.format);
                    field.textColor = originalText.color;
                    field.embedFonts = originalText.embed;
                    field.filters = originalText.filters;
                    field.x = originalText.x;
                    field.y = originalText.y;
                    field.scaleX = originalText.sx;
                    field.scaleY = originalText.sy;
                    field.width = originalText.width;
                    field.height = originalText.height;
                    if (field.parent != null) field.parent.setChildIndex(field, originalText.index);
                    var backend:StarlingNametag = cast Reflect.field(tag, "mStarlingNametag");
                    if (backend != null) backend.contentChanged();
                }
            }
        }
    }
}
