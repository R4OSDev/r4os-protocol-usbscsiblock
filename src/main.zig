const r4os = @import("r4os");

comptime {
    if (!@import("builtin").is_test) asm (r4os.technical2.protocolEntriesAsm("usbscsi_init", "usbscsi_shutdown", "usbscsi_query", "usbscsi_dispatch"));
}

export fn usbscsi_init(api: *const r4os.r4dev.ProtocolApi2) callconv(.c) i32 {
    const ctx = r4os.r4dev.ProtocolContext2.init(api);
    if (!ctx.requires(.{ "register_role", "set_status" })) return r4os.abi.err_no_fn;
    const registered = ctx.registerRole("usb.scsi_block", .usb, 0);
    if (registered != 0) return registered;
    return ctx.setStatus(.active, "USB SCSI block R4P active");
}

export fn usbscsi_shutdown() callconv(.c) i32 {
    return 0;
}

export fn usbscsi_query(out: *r4os.abi.ProtocolStatus) callconv(.c) i32 {
    out.* = .{
        .state = @intFromEnum(r4os.abi.ProtocolState.active),
        .flags = 0,
        .last_error = 0,
        .reserved = 0,
        .note = note("USB SCSI block R4P ready"),
    };
    return 0;
}

export fn usbscsi_dispatch(op: u32, in_buffer: *const r4os.abi.ProtocolBuffer, out_buffer: *r4os.abi.ProtocolBuffer) callconv(.c) i32 {
    _ = out_buffer;
    const request = requestFromBuffer(in_buffer) orelse return r4os.abi.usb_scsi_result_bad_param;
    switch (op) {
        r4os.abi.usb_scsi_op_build_inquiry => buildInquiry(request),
        r4os.abi.usb_scsi_op_build_test_unit_ready => buildTestUnitReady(request),
        r4os.abi.usb_scsi_op_build_request_sense => buildRequestSense(request),
        r4os.abi.usb_scsi_op_build_read_capacity10 => buildReadCapacity10(request),
        r4os.abi.usb_scsi_op_build_read_capacity16 => buildReadCapacity16(request),
        r4os.abi.usb_scsi_op_build_mode_sense6 => buildModeSense6(request),
        r4os.abi.usb_scsi_op_build_read10 => buildRead10(request),
        r4os.abi.usb_scsi_op_build_read16 => buildRead16(request),
        r4os.abi.usb_scsi_op_build_write10 => buildWrite10(request),
        r4os.abi.usb_scsi_op_build_write16 => buildWrite16(request),
        r4os.abi.usb_scsi_op_build_sync_cache10 => buildSyncCache10(request),
        r4os.abi.usb_scsi_op_parse_sense => parseSense(request),
        r4os.abi.usb_scsi_op_parse_capacity10 => parseCapacity10(request),
        r4os.abi.usb_scsi_op_parse_capacity16 => parseCapacity16(request),
        r4os.abi.usb_scsi_op_parse_mode_sense6 => parseModeSense6(request),
        r4os.abi.usb_scsi_op_self_test => selfTest(request),
        else => return r4os.abi.usb_scsi_result_unsupported,
    }
    return request.result;
}

fn clearCdb(op: *r4os.abi.UsbScsiBlockOp) void {
    op.cdb = .{0} ** r4os.abi.usb_scsi_max_cdb;
    op.cdb_len = 0;
    op.transfer_len = 0;
    op.direction = r4os.abi.usb_scsi_dir_none;
}

fn buildInquiry(op: *r4os.abi.UsbScsiBlockOp) void {
    clearCdb(op);
    op.cdb[0] = 0x12;
    op.cdb[4] = 36;
    op.cdb_len = 6;
    op.transfer_len = 36;
    op.direction = r4os.abi.usb_scsi_dir_in;
    op.result = r4os.abi.usb_scsi_result_ok;
}

fn buildTestUnitReady(op: *r4os.abi.UsbScsiBlockOp) void {
    clearCdb(op);
    op.cdb[0] = 0x00;
    op.cdb_len = 6;
    op.result = r4os.abi.usb_scsi_result_ok;
}

fn buildRequestSense(op: *r4os.abi.UsbScsiBlockOp) void {
    clearCdb(op);
    op.cdb[0] = 0x03;
    op.cdb[4] = 18;
    op.cdb_len = 6;
    op.transfer_len = 18;
    op.direction = r4os.abi.usb_scsi_dir_in;
    op.result = r4os.abi.usb_scsi_result_ok;
}

