package mods.enemy_health_and_effects;

import mods.api.Context;
import mods.api.Mod;
import facade.DBFacade;
import distributedObjects.DistributedDungeonFloor;
import distributedObjects.NPCGameObject;
import distributedObjects.HeroGameObject;
import actor.buffs.DistributedBuffGameObject;
import brain.assetRepository.AssetLoadingComponent;
import dBGlobals.DBGlobal;
import gameMasterDictionary.GMBuff;
import openfl.display.DisplayObject;
import openfl.display.Sprite;
import openfl.events.Event;
import openfl.geom.Point;

class Main extends Mod {
    var context:Context;
    var facade:DBFacade;
    var loader:AssetLoadingComponent;
    var entries:Map<Int, EnemyEntry> = new Map();
    var buffs:Map<Int, Dynamic> = new Map();
    var lastFloor:Int = -1;
    var failed:Bool = false;
    var bossLayer:Sprite;
    var golemPools:Map<Int, NPCGameObject> = new Map();
    var hardenedPools:Map<Int, Bool> = new Map();
    var players:Map<Int, PlayerManaEntry> = new Map();
    var manaArt:ManaBarArt;
    var manaFailed:Bool = false;
    var bossSlots:BossSlots = new BossSlots();
    var bossOverflow:NativeHpText;
    // Membership (who qualifies as a tracked enemy) is rescanned a few times a
    // second instead of every frame; only position/visibility/HP-bar sync for
    // already-tracked entries runs every frame.
    var nextActorScan:Float = 0;
    inline static var ACTOR_SCAN_INTERVAL:Float = 200;
    var floorMap:String = "";
    var floorTileIds:Array<String> = [];
    var golemRemaining:Int = 3;
    // Buff icons only need rebuilding when a buff actually appears/disappears.
    var effectsDirty:Bool = true;
    var lastViewWidth:Float = -1;
    var lastViewHeight:Float = -1;

    override public function init(context:Context):Void {
        this.context = context;
        context.overlay.mouseEnabled = false;
        context.overlay.mouseChildren = false;
        context.core.onObjectReady(function(object) {
            if (Std.isOfType(object, DistributedBuffGameObject)) { recordBuff(cast object); effectsDirty = true; }
        });
        context.core.onObjectGone(function(object) {
            if (Std.isOfType(object, DistributedBuffGameObject)) { buffs.remove(object.id); effectsDirty = true; }
        });
        context.onFloorExit(function(floor) {
            clearEnemies();
            buffs.clear();
            lastFloor = -1;
            failed = false;
        });
        context.overlay.addEventListener(Event.ENTER_FRAME, update);
    }

    override public function ready(context:Context):Void {
        facade = context.core.facade;
        loader = new AssetLoadingComponent(facade);
        bossLayer = new Sprite();
        bossLayer.mouseEnabled = false;
        bossLayer.mouseChildren = false;
        facade.sceneGraphManager.addChild(bossLayer, 50);
        bossOverflow = new NativeHpText(loader, 0.7);
        bossLayer.addChild(bossOverflow);
        bossOverflow.visible = false;
        context.log("loaded: native enemy HP, boss bars, player mana, and remote-player effect icons without countdowns");
    }

    function recordBuff(buff:DistributedBuffGameObject):Void {
        if (facade == null || buff == null || buff.isDestroyed) return;
        var actor:Int = Reflect.field(buff, "mEffectedActor");
        var gm:GMBuff = cast facade.gameMaster.buffById.itemFor(buff.type);
        if (gm == null) return;
        buffs.set(buff.id, {object: buff, actor: actor, type: buff.type, gm: gm});
    }

