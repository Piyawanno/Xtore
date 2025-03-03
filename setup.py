from setuptools import setup, Extension, find_packages
from pathlib import Path
from Cython.Build import cythonize
from sysconfig import get_paths

import os, sys, multiprocessing

__PROCESS_NUMBER__ = multiprocessing.cpu_count()

def buildCPP(executable, operation) :
	rootPath = os.path.abspath(os.path.dirname(__file__))
	os.chdir(f"{rootPath}/cpp")
	if operation == "build" :
		os.system(f"{executable} setup.py build")
		os.system(f"{executable} setup.py install")
	elif operation == "clean" :
		os.system(f"{executable} setup.py clean")
		os.system(f"{executable} setup.py uninstall")

def getIncludePath() -> list[str] :
	includeList:list = [
		"/usr/include/",
		get_paths()['include'],
		os.path.join(sys.prefix, "include"),
		os.path.join(sys.prefix, "include", "openfhe"),
		os.path.join(sys.prefix, "include", "openfhe", "binfhe"),
		os.path.join(sys.prefix, "include", "openfhe", "cereal"),
		os.path.join(sys.prefix, "include", "openfhe", "core"),
		os.path.join(sys.prefix, "include", "openfhe", "pke"),
		os.path.join(sys.prefix, "include", "xtorecpp"),
	]
	includePath:list = []
	for include in includeList :
		if os.path.isdir(include) : includePath.append(include)
	return includePath

def getLibPath() -> list[str] :
	libList:list = [
		"/usr/lib/",
		get_paths()['platlib'],
		os.path.join(sys.prefix, "lib"),
	]
	libPath:list = []
	for lib in libList :
		if os.path.isdir(lib) : libPath.append(lib)
	return libPath

def getExtension() -> list[Extension] :
	rootPath = os.path.abspath(os.path.dirname(__file__))
	os.chdir(rootPath)
	extensionList: list[Extension] = []
	sourcePath = 'src'
	path = Path(f"./{sourcePath}")
	for i in path.rglob("*.pyx"):
		modulePath = str(i.with_suffix(""))
		if '__init__' in modulePath: continue
		extensionList.append(Extension(
			modulePath.replace("/", '.')[len(sourcePath)+1:],
			sources=[f'{i}'],
			include_dirs=getIncludePath(),
			library_dirs=getLibPath(),
			libraries=["xtorecpp"],
			extra_compile_args=["-g", "--std=c++17"],
			extra_link_args=["-g", "--std=c++17"],
			language = 'c++',
		))
	return extensionList

def build(executable, operation) :
	buildCPP(executable, operation)
	extensionList:list = getExtension()
	setup(
		ext_modules=cythonize(
			extensionList,
			compiler_directives={"language_level": "3"},
			include_path=["src"],
			nthreads=__PROCESS_NUMBER__,
		),
	)

if __name__ == '__main__': build(sys.executable, sys.argv[-1])