package com.xk.netprobe;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

public class NmapOutputParser {

    public static class Port {
        public String protocol;
        public int portId;
        public String state;
        public String service;
        public String version;
    }

    public static class Host {
        public String ip;
        public String hostname;
        public String status;
        public final List<Port> ports = new ArrayList<>();
    }

    public static class Result {
        public final List<Host> hosts = new ArrayList<>();
    }

    private final StringBuilder raw = new StringBuilder();
    private final Result result = new Result();
    private Host currentHost;
    private boolean xmlMode = false;
    private boolean gnmapMode = false;

    private static final Pattern TEXT_PORT =
            Pattern.compile("^(\\d+)/(tcp|udp)\\s+(\\S+)\\s+(\\S+)\\s*(.*)$");
    private static final Pattern TEXT_HOST =
            Pattern.compile("^Nmap scan report for (.+?)(?:\\s+\\(([^)]+)\\))?$");
    private static final Pattern GNMAP_HOST =
            Pattern.compile("^Host:\\s+(\\S+)\\s+\\(([^)]*)\\)\\s+Status:\\s+(\\S+)");
    private static final Pattern GNMAP_PORTS =
            Pattern.compile("^Host:\\s+(\\S+).*Ports:\\s+([^\\t]+)");
    private static final Pattern XML_HOST =
            Pattern.compile("<host\\b[^>]*>.*?</host>", Pattern.DOTALL);
    private static final Pattern XML_ADDR =
            Pattern.compile("<address addr=\"([^\"]+)\"[^>]*addrtype=\"ipv4\"");
    private static final Pattern XML_STATUS =
            Pattern.compile("<status state=\"([^\"]+)\"");
    private static final Pattern XML_PORT =
            Pattern.compile("<port protocol=\"([^\"]+)\" portid=\"(\\d+)\">(.*?)</port>", Pattern.DOTALL);
    private static final Pattern XML_PORT_STATE =
            Pattern.compile("<state state=\"([^\"]+)\"");
    private static final Pattern XML_SERVICE =
            Pattern.compile("<service name=\"([^\"]*)\"(?:\\s+product=\"([^\"]*)\")?(?:\\s+version=\"([^\"]*)\")?");

    public void feed(String line) {
        if (line == null) return;
        if (!xmlMode && line.startsWith("<?xml")) xmlMode = true;
        if (!xmlMode && !gnmapMode
                && line.startsWith("Host: ") && line.contains("Status:")) {
            gnmapMode = true;
        }
        raw.append(line).append('\n');
        if (xmlMode) return;
        if (gnmapMode) { parseGnmapLine(line); return; }
        parseTextLine(line);
    }

    public Result finish() {
        if (xmlMode) parseXml(raw.toString());
        return result;
    }

    private void parseTextLine(String line) {
        Matcher h = TEXT_HOST.matcher(line);
        if (h.find()) {
            String name = h.group(1).trim();
            String ip = h.group(2);
            currentHost = new Host();
            if (ip != null) { currentHost.ip = ip; currentHost.hostname = name; }
            else { currentHost.ip = name; }
            currentHost.status = "up";
            result.hosts.add(currentHost);
            return;
        }
        Matcher p = TEXT_PORT.matcher(line);
        if (p.find() && currentHost != null) {
            Port port = new Port();
            try { port.portId = Integer.parseInt(p.group(1)); } catch (Exception e) { return; }
            port.protocol = p.group(2);
            port.state = p.group(3);
            port.service = p.group(4);
            port.version = p.group(5).trim();
            currentHost.ports.add(port);
        }
    }

    private void parseGnmapLine(String line) {
        Matcher h = GNMAP_HOST.matcher(line);
        if (h.find()) {
            String ip = h.group(1);
            String hostname = h.group(2);
            String status = h.group(3);
            Host existing = findHost(ip);
            if (existing == null) {
                Host host = new Host();
                host.ip = ip;
                if (!hostname.isEmpty()) host.hostname = hostname;
                host.status = status.toLowerCase();
                result.hosts.add(host);
            } else {
                existing.status = status.toLowerCase();
            }
            return;
        }
        Matcher pp = GNMAP_PORTS.matcher(line);
        if (pp.find()) {
            String ip = pp.group(1);
            String ports = pp.group(2);
            Host host = findHost(ip);
            if (host == null) return;
            for (String entry : ports.split(",\\s*")) {
                String[] f = entry.split("/", -1);
                if (f.length < 5) continue;
                try {
                    Port port = new Port();
                    port.portId = Integer.parseInt(f[0]);
                    port.state = f[1];
                    port.protocol = f[2];
                    port.service = f[4].isEmpty() ? f[3] : f[4];
                    port.version = f.length > 7 ? f[7] : "";
                    host.ports.add(port);
                } catch (Exception ignored) {}
            }
        }
    }

    private void parseXml(String xml) {
        Matcher m = XML_HOST.matcher(xml);
        while (m.find()) {
            String block = m.group();
            Host host = new Host();
            Matcher a = XML_ADDR.matcher(block);
            if (a.find()) host.ip = a.group(1);
            Matcher st = XML_STATUS.matcher(block);
            if (st.find()) host.status = st.group(1);
            Matcher pm = XML_PORT.matcher(block);
            while (pm.find()) {
                Port port = new Port();
                port.protocol = pm.group(1);
                try { port.portId = Integer.parseInt(pm.group(2)); } catch (Exception e) { continue; }
                String body = pm.group(3);
                Matcher sm = XML_PORT_STATE.matcher(body);
                if (sm.find()) port.state = sm.group(1);
                Matcher svm = XML_SERVICE.matcher(body);
                if (svm.find()) {
                    port.service = svm.group(1);
                    StringBuilder v = new StringBuilder();
                    if (svm.group(2) != null) v.append(svm.group(2));
                    if (svm.group(3) != null) {
                        if (v.length() > 0) v.append(' ');
                        v.append(svm.group(3));
                    }
                    port.version = v.toString();
                }
                host.ports.add(port);
            }
            if (host.ip != null) result.hosts.add(host);
        }
    }

    private Host findHost(String ip) {
        for (Host h : result.hosts) if (ip.equals(h.ip)) return h;
        return null;
    }

    public static String summary(Result r) {
        int hostsUp = 0;
        int openPorts = 0;
        Map<String, Integer> services = new LinkedHashMap<>();
        for (Host h : r.hosts) {
            if ("up".equalsIgnoreCase(h.status)) hostsUp++;
            for (Port p : h.ports) {
                if ("open".equalsIgnoreCase(p.state)) {
                    openPorts++;
                    if (p.service != null && !p.service.isEmpty()) {
                        services.merge(p.service, 1, Integer::sum);
                    }
                }
            }
        }
        StringBuilder sb = new StringBuilder();
        sb.append("[*] === SUMMARY ===");
        sb.append("\n[*] Hosts up   : ").append(hostsUp);
        sb.append("\n[*] Open ports : ").append(openPorts);
        if (!services.isEmpty()) {
            sb.append("\n[*] Services   : ");
            boolean first = true;
            for (Map.Entry<String, Integer> e : services.entrySet()) {
                if (!first) sb.append(", ");
                sb.append(e.getKey()).append('(').append(e.getValue()).append(')');
                first = false;
            }
        }
        return sb.toString();
    }
}
