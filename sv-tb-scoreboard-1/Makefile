.PHONY: clean sim

export PRJ_ROOT ?= ${PWD}
SRC_ROOT = $(PRJ_ROOT)/rtl
TB_ROOT = $(PRJ_ROOT)/tb
SIM_ROOT = $(PRJ_ROOT)/sim/vcs

SRC = $(shell find $(SRC_ROOT) $(TB_ROOT) -type f -name '*.cpp' -or -name '*.f' -or -name '*.v' -or -name '*.sv')

sim: $(SRC) $(SIM_ROOT)
	cd $(SIM_ROOT); \
		vcs -full64 -sverilog -debug_access+all +lint=all -kdb \
			-top tb_top \
			-f $(TB_ROOT)/flist.f \
			-f $(SRC_ROOT)/flist.f	

run: sim
	cd $(SIM_ROOT); \
		$(SIM_ROOT)/simv -gui

clean:
	rm -rf $(SIM_ROOT)

$(SIM_ROOT):
	mkdir -p $@
