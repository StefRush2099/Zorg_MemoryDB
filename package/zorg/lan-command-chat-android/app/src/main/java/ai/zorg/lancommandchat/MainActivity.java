package ai.zorg.lancommandchat;

import android.annotation.SuppressLint;
import android.app.Activity;
import android.app.AlertDialog;
import android.content.SharedPreferences;
import android.graphics.Color;
import android.graphics.Typeface;
import android.net.Uri;
import android.os.Bundle;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.view.Window;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.ArrayAdapter;
import android.widget.Button;
import android.widget.EditText;
import android.widget.LinearLayout;
import android.widget.ProgressBar;
import android.widget.ScrollView;
import android.widget.Spinner;
import android.widget.Switch;
import android.widget.TextView;
import android.widget.Toast;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URI;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

public class MainActivity extends Activity {
    private static final String PREFS = "lan_command_chat";
    private static final String KEY_PROFILES = "profiles";
    private static final String KEY_ACTIVE_ID = "active_profile_id";
    private static final int BG = Color.rgb(10, 12, 16);
    private static final int PANEL = Color.rgb(18, 22, 29);
    private static final int TEXT = Color.WHITE;
    private static final int MUTED = Color.rgb(165, 175, 190);

    private final List<Profile> profiles = new ArrayList<>();
    private final ExecutorService network = Executors.newFixedThreadPool(2);
    private SharedPreferences prefs;
    private LinearLayout messages;
    private ScrollView messageScroll;
    private EditText composer;
    private TextView connectionStatus;
    private TextView contextStatus;
    private TextView queryGauge;
    private TextView cacheGauge;
    private TextView writesGauge;
    private TextView sizeGauge;
    private ProgressBar progress;
    private Profile active;
    private boolean sending;

    @Override public void onCreate(Bundle state) {
        super.onCreate(state);
        requestWindowFeature(Window.FEATURE_NO_TITLE);
        prefs = getSharedPreferences(PREFS, MODE_PRIVATE);
        loadProfiles();
        active = getActiveProfile();
        buildUi();
        loadHistory();
        refreshStatus();
        refreshDbGauges();
    }

    private void buildUi() {
        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setBackgroundColor(BG);

        LinearLayout header = new LinearLayout(this);
        header.setOrientation(LinearLayout.VERTICAL);
        header.setPadding(18, 16, 18, 10);
        header.setBackgroundColor(PANEL);
        LinearLayout titleRow = row();
        TextView title = label("LAN Command Chat", 20, TEXT);
        title.setTypeface(Typeface.DEFAULT, Typeface.BOLD);
        titleRow.addView(title, weight(1));
        Button settings = button("Profiles");
        settings.setOnClickListener(v -> showProfileDialog(active));
        titleRow.addView(settings);
        header.addView(titleRow);
        connectionStatus = label("Connecting…", 12, MUTED);
        header.addView(connectionStatus);
        contextStatus = label("Context: —", 12, MUTED);
        header.addView(contextStatus);
        LinearLayout gauges = row();
        queryGauge = gauge("Queries/sec\n—");
        cacheGauge = gauge("Cache hit\n—");
        writesGauge = gauge("Writes/sec\n—");
        sizeGauge = gauge("DB size\n—");
        gauges.addView(queryGauge, weight(1));
        gauges.addView(cacheGauge, weight(1));
        gauges.addView(writesGauge, weight(1));
        gauges.addView(sizeGauge, weight(1));
        header.addView(gauges);
        progress = new ProgressBar(this, null, android.R.attr.progressBarStyleHorizontal);
        progress.setMax(100);
        progress.setVisibility(View.GONE);
        header.addView(progress, new LinearLayout.LayoutParams(-1, 8));
        root.addView(header);

        messageScroll = new ScrollView(this);
        messages = new LinearLayout(this);
        messages.setOrientation(LinearLayout.VERTICAL);
        messages.setPadding(14, 12, 14, 12);
        messageScroll.addView(messages, new ViewGroup.LayoutParams(-1, -2));
        root.addView(messageScroll, new LinearLayout.LayoutParams(-1, 0, 1));

        LinearLayout tools = row();
        tools.setPadding(12, 5, 12, 5);
        Button brain = button("Memory 3D");
        brain.setOnClickListener(v -> showMemoryBrain());
        Button reload = button("Refresh");
        reload.setOnClickListener(v -> { loadHistory(); refreshStatus(); refreshDbGauges(); });
        tools.addView(brain);
        tools.addView(reload);
        root.addView(tools);

        LinearLayout input = row();
        input.setPadding(12, 8, 12, 12);
        composer = new EditText(this);
        composer.setHint("Message Zorg…");
        composer.setTextColor(TEXT);
        composer.setHintTextColor(MUTED);
        composer.setGravity(Gravity.TOP | Gravity.START);
        composer.setMinLines(1);
        composer.setMaxLines(5);
        input.addView(composer, weight(1));
        Button send = button("Send");
        send.setOnClickListener(v -> sendMessage());
        input.addView(send);
        root.addView(input);
        setContentView(root);
    }

