pub const Open_state = struct {
    ctrl_down: bool = false,
    configuring: bool = false,
    opened: bool = false,
    n_configuring: u8 = 0,
};
