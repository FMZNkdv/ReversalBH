const std = @import("std");

const xml =
    "<data>\n" ++
    "  <servers>\n" ++
    "    <server id=\"1\" name=\"EMU\" url=\"http://127.0.0.1:8080/unity-config/gate.php\">\n" ++
    "      <instance id=\"1\" url=\"http://127.0.0.1:8080/unity-config/emu-instance.xml\"/>\n" ++
    "    </server>\n" ++
    "  </servers>\n" ++
    "</data>";

pub fn isHttp(data: []const u8) bool {
    if (std.mem.startsWith(u8, data, "GET ")) return true;
    if (std.mem.startsWith(u8, data, "POST ")) return true;
    return false;
}

fn target(data: []const u8) []const u8 {
    var first: ?usize = null;
    var second: ?usize = null;
    for (data, 0..) |byte, idx| {
        if (byte == ' ') {
            if (first == null) {
                first = idx;
            } else {
                second = idx;
                break;
            }
        }
        if (byte == '\r' or byte == '\n') break;
    }
    if (first) |start| {
        if (second) |end| {
            if (end > start + 1) return data[start + 1 .. end];
        }
    }
    return "";
}

pub fn serve(io: std.Io, stream: std.Io.net.Stream, first: []const u8) void {
    var buf: [16384]u8 = undefined;
    var total: usize = @min(first.len, buf.len);
    @memcpy(buf[0..total], first[0..total]);

    while (total < buf.len and std.mem.indexOf(u8, buf[0..total], "\r\n\r\n") == null) {
        var bufs = [_][]u8{buf[total..]};
        const got = stream.read(io, &bufs) catch return;
        if (got == 0) break;
        total += got;
    }

    const req = buf[0..total];
    const reader = target(req);
    var wbuf: [4096]u8 = undefined;
    var writer = stream.writer(io, &wbuf);

    if (std.mem.startsWith(u8, reader, "/unity-config/Servers.xml")) {
        writer.interface.print("HTTP/1.1 200 OK\r\nContent-Length: {d}\r\nConnection: close\r\nContent-Type: application/xml\r\n\r\n{s}", .{ xml.len, xml }) catch return;
    } else if (std.mem.startsWith(u8, reader, "/unity-config/gate.php") or std.mem.startsWith(u8, reader, "/unity-config/emu-instance.xml")) {
        var gbuf: [512]u8 = undefined;
        const body = std.fmt.bufPrint(&gbuf, "{s}{s}{s}{d}{s}", .{ "<SmartFoxConfig>\n   <ip>", "127.0.0.1", "</ip>\n   <port>", 8080, "</port>\n   <zone>PixelQuest</zone>\n   <httpPort>8443</httpPort>\n</SmartFoxConfig>" }) catch return;
        writer.interface.print("HTTP/1.1 200 OK\r\nContent-Length: {d}\r\nConnection: close\r\nContent-Type: application/xml\r\n\r\n{s}", .{ body.len, body }) catch return;
    } else {
        writer.interface.print("HTTP/1.1 404 Not Found\r\nContent-Length: 14\r\nConnection: close\r\n\r\nemu: unknown", .{}) catch return;
    }
    writer.interface.flush() catch return;
}