    function update(event:Event):Void {
        if (facade == null || failed || !context.core.alive) return;
        try {
            var wrapper = context.state.floor;
            if (wrapper == null) {
                if (bossOverflow != null) bossOverflow.visible = false;
                for (p in players) { var player:PlayerManaEntry = p; player.hide(); }
                for (e in entries) { var entry:EnemyEntry = e; if (entry.shown) hideEntry(entry); }
                return;
            }
            var floor:DistributedDungeonFloor = cast Reflect.field(wrapper, "floor");
            if (floor == null || floor.isDestroyed || floor.remoteActors == null) return;
            var now:Float = facade.gameClock.gameTime;
            if (lastFloor != floor.id) {
                clearEnemies();
                lastFloor = floor.id;
                floorMap = floor.gmMapNode == null ? "" : floor.gmMapNode.Constant;
                nextActorScan = 0;
            }
            var owner = floor.activeOwnerAvatar;
            var heroes:Int = owner == null ? (DBGlobal.TEAM_1 : Int) : owner.team;
            var hidden = facade.uiHideToggle != null && facade.uiHideToggle.hidden;
            // Membership (who qualifies, who's a boss, golem pool state) only
            // needs rechecking a few times a second, not every frame.
            if (now >= nextActorScan) {
                nextActorScan = now + ACTOR_SCAN_INTERVAL;
                scanActors(floor, heroes);
                scanPlayers(floor);
            }
            updatePlayerMana(hidden);
            syncBossLayerTransform();
            bossOverflow.visible = false;
            var bossCandidates:Array<EnemyEntry> = [];
            for (e in entries) {
                var entry:EnemyEntry = e;
                var npc:NPCGameObject = entry.npc;
                if (npc.isDestroyed) { if (entry.shown) hideEntry(entry); continue; }
                // Most enemies on a floor were never hit and aren't a boss -
                // skip the on-screen test (coordinate conversion, bounds
                // checks) entirely for them instead of doing it every frame.
                if (!entry.hit && !entry.boss) { if (entry.shown) hideEntry(entry); continue; }
                if (hidden || npc.actorView == null || npc.actorView.root == null) {
                    if (entry.shown) hideEntry(entry);
                    continue;
                }
                var root = npc.actorView.root;
                var onStage = showing(root);
                var position = facade.scalingRoot.globalToLocal(root.localToGlobal(new Point(0, -entry.nametagY)));
                var onScreen = onStage && position.x >= -100 && position.x <= context.viewWidth + 100
                    && position.y >= -100 && position.y <= context.viewHeight + 100;
                if (entry.boss && onStage && !onScreen) {
                    var bodyBox = root.getBounds(facade.scalingRoot);
                    onScreen = bodyBox.width > 0 && bodyBox.height > 0 && bodyBox.right >= 0 && bodyBox.bottom >= 0
                        && bodyBox.x <= context.viewWidth && bodyBox.y <= context.viewHeight;
                }
                if (entry.boss && onScreen) entry.encountered = true;
                var show = entry.boss ? entry.encountered && onScreen : entry.hit && onScreen;
                if (!show || !(entry.maxHP > 0)) { if (entry.shown) hideEntry(entry); continue; }
                if (entry.boss) bossCandidates.push(entry);
                // Until assigned a panel row, a boss uses its native overhead bar.
                entry.decorations.visible = true;
                entry.shown = true;
                entry.syncTag(true);
                entry.decorations.scaleX = 1 / Math.max(0.01, Math.abs(root.scaleX));
                entry.decorations.scaleY = 1 / Math.max(0.01, Math.abs(root.scaleY));
            }
            renderBosses(bossCandidates, golemRemaining);
        } catch (error:Dynamic) {
            failed = true;
            clearEnemies();
            context.log("enemy overlay stopped: " + Std.string(error));
        }
    }

    // Hides an entry's overlay (decorations/tag/panel) and marks it not
    // shown, so the per-frame loop can skip re-hiding an already-hidden
    // entry instead of writing all four every frame regardless of state.
    function hideEntry(entry:EnemyEntry):Void {
        entry.selectPanel(false);
        entry.decorations.visible = false;
        if (entry.panel != null) entry.panel.visible = false;
        entry.syncTag(false);
        entry.shown = false;
    }

