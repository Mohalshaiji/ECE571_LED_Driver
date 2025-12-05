# Before running, add the work directory: SIM/work

# directory to compile
set dir "../RTL"

# compile the package first
vlog -sv $dir/led_driver_pkg.sv

# compile the rest of the SV files EXCEPT the package
foreach f [glob -nocomplain -directory $dir *.sv] {
    if { $f ne "$dir/led_driver_pkg.sv" } {
        vlog -sv $f
    }
}

vsim -voptargs="+acc" led_driver_tb
add wave *
run -all
