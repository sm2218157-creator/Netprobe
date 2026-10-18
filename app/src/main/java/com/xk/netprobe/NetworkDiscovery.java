package com.xk.netprobe;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
public class NetworkDiscovery {
    public interface Callback { void onDeviceFound(String ip); void onFinished(int total); }
    public static void scan(String subnet, Callback callback) {
        if (subnet == null || !subnet.contains(".")) { callback.onFinished(0); return; }
        ExecutorService executor = Executors.newFixedThreadPool(20);
        String base = subnet.substring(0, subnet.lastIndexOf('.'));
        final int[] count = {0};
        for (int i = 1; i <= 254; i++) {
            final String ip = base + "." + i;
            executor.execute(() -> {
                try { if (java.net.InetAddress.getByName(ip).isReachable(800)) { synchronized (count) { count[0]++; } callback.onDeviceFound(ip); } } catch (Exception ignored) {}
            });
        }
        executor.shutdown();
        new Thread(() -> { while (!executor.isTerminated()) { try { Thread.sleep(100); } catch (Exception ignored) {} } callback.onFinished(count[0]); }).start();
    }
}
