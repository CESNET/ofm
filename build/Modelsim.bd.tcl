set output_path [lindex $argv 0]
set bd_core_file [lindex $argv 1]
set fpga [lindex $argv 2]

set modelsim_library ""
if { [info exists ::env(MODELSIM_XIL_LIBRARY)] } {
    set modelsim_library "$env(MODELSIM_XIL_LIBRARY)"
} else {
    set modelsim_library "$env(XILINX_VIVADO)/modelsimlib"
}

puts "Ouput path: $output_path"
puts "IP Core file: $ip_core_file"
puts "FPGA: $fpga"

set lib_map_path_arg ""
if {[file exist $modelsim_library]} {
    puts "Using Modelsim precompiled library - $modelsim_library"
    set lib_map_path_arg [list {-lib_map_path} [list {modelsim="$modelsim_library"}]]
}

create_project -in_memory -part "$fpga"

read_bd "$bd_core_file"
upgrade_ip [get_ips *] -quiet

exec mkdir -p "$output_path/ip_user_files_dir/ipstatic"

generate_target all [get_files "$bd_core_file"] -force
export_simulation \
    -simulator modelsim \
    -force \
    -absolute_path \
    -use_ip_compiled_libs \
    -ip_user_files_dir $output_path/ip_user_files_dir \
    {*}$lib_map_path_arg \
    -ipstatic_source_dir $output_path/ip_user_files_dir/ipstatic \
    -export_source_files \
    -directory "$output_path" \
    -of_objects [get_files "$bd_core_file"]