    private void sendMessage() {
        final String text = composer.getText().toString().trim();
        if (text.isEmpty() || sending) return;
        addMessage("You", text, true);
        composer.setText("");
        sending = true;
        progress.setVisibility(View.VISIBLE);
        connectionStatus.setText("Sending…");
        network.execute(() -> {
            try {
                JSONObject body = new JSONObject().put("message", text);
                JSONObject response = request(active.route(), "/api/chat/send", "POST", body.toString());
                String runId = response.optString("runId", "started");
                runOnUiThread(() -> {
                    addMessage("Zorg", "Request accepted (" + runId + "). Waiting for response…", false);
                    connectionStatus.setText("Connected · request accepted");
                });
                waitForResponse(text);
            } catch (Exception error) {
                runOnUiThread(() -> addMessage("Error", error.getMessage() == null ? "Request failed" : error.getMessage(), false));
            } finally {
                runOnUiThread(() -> { sending = false; progress.setVisibility(View.GONE); });
            }
        });
    }

    private void waitForResponse(String sentText) {
        for (int attempt = 0; attempt < 8; attempt++) {
            try {
                Thread.sleep(1200);
                JSONArray list = request(active.route(), "/api/chat/history", "GET", null).optJSONArray("messages");
                if (list == null) continue;
                String latest = latestAssistant(list, sentText);
                if (!latest.isEmpty()) {
                    final String answer = latest;
                    runOnUiThread(() -> { replaceLastPending(answer); connectionStatus.setText("Connected"); });
                    return;
                }
            } catch (Exception ignored) { }
        }
        runOnUiThread(() -> replaceLastPending("The request was sent. Refresh to load the agent response."));
    }

    private String latestAssistant(JSONArray list, String sentText) throws JSONException {
        for (int i = list.length() - 1; i >= 0; i--) {
            JSONObject item = list.optJSONObject(i);
            if (item == null) continue;
            String role = item.optString("role", item.optString("sender", ""));
            String text = item.optString("text", item.optString("content", "")).trim();
            if (("assistant".equalsIgnoreCase(role) || "agent".equalsIgnoreCase(role)) && !text.isEmpty()) return text;
        }
        return "";
    }

    private void loadHistory() {
        network.execute(() -> {
            try {
                JSONArray list = request(active.route(), "/api/chat/history", "GET", null).optJSONArray("messages");
                if (list == null) return;
                List<String[]> loaded = new ArrayList<>();
                for (int i = 0; i < list.length(); i++) {
                    JSONObject item = list.optJSONObject(i);
                    if (item == null) continue;
                    String role = item.optString("role", item.optString("sender", "assistant"));
                    String text = item.optString("text", item.optString("content", "")).trim();
                    if (!text.isEmpty()) loaded.add(new String[]{role, text});
                }
                runOnUiThread(() -> { messages.removeAllViews(); for (String[] item : loaded) addMessage(item[0], item[1], "user".equalsIgnoreCase(item[0])); scrollBottom(); });
            } catch (Exception error) { runOnUiThread(() -> connectionStatus.setText("Offline · " + error.getMessage())); }
        });
    }

    private void refreshStatus() {
        network.execute(() -> {
            try {
                JSONObject status = request(active.route(), "/api/chat/status", "GET", null);
                int percent = status.has("tokensPercent") ? status.optInt("tokensPercent", -1) : -1;
                int limit = status.optInt("tokensLimit", 0);
                runOnUiThread(() -> { connectionStatus.setText("Connected · " + active.name); contextStatus.setText(percent >= 0 ? "Context window: " + percent + "%" + (limit > 0 ? " / " + limit + " tokens" : "") : "Context window: available"); });
            } catch (Exception error) { runOnUiThread(() -> connectionStatus.setText("Offline · trying configured routes")); }
        });
    }

