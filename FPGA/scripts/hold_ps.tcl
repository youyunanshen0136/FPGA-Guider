connect
puts [targets]
targets -set -filter {name =~ "*Cortex-A9*#0"}
stop
targets -set -filter {name =~ "*Cortex-A9*#1"}
stop
puts [targets]
targets -set -filter {name == "APU"}
puts "FCLK0_CTRL=[mrd 0xF8000170]"
disconnect
exit