fn buildReadCapacity10(op: *r4os.abi.UsbScsiBlockOp) void {
    clearCdb(op);
    op.cdb[0] = 0x25;
    op.cdb_len = 10;
    op.transfer_len = 8;
    op.direction = r4os.abi.usb_scsi_dir_in;
    op.result = r4os.abi.usb_scsi_result_ok;
}

fn buildReadCapacity16(op: *r4os.abi.UsbScsiBlockOp) void {
    clearCdb(op);
    op.cdb[0] = 0x9E;
    op.cdb[1] = 0x10;
    writeBe32(op.cdb[10..14], 32);
    op.cdb_len = 16;
    op.transfer_len = 32;
    op.direction = r4os.abi.usb_scsi_dir_in;
    op.result = r4os.abi.usb_scsi_result_ok;
}

fn buildModeSense6(op: *r4os.abi.UsbScsiBlockOp) void {
    clearCdb(op);
    op.cdb[0] = 0x1A;
    op.cdb[1] = 0x08;
    op.cdb[2] = 0x3F;
    op.cdb[4] = 4;
    op.cdb_len = 6;
    op.transfer_len = 4;
    op.direction = r4os.abi.usb_scsi_dir_in;
    op.result = r4os.abi.usb_scsi_result_ok;
}

fn buildRead10(op: *r4os.abi.UsbScsiBlockOp) void {
    if (op.sectors == 0) {
        op.result = r4os.abi.usb_scsi_result_bad_param;
        return;
    }
    clearCdb(op);
    op.cdb[0] = 0x28;
    writeBe32(op.cdb[2..6], op.lba);
    writeBe16(op.cdb[7..9], op.sectors);
    op.cdb_len = 10;
    op.transfer_len = transferBytes(op, op.sectors) orelse {
        op.result = r4os.abi.usb_scsi_result_bad_param;
        return;
    };
    op.direction = r4os.abi.usb_scsi_dir_in;
    op.result = r4os.abi.usb_scsi_result_ok;
}

fn buildWrite10(op: *r4os.abi.UsbScsiBlockOp) void {
    if (op.sectors == 0) {
        op.result = r4os.abi.usb_scsi_result_bad_param;
        return;
    }
    clearCdb(op);
    op.cdb[0] = 0x2A;
    writeBe32(op.cdb[2..6], op.lba);
    writeBe16(op.cdb[7..9], op.sectors);
    op.cdb_len = 10;
    op.transfer_len = transferBytes(op, op.sectors) orelse {
        op.result = r4os.abi.usb_scsi_result_bad_param;
        return;
    };
    op.direction = r4os.abi.usb_scsi_dir_out;
    op.result = r4os.abi.usb_scsi_result_ok;
}

fn buildRead16(op: *r4os.abi.UsbScsiBlockOp) void {
    const blocks = effectiveBlockCount(op);
    if (blocks == 0) {
        op.result = r4os.abi.usb_scsi_result_bad_param;
        return;
    }
    clearCdb(op);
    op.cdb[0] = 0x88;
    writeBe64(op.cdb[2..10], effectiveLba(op));
    writeBe32(op.cdb[10..14], blocks);
    op.cdb_len = 16;
    op.transfer_len = transferBytes(op, blocks) orelse {
        op.result = r4os.abi.usb_scsi_result_bad_param;
        return;
    };
    op.direction = r4os.abi.usb_scsi_dir_in;
    op.result = r4os.abi.usb_scsi_result_ok;
}

fn buildWrite16(op: *r4os.abi.UsbScsiBlockOp) void {
    const blocks = effectiveBlockCount(op);
    if (blocks == 0) {
        op.result = r4os.abi.usb_scsi_result_bad_param;
        return;
    }
    clearCdb(op);
    op.cdb[0] = 0x8A;
    writeBe64(op.cdb[2..10], effectiveLba(op));
    writeBe32(op.cdb[10..14], blocks);
    op.cdb_len = 16;
    op.transfer_len = transferBytes(op, blocks) orelse {
        op.result = r4os.abi.usb_scsi_result_bad_param;
        return;
    };
    op.direction = r4os.abi.usb_scsi_dir_out;
    op.result = r4os.abi.usb_scsi_result_ok;
}

fn buildSyncCache10(op: *r4os.abi.UsbScsiBlockOp) void {
    clearCdb(op);
    op.cdb[0] = 0x35;
    op.cdb_len = 10;
    op.result = r4os.abi.usb_scsi_result_ok;
}

