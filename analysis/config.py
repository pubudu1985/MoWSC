exp_cmd = "../dist/build/MoWSC-exp/MoWSC-exp"

arg_tags = {
	"pop_size"	: "-p %d",
	"gen_num" 	: "-g %d",
	"prob_xo"	: "-c %f",
	"prob_mu"	: "-m %f",
}

args_defaults = {
	"pop_size"	: 25,
	"gen_num" 	: 2000,
	"prob_xo"	: 1,
	"prob_mu"	: 1,
}

exp_defaults = {
	"times" : 4,
	"args" 	: {}
}

experiments = {
	# "SPEA2-C0"	:{
	# 	"cmd"	: "spea2_c0",
	# },
	"SPEA2-C3"	:{
		"cmd"	: "spea2_c3",
	},
	# "SPEA2-C3r"	:{
	# 	"cmd"	: "spea2_c3r",
	# },
	# "SPEA2-C3sr"	:{
	# 	"cmd"	: "spea2_c3sr",
	# },
	# "MOHEFT"	:{
	# 	"times" : 1,
	# 	"cmd"	: "moheft",
	# },
	# "HBCS" 		:{
	# 	"times"	: 1,
	# 	"cmd"	: "hbcs",
	# },
# 	"HEFT" 		:{
# 		"times"	: 1,
# 		"cmd"	: "heft",
# 	},
}

## DAG

dag_pegasus_path = "./resources/workflows/Pegasus/%s.xml"

dag_pegasus = [
	"Montage_25",
	"Montage_50",
	"Montage_100",
	"Montage_1000",
	"Epigenomics_24",
	"Epigenomics_46",
	"Epigenomics_100",
	"Epigenomics_997_fixed",
	"CyberShake_30",
	"CyberShake_50",
	"CyberShake_100",
	"CyberShake_1000",
	"Sipht_30",
	"Sipht_60",
	"Sipht_100",
	"Sipht_1000",
	"Inspiral_30",
	"Inspiral_50",
	"Inspiral_100",
	"Inspiral_1000",
]

## Database
db_addr = 'http://127.0.0.1:5984/'
db_name = "hookie-exp-test"

## Query

query_cond = {
	"algorithm"	: [
		"SPEA2-C0", 
		"SPEA2-C3",
		"SPEA2-C3r",           
		"SPEA2-C3sr",           
		"MOHEFT",
		],
	"pop_size" 	: [25],
}

## Hypervolume

hv_ref = [1.01, 1.01]

## Plotting

figure_path_pegasus_plot = "./results/"
figure_path_pegasus_trace = "./results/trace/"

