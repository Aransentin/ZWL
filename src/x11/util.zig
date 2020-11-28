pub fn xpad(n: usize) u8 {
    const v = @bitCast(usize, (-%@bitCast(isize, n)) & 3);
    return @intCast(u8, v);
}