    // Who qualifies as a tracked enemy, and the golem-trap-pool state. Runs on
    // a throttle (see ACTOR_SCAN_INTERVAL), not every frame: this is what
    // used to call floor.remoteActors.toArray() twice a frame and re-filter
    // every actor on the floor from scratch.
    function scanActors(floor:DistributedDungeonFloor, heroes:Int):Void {
        for (e in entries) { var entry:EnemyEntry = e; entry.seen = false; }
        // Tile-network membership can grow mid-floor (rooms/triggers unlocking
        // further tiles), so this is re-read on every scan, not cached once
        // per floor - just not on every single frame any more.
        var tileIds:Array<String> = [];
        var usages:Dynamic = Reflect.field(floor, "mTileNetworkComponents");
        if (usages != null) for (i in 0...Std.int(usages.length)) tileIds.push(Std.string(usages[i].tileId));
        floorTileIds = tileIds;
        var actors = floor.remoteActors.toArray();
        for (actor in actors) {
            if (!Std.isOfType(actor, NPCGameObject)) continue;
            var npc:NPCGameObject = cast actor;
            // These are the three encounter pools, not the approach-room lava
            // traps. Checked before HP/team/prop filtering: pools are
            // non-attackable zero-HP props that would otherwise be skipped.
            if (npc.gmNpc != null && npc.gmNpc.Constant == "JURASSIC_TRIBAL_BOSS_TRAP_LAVA_A")
                golemPools.set(npc.id, npc);
            if (npc.isDestroyed || npc.gmNpc == null || npc.isDead() || npc.hitPoints <= 0) continue;
            var breakable = npc.isProp && npc.gmNpc.IsAttackable;
            if (!breakable && (npc.team == heroes || npc.team == (DBGlobal.TEAM_ENVIRONMENT : Int)
                || npc.team == (DBGlobal.TEAM_3 : Int))) continue;
            if (npc.isProp && !breakable) continue;
            // Some map-specific "boss" NPCs only start qualifying once a
            // room/trigger tile activates mid-floor, so this is rechecked
            // every scan rather than cached once at entry creation.
            var isBoss = BossRules.qualifies(npc.gmNpc.Constant, floorMap, floorTileIds, npc.gmNpc.IsBoss);
            var entry:EnemyEntry = entries.get(npc.id);
            var wasBoss = entry != null && entry.boss;
            if (entry == null) {
                entry = new EnemyEntry(facade, loader, npc, isBoss);
                entries.set(npc.id, entry);
            } else {
                entry.setBoss(isBoss);
            }
            if (entry.boss && !wasBoss) {
                if (entry.panel != null) bossLayer.addChild(entry.panel);
                context.log("tracking boss " + npc.gmNpc.Constant + " (" + npc.gmNpc.Name + ")");
            }
            entry.seen = true;
        }
        for (p in golemPools) {
            var pool:NPCGameObject = p;
            // Absence alone never counts as completion.
            if (!pool.isDestroyed && !pool.triggerState && !hardenedPools.exists(pool.id)) {
                hardenedPools.set(pool.id, true);
                context.log("Golem lava pool hardened: " + pool.id);
            }
        }
        golemRemaining = 3;
        for (id in hardenedPools.keys()) golemRemaining--;
        var remove:Array<Int> = [];
        for (id in entries.keys()) if (!entries.get(id).seen) remove.push(id);
        for (id in remove) {
            var entry:EnemyEntry = entries.get(id);
            entry.dispose();
            entries.remove(id);
        }
    }

