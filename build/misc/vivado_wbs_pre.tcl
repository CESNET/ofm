## Remove unloced ports the design

foreach i [get_ports -filter { IS_LOC_FIXED == "FALSE" }] {
    puts "Removing unloced port $i"
    disconnect_net -prune -objects $i
    #remove_port $i
}

foreach i [get_cells -filter {IS_LOC_FIXED == "FALSE" && REF_NAME == "OBUFT"}] {
	puts "Removing unloced OBUFT $i"
	remove_cell $i
}
