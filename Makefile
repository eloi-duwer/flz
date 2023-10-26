

all : flz flz-config

flz : FORCE
	cd flz && $(MAKE) all

flz-config : FORCE
	cd flz-config && $(MAKE) all

clean : FORCE
	cd flz && $(MAKE) clean
	cd flz-config && $(MAKE) clean

fclean : FORCE
	cd flz && $(MAKE) fclean
	cd flz-config && $(MAKE) fclean

re : FORCE
	cd flz && $(MAKE) re
	cd flz-config && $(MAKE) re

FORCE: ;