fn parseSense(op: *r4os.abi.UsbScsiBlockOp) void {
    const len: usize = @intCast(op.allocation_len);
    if (len == 0 or len > op.data.len) {
        op.result = r4os.abi.usb_scsi_result_bad_response;
        return;
    }
    switch (op.data[0] & 0x7F) {
        0x70, 0x71 => {
            if (len < 14) {
                op.result = r4os.abi.usb_scsi_result_bad_response;
                return;
            }
            op.sense_key = op.data[2] & 0x0F;
            op.sense_asc = op.data[12];
            op.sense_ascq = op.data[13];
        },
        0x72, 0x73 => {
            if (len < 4) {
                op.result = r4os.abi.usb_scsi_result_bad_response;
                return;
            }
            op.sense_key = op.data[1] & 0x0F;
            op.sense_asc = op.data[2];
            op.sense_ascq = op.data[3];
        },
        else => {
            op.result = r4os.abi.usb_scsi_result_bad_response;
            return;
        },
    }
    op.result = r4os.abi.usb_scsi_result_ok;
}

fn parseCapacity10(op: *r4os.abi.UsbScsiBlockOp) void {
    const len: usize = @intCast(op.allocation_len);
    if (len < 8 or len > op.data.len) {
        op.result = r4os.abi.usb_scsi_result_bad_response;
        return;
    }
    const last_lba = readBe32(op.data[0..4]);
    const block_len = readBe32(op.data[4..8]);
    op.sector_count = if (last_lba == 0xFFFF_FFFF) 0 else @as(u64, last_lba) + 1;
    op.sector_size = block_len;
    op.logical_block_size = block_len;
    op.capacity_format = 10;
    op.result = if (block_len == 0) r4os.abi.usb_scsi_result_bad_response else r4os.abi.usb_scsi_result_ok;
}

fn parseCapacity16(op: *r4os.abi.UsbScsiBlockOp) void {
    const len: usize = @intCast(op.allocation_len);
    if (len < 12 or len > op.data.len) {
        op.result = r4os.abi.usb_scsi_result_bad_response;
        return;
    }
    const last_lba = readBe64(op.data[0..8]);
    const block_len = readBe32(op.data[8..12]);
    if (last_lba == 0xFFFF_FFFF_FFFF_FFFF or block_len == 0) {
        op.result = r4os.abi.usb_scsi_result_bad_response;
        return;
    }
    op.sector_count = last_lba + 1;
    op.sector_size = block_len;
    op.logical_block_size = block_len;
    op.capacity_format = 16;
    op.result = r4os.abi.usb_scsi_result_ok;
}

fn parseModeSense6(op: *r4os.abi.UsbScsiBlockOp) void {
    const len: usize = @intCast(op.allocation_len);
    if (len < 3 or len > op.data.len) {
        op.result = r4os.abi.usb_scsi_result_bad_response;
        return;
    }
    op.write_protected_known = 1;
    op.write_protected = if ((op.data[2] & 0x80) != 0) 1 else 0;
    op.result = r4os.abi.usb_scsi_result_ok;
}

