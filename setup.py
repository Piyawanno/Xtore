from setuptools import setup, Extension, find_packages
from pathlib import Path
from Cython.Build import cythonize

import os, sys, multiprocessing

__PROCESS_NUMBER__ = multiprocessing.cpu_count()

def buildCPP(executable) :
	rootPath = os.path.abspath(os.path.dirname(__file__))
	os.chdir(f"{rootPath}/cpp")
	os.system(f"{executable} setup.py build")
	os.system(f"{executable} setup.py install")

def getExtensionList() -> list[Extension]:
	rootPath = os.path.abspath(os.path.dirname(__file__))
	os.chdir(rootPath)
	sourcePath = 'src'
	extensionList: list[Extension] = []
	path = Path(f"./{sourcePath}")
	includeList:list = [
		os.path.join(sys.prefix, "include"),
		os.path.join(sys.prefix, "include", "openfhe"),
		os.path.join(sys.prefix, "include", "openfhe", "binfhe"),
		os.path.join(sys.prefix, "include", "openfhe", "cereal"),
		os.path.join(sys.prefix, "include", "openfhe", "core"),
		os.path.join(sys.prefix, "include", "openfhe", "pke"),
	]
	includePath:list = []
	for include in includeList :
		if os.path.isdir(include) : includePath.append(include)
	libPath:list = ["OPENFHEbinfhe", "OPENFHEcore", "OPENFHEpke"] if len(includePath) else []
	for i in path.rglob("*.pyx"):
		modulePath = str(i.with_suffix(""))
		if '__init__' in modulePath: continue
		extensionList.append(Extension(
			modulePath.replace("/", '.')[len(sourcePath)+1:],
			sources=[f'{i}'],
			# define_macros=[("CYTHON_LIMITED_API", "1")],
			# py_limited_api=True,
			include_dirs=includePath,
			library_dirs=[os.path.join(sys.prefix, "lib"),],
			libraries=libPath,
			extra_compile_args=["-g", "--std=c++17"],
			extra_link_args=["-g", "--std=c++17"],
			language = 'c++',
		))
	return extensionList

def build(executable) :
	buildCPP(executable)
	extensionList:list = getExtensionList()
	setup(
		ext_modules=cythonize(
			extensionList,
			compiler_directives={"language_level": "3"},
			include_path = ["src/"], 
			nthreads=__PROCESS_NUMBER__,
		),
	)

if __name__ == '__main__': build(sys.executable)