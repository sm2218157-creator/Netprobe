package com.xk.netprobe;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.TextView;
import androidx.annotation.NonNull;
import androidx.recyclerview.widget.RecyclerView;
import java.util.ArrayList;
import java.util.List;
public class PortAdapter extends RecyclerView.Adapter<PortAdapter.VH> {
    private final List<String[]> ports = new ArrayList<>();
    public void setData(String rawData) {
        ports.clear();
        if (rawData != null) {
            for (String line : rawData.split("\n")) {
                String trimmed = line.trim();
                if (trimmed.isEmpty()) continue;
                if (trimmed.contains("/tcp") && trimmed.contains("open")) { // صيغة nmap
                    String[] parts = trimmed.split("\\s+");
                    if (parts.length >= 3) {
                        String port = parts[0].split("/")[0];
                        String service = parts.length >= 4 ? parts[2] + " " + parts[3] : parts[2];
                        ports.add(new String[]{port, service});
                    }
                } else if (trimmed.contains("(") && trimmed.contains(")")) { // صيغة الماسح المدمج (جافا)
                    String[] parts = trimmed.split("\\(");
                    if (parts.length >= 2) {
                        String port = parts[0].trim();
                        String service = parts[1].replace(")", "").trim();
                        ports.add(new String[]{port, service});
                    }
                }
            }
        }
        notifyDataSetChanged();
    }
    @NonNull @Override public VH onCreateViewHolder(@NonNull ViewGroup p, int t) { return new VH(LayoutInflater.from(p.getContext()).inflate(R.layout.item_port, p, false)); }
    @Override public void onBindViewHolder(@NonNull VH h, int i) { h.tvNumber.setText(ports.get(i)[0]); h.tvService.setText(ports.get(i)[1]); }
    @Override public int getItemCount() { return ports.size(); }
    static class VH extends RecyclerView.ViewHolder {
        TextView tvNumber, tvService;
        VH(@NonNull View v) { super(v); tvNumber = v.findViewById(R.id.tvPortNumber); tvService = v.findViewById(R.id.tvPortService); }
    }
}
