package com.xk.netprobe;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.TextView;
import androidx.annotation.NonNull;
import androidx.recyclerview.widget.RecyclerView;
import java.util.ArrayList;
import java.util.List;
public class DeviceAdapter extends RecyclerView.Adapter<DeviceAdapter.VH> {
    static class Device { String ip; int ports; Device(String ip, int ports) { this.ip = ip; this.ports = ports; } }
    private final List<Device> devices = new ArrayList<>();
    public void addDevice(String ip) {
        for (Device d : devices) if (d.ip.equals(ip)) return;
        devices.add(new Device(ip, -1)); notifyItemInserted(devices.size() - 1);
    }
    public void updatePorts(String ip, int ports) {
        for (int i = 0; i < devices.size(); i++) {
            if (devices.get(i).ip.equals(ip)) { devices.get(i).ports = ports; notifyItemChanged(i); break; }
        }
    }
    public String getIpAt(int index) { return devices.get(index).ip; }
    @NonNull @Override public VH onCreateViewHolder(@NonNull ViewGroup p, int t) { return new VH(LayoutInflater.from(p.getContext()).inflate(R.layout.item_device, p, false)); }
    @Override public void onBindViewHolder(@NonNull VH h, int i) {
        Device d = devices.get(i);
        h.tvIp.setText(d.ip);
        h.tvPortCount.setText(d.ports == -1 ? "?" : String.valueOf(d.ports));
        h.tvVendor.setText("Device");
    }
    @Override public int getItemCount() { return devices.size(); }
    static class VH extends RecyclerView.ViewHolder {
        TextView tvIp, tvPortCount, tvVendor;
        VH(@NonNull View v) { super(v); tvIp = v.findViewById(R.id.tvIp); tvPortCount = v.findViewById(R.id.tvPortCount); tvVendor = v.findViewById(R.id.tvVendor); }
    }
}