    // Normalize the generic UI layer to authored design coordinates. Layer 51
    // is a specially repositioned top-center HUD background. Only the view
    // size can actually change this, so skip the conversion otherwise.
    function syncBossLayerTransform():Void {
        if (bossLayer.parent == null) return;
        if (context.viewWidth == lastViewWidth && context.viewHeight == lastViewHeight) return;
        lastViewWidth = context.viewWidth;
        lastViewHeight = context.viewHeight;
        var zero = bossLayer.parent.globalToLocal(facade.scalingRoot.localToGlobal(new Point(0, 0)));
        var unit = bossLayer.parent.globalToLocal(facade.scalingRoot.localToGlobal(new Point(1, 1)));
        bossLayer.x = zero.x;
        bossLayer.y = zero.y;
        bossLayer.scaleX = unit.x - zero.x;
        bossLayer.scaleY = unit.y - zero.y;
    }

    function renderBosses(candidates:Array<EnemyEntry>, golemRemaining:Int):Void {
        candidates.sort(function(a:EnemyEntry, b:EnemyEntry):Int { return a.npc.id - b.npc.id; });
        var visible:Array<Int> = [];
        var priority = -1;
        var lastDamage:Float = facade.gameClock.gameTime - 1500;
        for (c in candidates) {
            var entry:EnemyEntry = c;
            if (entry.panel.isReady()) visible.push(entry.npc.id);
            if (entry.lastDamage > lastDamage && entry.panel.isReady()) {
                priority = entry.npc.id;
                lastDamage = entry.lastDamage;
            }
        }
        var selected = bossSlots.select(visible, priority);
        var width = Math.min(450, context.viewWidth * 0.3);
        var top:Float = 145;
        for (c in candidates) {
            var entry:EnemyEntry = c;
            var row = selected.indexOf(entry.npc.id);
            entry.selectPanel(row >= 0);
            if (row >= 0) {
                entry.panel.visible = true;
                entry.decorations.visible = false;
                if (entry.objectives) entry.panel.updateObjectives(golemRemaining, width);
                else entry.panel.updateHP(entry.hp, entry.maxHP, width);
                entry.panel.x = (context.viewWidth - width) / 2;
                entry.panel.y = top + row * 56;
                entry.syncTag(true);
            } else if (entry.panel != null) {
                // Not assigned a row this frame (overflow, or bumped by a
                // higher-priority boss) - make sure a stale panel from an
                // earlier frame's selection doesn't stay visible.
                entry.panel.visible = false;
            }
        }
        var bottom = top;
        for (id in selected) {
            var entry:EnemyEntry = entries.get(id);
            entry.panel.y = bottom;
            bottom += 56;
        }
        var extra = candidates.length - selected.length;
        if (extra > 0) {
            bossOverflow.setValue("+" + extra + (extra == 1 ? " boss" : " bosses"));
            bossOverflow.x = context.viewWidth / 2;
            bossOverflow.y = bottom - 2;
            bossOverflow.visible = true;
        }
    }

    function syncEffects(actorId:Int, effects:Map<Int, EffectIcon>, layer:Sprite, columns:Int, center:Float, down:Bool = false):Void {
        for (icon in effects) icon.seen = false;
        var groups:Map<Int, Dynamic> = new Map();
        for (record in buffs) {
            var object:DistributedBuffGameObject = cast record.object;
            if (object == null || object.isDestroyed || record.actor != actorId) continue;
            var gm:GMBuff = cast record.gm;
            var group:Dynamic = groups.get(record.type);
            if (group == null) {
                group = {gm: gm, count: 1};
                groups.set(record.type, group);
            } else {
                group.count++;
            }
        }
        var types:Array<Int> = [for (id in groups.keys()) id];
        types.sort(function(a:Int, b:Int):Int { return a - b; });
        var index = 0;
        for (type in types) {
            var group:Dynamic = groups.get(type);
            var icon = effects.get(type);
            if (icon == null) {
                icon = new EffectIcon(loader, cast group.gm);
                effects.set(type, icon);
                layer.addChild(icon);
            }
            icon.seen = true;
            icon.updateStacks(group.count);
            var row = Std.int(index / columns);
            var rowCount = Std.int(Math.min(columns, types.length - row * columns));
            icon.x = center - (rowCount * 38 - 8) / 2 + (index % columns) * 38;
            icon.y = (down ? row : -row) * 38;
            index++;
        }
        var remove:Array<Int> = [];
        for (type in effects.keys()) if (!effects.get(type).seen) remove.push(type);
        for (type in remove) {
            effects.get(type).dispose();
            effects.remove(type);
        }
    }