    private void refreshDbGauges() {
        network.execute(() -> {
            try {
                JSONObject status = request(active.route(), "/api/db/status", "GET", null);
                JSONObject metrics = status.optJSONObject("metrics");
                if (metrics == null) throw new IllegalStateException("Gauge data unavailable");
                String qps = metric(metrics, "queriesPerSecond", "qps");
                String cache = metric(metrics, "cacheHitRatio", "%");
                String writes = metric(metrics, "writesPerSecond", "writes/s");
                String size = metric(metrics, "dbSize", "% full");
                runOnUiThread(() -> { queryGauge.setText("Queries/sec\n" + qps); cacheGauge.setText("Cache hit\n" + cache); writesGauge.setText("Writes/sec\n" + writes); sizeGauge.setText("DB size\n" + size); });
            } catch (Exception ignored) { }
        });
    }

    private String metric(JSONObject metrics, String key, String unit) {
        JSONObject value = metrics.optJSONObject(key);
        if (value == null) return "—";
        return value.optString("value", "—") + " " + value.optString("unit", unit);
    }

    private JSONObject request(String ignoredBase, String path, String method, String body) throws Exception {
        Exception last = null;
        for (String base : active.routes()) {
            try { return requestAt(base, path, method, body); }
            catch (Exception error) { last = error; }
        }
        throw last == null ? new IllegalStateException("No connection route configured") : last;
    }

    private JSONObject requestAt(String base, String path, String method, String body) throws Exception {
        HttpURLConnection connection = (HttpURLConnection) new URL(join(base, path)).openConnection();
        connection.setRequestMethod(method);
        connection.setConnectTimeout(5000);
        connection.setReadTimeout(30000);
        connection.setRequestProperty("Accept", "application/json");
        if (body != null) {
            connection.setDoOutput(true);
            connection.setRequestProperty("Content-Type", "application/json");
            try (OutputStream output = connection.getOutputStream()) { output.write(body.getBytes(StandardCharsets.UTF_8)); }
        }
        int code = connection.getResponseCode();
        BufferedReader reader = new BufferedReader(new InputStreamReader(code >= 400 ? connection.getErrorStream() : connection.getInputStream(), StandardCharsets.UTF_8));
        StringBuilder result = new StringBuilder(); String line;
        while ((line = reader.readLine()) != null) result.append(line);
        if (code >= 400) throw new IllegalStateException("HTTP " + code);
        return result.length() == 0 ? new JSONObject() : new JSONObject(result.toString());
    }

    private void showMemoryBrain() {
        WebView brain = new WebView(this);
        brain.setWebViewClient(new WebViewClient());
        WebSettings settings = brain.getSettings(); settings.setJavaScriptEnabled(true); settings.setDomStorageEnabled(true);
        brain.loadUrl(join(active.route(), "/memory-3d-proxy/"));
        new AlertDialog.Builder(this).setTitle("Zorg Memory Brain 3D").setView(brain).setPositiveButton("Close", null).show();
    }

    private void addMessage(String role, String text, boolean user) {
        TextView item = label(role + "\n" + text, 15, TEXT);
        item.setPadding(16, 12, 16, 12); item.setGravity(Gravity.START); item.setBackgroundColor(user ? Color.rgb(30, 55, 78) : Color.rgb(29, 34, 43));
        LinearLayout.LayoutParams params = new LinearLayout.LayoutParams(-1, -2); params.setMargins(0, 5, 0, 5); messages.addView(item, params); scrollBottom();
    }

    private void replaceLastPending(String text) {
        if (messages.getChildCount() > 0) messages.removeViewAt(messages.getChildCount() - 1);
        addMessage("Zorg", text, false);
    }

    private void scrollBottom() { messageScroll.post(() -> messageScroll.fullScroll(View.FOCUS_DOWN)); }

