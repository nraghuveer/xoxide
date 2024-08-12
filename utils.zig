pub fn castToSelf(comptime T: type, ptr: *anyopaque) T {
    return @ptrCast(@alignCast(ptr));
}
