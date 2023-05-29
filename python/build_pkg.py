#!/usr/bin/python3

##############################################################
# build_pkg.py: Top-level script for building the ofm package
# Copyright (C) 2022 CESNET z. s. p. o.
# Author(s): Tomas Hak <xhakto01@vut.cz>
##############################################################

import shutil
import os


setup_file = "setup.py"
tmp_dir    = "__ofm_pkg_tmp__"
comp_dir   = "../comp/"
init_files = []

# remove existing tmp directory
try:
    shutil.rmtree(tmp_dir)
except:
    pass

# create tmp directory
os.mkdir(tmp_dir)

# copy setup file
shutil.copyfile(setup_file, tmp_dir + "/" + setup_file)

# find non-empty __init__.py files in comp directory
comp_path = os.path.realpath(comp_dir)
for root, dirs, files in os.walk(comp_path):
    for f in files:
        if f == "__init__.py":
            init_file_name = root + '/' + str(f)
            if (os.stat(init_file_name).st_size > 0):
                init_files.append(init_file_name)

# build directory tree and copy necessary files
os.chdir(tmp_dir)
for init in init_files:
    init_dirname = os.path.dirname(init)
    init_subdirname = init_dirname[init_dirname.find("sw")+3:]
    shutil.copytree(init_dirname, init[init.find("ofm") : init.find("sw")] + init_subdirname)

# create empty init files in subdirectories
for root, dirs, files in os.walk("ofm"):
    if not os.path.exists(root + "/__init__.py"):
        with open(root + "/__init__.py", "w") as fp:
            pass

# create ofm package
os.system("python3 setup.py bdist_wheel")
for root, dirs, files in os.walk("dist"):
    for f in files:
        if f.endswith(".whl"):
            shutil.copyfile(root + "/" + str(f), "../" + str(f))

# remove tmp directory
os.chdir("../")
shutil.rmtree(tmp_dir)