    private void showProfileDialog(Profile original) {
        final boolean isNew = original == null;
        LinearLayout form = new LinearLayout(this); form.setOrientation(LinearLayout.VERTICAL); form.setPadding(30, 8, 30, 0);
        EditText name = field("Profile name", isNew ? "" : original.name); form.addView(name);
        EditText publicUrl = field("Internet URL (https://…/chat)", isNew ? "" : original.publicUrl); form.addView(publicUrl);
        EditText localHost = field("Local host/IP (optional)", isNew ? "" : original.localHost); form.addView(localHost);
        EditText localPort = field("Local port (optional)", isNew ? "" : original.localPort); form.addView(localPort);
        new AlertDialog.Builder(this).setTitle(isNew ? "Add connection" : "Edit connection").setView(form).setNegativeButton("Cancel", null).setPositiveButton("Save", (dialog, which) -> {
            String n = name.getText().toString().trim(), u = normalize(publicUrl.getText().toString()), h = localHost.getText().toString().trim(), p = localPort.getText().toString().trim();
            if (n.isEmpty() || u.isEmpty()) { Toast.makeText(this, "Name and internet URL are required", Toast.LENGTH_SHORT).show(); return; }
            Profile updated = new Profile(isNew ? UUID.randomUUID().toString() : original.id, n, u, h, p);
            if (isNew) profiles.add(updated); else profiles.set(profiles.indexOf(original), updated); active = updated; saveProfiles(); loadHistory(); refreshStatus();
        }).show();
    }

    private EditText field(String hint, String value) { EditText field = new EditText(this); field.setHint(hint); field.setText(value); field.setSingleLine(true); field.setTextColor(TEXT); field.setHintTextColor(MUTED); return field; }
    private String normalize(String value) { if (value.isEmpty()) return ""; if (!value.startsWith("http://") && !value.startsWith("https://")) value = "https://" + value; return value.replaceAll("/+$", "") + (value.endsWith("/chat") ? "" : "/chat"); }
    private String join(String base, String path) { return base.replaceAll("/+$", "") + "/" + path.replaceAll("^/+", ""); }
    private LinearLayout row() { LinearLayout row = new LinearLayout(this); row.setOrientation(LinearLayout.HORIZONTAL); row.setGravity(Gravity.CENTER_VERTICAL); return row; }
    private LinearLayout.LayoutParams weight(float value) { return new LinearLayout.LayoutParams(0, -2, value); }
    private TextView label(String text, int size, int color) { TextView view = new TextView(this); view.setText(text); view.setTextSize(size); view.setTextColor(color); return view; }
    private TextView gauge(String text) { TextView view = label(text, 11, TEXT); view.setGravity(Gravity.CENTER); view.setPadding(4, 8, 4, 8); return view; }
    private Button button(String text) { Button button = new Button(this); button.setText(text); return button; }

    private void loadProfiles() {
        String raw = prefs.getString(KEY_PROFILES, "[]"); profiles.clear();
        try { JSONArray list = new JSONArray(raw); for (int i = 0; i < list.length(); i++) { JSONObject item = list.getJSONObject(i); profiles.add(new Profile(item.optString("id"), item.optString("name"), item.optString("url"), item.optString("localHost"), item.optString("localPort"))); } } catch (JSONException ignored) { }
        if (profiles.isEmpty()) profiles.add(new Profile(UUID.randomUUID().toString(), BuildConfig.DEFAULT_PROFILE_NAME, BuildConfig.DEFAULT_PROFILE_URL, "", ""));
    }
    private void saveProfiles() { JSONArray list = new JSONArray(); try { for (Profile p : profiles) list.put(new JSONObject().put("id", p.id).put("name", p.name).put("url", p.publicUrl).put("localHost", p.localHost).put("localPort", p.localPort)); } catch (JSONException ignored) { } prefs.edit().putString(KEY_PROFILES, list.toString()).putString(KEY_ACTIVE_ID, active.id).apply(); }
    private Profile getActiveProfile() { String id = prefs.getString(KEY_ACTIVE_ID, ""); for (Profile p : profiles) if (p.id.equals(id)) return p; return profiles.get(0); }

    @Override public void onDestroy() { network.shutdownNow(); super.onDestroy(); }

    private static final class Profile {
        final String id, name, publicUrl, localHost, localPort;
        Profile(String id, String name, String publicUrl, String localHost, String localPort) { this.id = id; this.name = name; this.publicUrl = publicUrl; this.localHost = localHost; this.localPort = localPort; }
        String route() { return routes().get(0); }
        List<String> routes() {
            List<String> routes = new ArrayList<>();
            if (!localHost.isEmpty()) routes.add("http://" + localHost + (localPort.isEmpty() ? "" : ":" + localPort));
            Uri parsed = Uri.parse(publicUrl);
            String scheme = parsed.getScheme() == null ? "https" : parsed.getScheme();
            String authority = parsed.getEncodedAuthority();
            String remote = scheme + "://" + authority;
            if (!routes.contains(remote)) routes.add(remote);
            return routes;
        }
    }
}