    function showing(object:DisplayObject):Bool {
        if (object.stage == null) return false;
        var current:DisplayObject = object;
        while (current != null) {
            if (!current.visible || current.alpha <= 0) return false;
            current = current.parent;
        }
        return true;
    }

    // Who is a tracked remote player. Runs on the same throttle as
    // scanActors (see ACTOR_SCAN_INTERVAL), not every frame: this is what
    // used to call floor.remoteHeroes.toArray() every single frame just to
    // find the same handful of players it found last frame.
    function scanPlayers(floor:DistributedDungeonFloor):Void {
        if (manaFailed) return;
        try {
            for (p in players) { var player:PlayerManaEntry = p; player.seen = false; }
            // Heroes and NPCs are held in separate collections by the floor.
            var heroes = floor.remoteHeroes;
            if (heroes == null) return;
            for (actor in heroes.toArray()) {
                if (!Std.isOfType(actor, HeroGameObject)) continue;
                var hero:HeroGameObject = cast actor;
                if (hero.isOwner || hero.isDestroyed || hero.playerID == 0) continue;
                // Defer artwork until another player actually needs it.
                if (manaArt == null) manaArt = new ManaBarArt(loader);
                var player:PlayerManaEntry = players.get(hero.id);
                if (player == null) {
                    player = new PlayerManaEntry(hero, manaArt, loader);
                    players.set(hero.id, player);
                    context.log("tracking remote player bars/effects: " + hero.id);
                    syncEffects(hero.id, player.effectStrip.effects, player.effectStrip.layer, 6, 0);
                }
                player.seen = true;
            }
            var remove:Array<Int> = [];
            for (id in players.keys()) if (!players.get(id).seen) remove.push(id);
            for (id in remove) {
                var player:PlayerManaEntry = players.get(id);
                player.dispose();
                players.remove(id);
            }
        } catch (error:Dynamic) {
            manaFailed = true;
            for (p in players) { var player:PlayerManaEntry = p; player.dispose(); }
            players.clear();
            context.log("player mana bars stopped: " + Std.string(error));
        }
    }

    // Per-frame refresh (position/bars/icons) for already-known players;
    // membership itself is handled by scanPlayers above.
    function updatePlayerMana(hidden:Bool):Void {
        if (manaFailed) return;
        try {
            for (id in players.keys()) {
                var player:PlayerManaEntry = players.get(id);
                // Rebuilding the icon strip (map + array + sort) is only
                // worth doing when a buff actually changed.
                if (effectsDirty) syncEffects(id, player.effectStrip.effects, player.effectStrip.layer, 6, 0);
                player.update(hidden);
            }
            effectsDirty = false;
        } catch (error:Dynamic) {
            manaFailed = true;
            for (p in players) { var player:PlayerManaEntry = p; player.dispose(); }
            players.clear();
            context.log("player mana bars stopped: " + Std.string(error));
        }
    }

    function clearEnemies():Void {
        for (entry in entries) entry.dispose();
        entries.clear();
        golemPools.clear();
        hardenedPools.clear();
        for (player in players) player.dispose();
        players.clear();
        manaFailed = false;
        bossSlots.clear();
        if (bossOverflow != null) bossOverflow.visible = false;
    }

    override public function dispose():Void {
        context.overlay.removeEventListener(Event.ENTER_FRAME, update);
        clearEnemies();
        buffs.clear();
        if (loader != null) loader.destroy();
        if (manaArt != null) manaArt.dispose();
        if (bossOverflow != null) bossOverflow.dispose();
        if (bossLayer != null && bossLayer.parent != null) bossLayer.parent.removeChild(bossLayer);
        facade = null;
    }
}
