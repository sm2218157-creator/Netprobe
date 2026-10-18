package com.xk.netprobe;
import android.content.Intent;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.TextView;
import androidx.annotation.NonNull;
import androidx.recyclerview.widget.RecyclerView;
import java.util.ArrayList;
import java.util.List;
public class DeviceAdapter extends RecyclerView.Adapter<DeviceAdapter.VH> {
    static class Device { String ip; String mac; int ports; String rawPorts; boolean isGateway; 
        Device(String ip, String mac, int ports, String raw, boolean gw) { this.ip = ip; this.mac = mac; this.ports = ports; this.rawPorts = raw; this.isGateway = gw; } }
    private final List<Device> devices = new ArrayList<>();
    private String gatewayIp = "";
    
    public void setGateway(String gw) { this.gatewayIp = gw; }
    
    public void addDevice(String ip) {
        for (Device d : devices) if (d.ip.equals(ip)) return;
        devices.add(new Device(ip, "Unknown", -1, "", ip.equals(gatewayIp)));
        notifyItemInserted(devices.size() - 1);
    }
    public void updateDevice(String ip, int ports, String mac, String raw) {
        for (int i = 0; i < devices.size(); i++) {
            if (devices.get(i).ip.equals(ip)) {
                devices.get(i).ports = ports; devices.get(i).mac = mac; devices.get(i).rawPorts = raw;
                notifyItemChanged(i); break;
            }
        }
    }
    public String getIpAt(int index) { return devices.get(index).ip; }
    public void clear() { devices.clear(); notifyDataSetChanged(); }
    @NonNull @Override public VH onCreateViewHolder(@NonNull ViewGroup p, int t) { return new VH(LayoutInflater.from(p.getContext()).inflate(R.layout.item_device, p, false)); }
    @Override public void onBindViewHolder(@NonNull VH h, int i) {
        Device d = devices.get(i);
        h.tvIp.setText(d.ip); h.tvPortCount.setText(d.ports == -1 ? "?" : String.valueOf(d.ports));
        if (d.isGateway) h.tvVendor.setText("Router / Gateway");
        else h.tvVendor.setText(d.mac.equals("Unknown") ? "Device" : d.mac);
        
        h.itemView.setOnClickListener(v -> {
            Intent intent = new Intent(v.getContext(), DeviceDetailsActivity.class);
            intent.putExtra("ip", d.ip); intent.putExtra("mac", d.mac); intent.putExtra("rawPorts", d.rawPorts);
            v.getContext().startActivity(intent);
        });
    }
    @Override public int getItemCount() { return devices.size(); }
    static class VH extends RecyclerView.ViewHolder {
        TextView tvIp, tvPortCount, tvVendor;
        VH(@NonNull View v) { super(v); tvIp = v.findViewById(R.id.tvIp); tvPortCount = v.findViewById(R.id.tvPortCount); tvVendor = v.findViewById(R.id.tvVendor); }
    }
}
