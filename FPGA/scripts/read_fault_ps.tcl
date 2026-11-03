connect
puts "TARGET_STATES: [targets]"
targets -set -filter {name == "APU"}
puts "FCLK0_CTRL: [mrd 0xF8000170]"
puts "BOOT_MODE: [mrd 0xF800025C]"
puts "RESET_REASON: [mrd 0xF8000258]"
disconnect
exit