fn selfTest(op: *r4os.abi.UsbScsiBlockOp) void {
    var probe: r4os.abi.UsbScsiBlockOp = .{ .lba = 0x12345678, .sectors = 2, .logical_block_size = 4096 };
    buildRead10(&probe);
    if (probe.result != r4os.abi.usb_scsi_result_ok or probe.cdb[0] != 0x28 or probe.cdb[2] != 0x12 or probe.cdb[5] != 0x78 or probe.cdb[8] != 2) {
        op.result = r4os.abi.usb_scsi_result_bad_param;
        return;
    }
    if (probe.transfer_len != 8192) {
        op.result = r4os.abi.usb_scsi_result_bad_param;
        return;
    }
    probe = .{ .lba64 = 0x0000_0001_2345_6789, .block_count = 3, .logical_block_size = 4096 };
    buildRead16(&probe);
    if (probe.result != r4os.abi.usb_scsi_result_ok or probe.cdb[0] != 0x88 or probe.cdb[2] != 0 or probe.cdb[5] != 1 or probe.cdb[13] != 3 or probe.transfer_len != 12288) {
        op.result = r4os.abi.usb_scsi_result_bad_param;
        return;
    }
    probe = .{ .lba64 = 0x0000_0002_3456_789A, .block_count = 2, .logical_block_size = 4096 };
    buildWrite16(&probe);
    if (probe.result != r4os.abi.usb_scsi_result_ok or probe.cdb[0] != 0x8A or probe.cdb[5] != 2 or probe.cdb[13] != 2 or probe.transfer_len != 8192 or probe.direction != r4os.abi.usb_scsi_dir_out) {
        op.result = r4os.abi.usb_scsi_result_bad_param;
        return;
    }
    probe = .{};
    buildReadCapacity16(&probe);
    if (probe.result != r4os.abi.usb_scsi_result_ok or probe.cdb[0] != 0x9E or probe.cdb[1] != 0x10 or probe.cdb_len != 16 or probe.transfer_len != 32) {
        op.result = r4os.abi.usb_scsi_result_bad_param;
        return;
    }
    probe = .{};
    probe.allocation_len = 8;
    writeBe32(probe.data[0..4], 999);
    writeBe32(probe.data[4..8], 512);
    parseCapacity10(&probe);
    if (probe.result != r4os.abi.usb_scsi_result_ok or probe.sector_count != 1000 or probe.sector_size != 512) {
        op.result = r4os.abi.usb_scsi_result_bad_response;
        return;
    }
    probe = .{};
    probe.allocation_len = 8;
    writeBe32(probe.data[0..4], 0xFFFF_FFFF);
    writeBe32(probe.data[4..8], 4096);
    parseCapacity10(&probe);
    if (probe.result != r4os.abi.usb_scsi_result_ok or probe.sector_count != 0 or probe.capacity_format != 10) {
        op.result = r4os.abi.usb_scsi_result_bad_response;
        return;
    }
    probe = .{};
    probe.allocation_len = 32;
    writeBe64(probe.data[0..8], 0x0000_0001_0000_0000);
    writeBe32(probe.data[8..12], 4096);
    parseCapacity16(&probe);
    if (probe.result != r4os.abi.usb_scsi_result_ok or probe.sector_count != 0x0000_0001_0000_0001 or probe.sector_size != 4096 or probe.capacity_format != 16) {
        op.result = r4os.abi.usb_scsi_result_bad_response;
        return;
    }
    probe.allocation_len = 4;
    probe.data[2] = 0x80;
    parseModeSense6(&probe);
    if (probe.write_protected_known != 1 or probe.write_protected != 1) {
        op.result = r4os.abi.usb_scsi_result_bad_response;
        return;
    }
    probe.allocation_len = 18;
    probe.data[0] = 0x70;
    probe.data[2] = 0x05;
    probe.data[12] = 0x20;
    probe.data[13] = 0x00;
    parseSense(&probe);
    if (probe.sense_key != 0x05 or probe.sense_asc != 0x20 or probe.sense_ascq != 0x00) {
        op.result = r4os.abi.usb_scsi_result_bad_response;
        return;
    }
    op.result = r4os.abi.usb_scsi_result_ok;
}

fn requestFromBuffer(buffer: *const r4os.abi.ProtocolBuffer) ?*r4os.abi.UsbScsiBlockOp {
    const native = r4os.native_protocol_view;
    // These original caller-owned operation records are not wire headers.
    // Dispatch borrows them exclusively and never owns a USB transfer.
    var metadata = buffer.*;
    return (native.InOut(r4os.abi.UsbScsiBlockOp).init(&metadata, native.Policy.record(r4os.abi.UsbScsiBlockOp, .inout, .prefix)) catch return null).value;
}

fn readBe32(bytes: []const u8) u32 {
    var reader = r4os.binary_cursor.Reader.init(bytes) catch unreachable;
    return reader.readInt(u32, .big) catch unreachable;
}

fn readBe64(bytes: []const u8) u64 {
    var reader = r4os.binary_cursor.Reader.init(bytes) catch unreachable;
    return reader.readInt(u64, .big) catch unreachable;
}

fn effectiveLba(op: *const r4os.abi.UsbScsiBlockOp) u64 {
    return if (op.lba64 != 0) op.lba64 else op.lba;
}

fn effectiveBlockCount(op: *const r4os.abi.UsbScsiBlockOp) u32 {
    return if (op.block_count != 0) op.block_count else op.sectors;
}

fn transferBytes(op: *const r4os.abi.UsbScsiBlockOp, blocks: u32) ?u32 {
    const block_size = if (op.logical_block_size == 0) @as(u32, 512) else op.logical_block_size;
    if (block_size == 0 or blocks > 0xFFFF_FFFF / block_size) return null;
    return blocks * block_size;
}

fn writeBe16(out: []u8, value: u16) void {
    var writer = r4os.binary_cursor.Writer.init(out) catch unreachable;
    writer.writeInt(u16, value, .big) catch unreachable;
}

fn writeBe32(out: []u8, value: u32) void {
    var writer = r4os.binary_cursor.Writer.init(out) catch unreachable;
    writer.writeInt(u32, value, .big) catch unreachable;
}

fn writeBe64(out: []u8, value: u64) void {
    var writer = r4os.binary_cursor.Writer.init(out) catch unreachable;
    writer.writeInt(u64, value, .big) catch unreachable;
}

fn note(comptime text: []const u8) [64]u8 {
    var out: [64]u8 = .{0} ** 64;
    @memcpy(out[0..text.len], text);
    return out;
}
