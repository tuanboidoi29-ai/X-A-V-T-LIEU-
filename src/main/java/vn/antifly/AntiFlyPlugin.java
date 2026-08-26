package vn.antifly;

import org.bukkit.ChatColor;
import org.bukkit.GameMode;
import org.bukkit.Location;
import org.bukkit.entity.Player;
import org.bukkit.event.EventHandler;
import org.bukkit.event.Listener;
import org.bukkit.event.player.PlayerMoveEvent;
import org.bukkit.plugin.java.JavaPlugin;
import org.bukkit.potion.PotionEffectType;

import java.util.HashMap;
import java.util.Map;
import java.util.UUID;

public final class AntiFlyPlugin extends JavaPlugin implements Listener {
    private final Map<UUID, ViolationState> violations = new HashMap<>();
    private int violationThreshold;
    private long violationDecayMillis;
    private double maxUpwardDistance;
    private String alertMessage;

    @Override
    public void onEnable() {
        saveDefaultConfig();
        loadSettings();
        getServer().getPluginManager().registerEvents(this, this);
        getLogger().info("AntiFly da duoc bat.");
    }

    @Override
    public void onDisable() {
        violations.clear();
    }

    private void loadSettings() {
        violationThreshold = Math.max(1, getConfig().getInt("checks.violations-before-alert", 3));
        violationDecayMillis = Math.max(1, getConfig().getLong("checks.violation-decay-seconds", 5)) * 1000L;
        maxUpwardDistance = Math.max(0.1, getConfig().getDouble("checks.max-upward-distance", 0.65));
        alertMessage = getConfig().getString("messages.alert", "&c[AntiFly] &f%player% &7co dau hieu bay bat thuong.");
    }

    @EventHandler(ignoreCancelled = true)
    public void onPlayerMove(PlayerMoveEvent event) {
        Player player = event.getPlayer();
        if (!shouldCheck(player) || event.getTo() == null) {
            return;
        }

        Location from = event.getFrom();
        Location to = event.getTo();
        double upwardDistance = to.getY() - from.getY();
        if (upwardDistance <= maxUpwardDistance || !isSuspiciousPosition(player, to)) {
            decayViolation(player.getUniqueId());
            return;
        }

        ViolationState state = violations.computeIfAbsent(player.getUniqueId(), ignored -> new ViolationState());
        long now = System.currentTimeMillis();
        if (now - state.lastViolationAt > violationDecayMillis) {
            state.count = 0;
        }
        state.count++;
        state.lastViolationAt = now;

        if (state.count >= violationThreshold) {
            sendAlert(player, state.count);
            state.count = 0;
        }
    }

    private boolean shouldCheck(Player player) {
        GameMode gameMode = player.getGameMode();
        return gameMode != GameMode.CREATIVE
                && gameMode != GameMode.SPECTATOR
                && !player.getAllowFlight()
                && !player.isInsideVehicle()
                && !player.isGliding()
                && !player.isFlying();
    }

    private boolean isSuspiciousPosition(Player player, Location location) {
        return !player.isOnGround()
                && !player.isSwimming()
                && !player.isClimbing()
                && !player.hasPotionEffect(PotionEffectType.LEVITATION)
                && location.getBlock().getType().isAir();
    }

    private void decayViolation(UUID playerId) {
        ViolationState state = violations.get(playerId);
        if (state != null && System.currentTimeMillis() - state.lastViolationAt > violationDecayMillis) {
            violations.remove(playerId);
        }
    }

    private void sendAlert(Player player, int count) {
        String message = alertMessage
                .replace("%player%", player.getName())
                .replace("%violations%", String.valueOf(count))
                .replace("%threshold%", String.valueOf(violationThreshold));
        String coloredMessage = ChatColor.translateAlternateColorCodes('&', message);
        getLogger().warning(ChatColor.stripColor(coloredMessage));
        getServer().getOnlinePlayers().stream()
                .filter(viewer -> viewer.hasPermission("antifly.alert"))
                .forEach(viewer -> viewer.sendMessage(coloredMessage));
    }

    private static final class ViolationState {
        private int count;
        private long lastViolationAt;
    }
}