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
    static class Device { 
        String ip; String mac; String displayName; int ports; String rawPorts; boolean isGateway; 
        Device(String ip, String mac, String displayName, int ports, String raw, boolean gw) { 
            this.ip = ip; this.mac = mac; this.displayName = displayName; this.ports = ports; this.rawPorts = raw; this.isGateway = gw; 
        } 
    }
    private final List<Device> devices = new ArrayList<>();
    private String gatewayIp = "";
    private int expandedPosition = -1;

    public void setGateway(String gw) { this.gatewayIp = gw; }
    public void addDevice(String ip) {
        for (Device d : devices) if (d.ip.equals(ip)) return;
        devices.add(new Device(ip, "Unknown", "Unknown", -1, "Scanning...", ip.equals(gatewayIp)));
        notifyItemInserted(devices.size() - 1);
    }
    public void updateDevice(String ip, int ports, String mac, String displayName, String raw) {
        for (int i = 0; i < devices.size(); i++) {
            if (devices.get(i).ip.equals(ip)) {
                devices.get(i).ports = ports; devices.get(i).mac = mac; 
                devices.get(i).displayName = displayName; devices.get(i).rawPorts = raw;
                notifyItemChanged(i); break;
            }
        }
    }
    public String getIpAt(int index) { return devices.get(index).ip; }
    public void clear() { devices.clear(); expandedPosition = -1; notifyDataSetChanged(); }
    
    @NonNull @Override public VH onCreateViewHolder(@NonNull ViewGroup p, int t) { 
        return new VH(LayoutInflater.from(p.getContext()).inflate(R.layout.item_device, p, false)); 
    }
    @Override public void onBindViewHolder(@NonNull VH h, int i) {
        Device d = devices.get(i);
        h.tvIp.setText(d.ip); h.tvPortCount.setText(d.ports == -1 ? "?" : String.valueOf(d.ports));
        
        if (d.isGateway) h.tvVendor.setText("Router / Gateway");
        else if (d.displayName != null && !d.displayName.equals("Unknown")) h.tvVendor.setText(d.displayName);
        else h.tvVendor.setText(d.mac.equals("Unknown") ? "Device" : d.mac);

        if (expandedPosition == i) {
            h.cardExpandable.setVisibility(View.VISIBLE);
            h.tvArrow.setText("▲");
            if (d.rawPorts == null || d.rawPorts.isEmpty() || d.rawPorts.equals("Scanning...")) {
                h.tvPortsList.setText("No open ports found.");
            } else {
                h.tvPortsList.setText(d.rawPorts);
            }
        } else {
            h.cardExpandable.setVisibility(View.GONE);
            h.tvArrow.setText("▼");
        }
        
        h.itemView.setOnClickListener(v -> {
            if (expandedPosition == i) {
                expandedPosition = -1; notifyItemChanged(i);
            } else {
                int prev = expandedPosition; expandedPosition = i; notifyItemChanged(i);
                if (prev != -1) notifyItemChanged(prev);
            }
        });
    }
    @Override public int getItemCount() { return devices.size(); }
    static class VH extends RecyclerView.ViewHolder {
        TextView tvIp, tvPortCount, tvVendor, tvArrow, tvPortsList; View cardExpandable;
        VH(@NonNull View v) { 
            super(v); tvIp = v.findViewById(R.id.tvIp); tvPortCount = v.findViewById(R.id.tvPortCount); 
            tvVendor = v.findViewById(R.id.tvVendor); tvArrow = v.findViewById(R.id.tvArrow); 
            tvPortsList = v.findViewById(R.id.tvPortsList); cardExpandable = v.findViewById(R.id.cardExpandable);
        }
    }
}
