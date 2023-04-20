from setuptools import setup, find_packages

VERSION = '0.0.1'
DESCRIPTION = 'Open FPGA Modules package'

setup(
    name='ofm',
    version=VERSION,
    author='Tomas Hak',
    author_email='xhakto01@vut.cz',
    description=DESCRIPTION,
    packages=find_packages(),
    install_requires=[],

    keywords=['python'],
    classifiers=[
        "Programming Language :: Python :: 3",
    ]
)
