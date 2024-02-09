.PHONY: rpm

rpm: comp
	/usr/bin/env python3 setup.py bdist_rpm

comp:
	ln -s ../../comp comp

clean:
	rm comp -f
	rm -rf build dist *.egg-info
