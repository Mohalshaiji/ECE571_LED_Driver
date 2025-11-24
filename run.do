# List of directories to compile
set sv_dirs {
    "FULL SYS"
    "CLK Gen"
    "I2C"
    "LED Controller"
    "TEST Output"
}

# Loop over each directory and compile all .sv files
foreach dir $sv_dirs {
    foreach f [glob -nocomplain -directory $dir *.sv] {
        vlog -sv $f
    }
}

vsim -voptargs="+acc" led_driver_tb
add wave *
run -all
