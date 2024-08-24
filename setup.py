from setuptools import setup, Extension, find_packages
from pathlib import Path
from Cython.Build import cythonize

import multiprocessing


__PROCESS_NUMBER__ = multiprocessing.cpu_count()

def getExtensionList() -> list[Exception]:
	sourcePath = 'src'
	extensionList: list[Exception] = []
	path = Path(f"./{sourcePath}")
	for i in path.rglob("*.pyx"):
		modulePath = str(i.with_suffix(""))
		if '__init__' in modulePath: continue
		print(modulePath.replace("/", '.')[len(sourcePath)+1:], [f'{i}'])
		extensionList.append(Extension(
			modulePath.replace("/", '.')[len(sourcePath)+1:],
			[f'{i}'],
			# define_macros=[("CYTHON_LIMITED_API", "1")],
			# py_limited_api=True,
			extra_compile_args=["-g"],
			extra_link_args=["-g"],
			language = 'c++',
		))
	return extensionList

def build(extensionList):
	setup(
		ext_modules=cythonize(
			extensionList,
			compiler_directives={"language_level": "3"},
			include_path = ["src/"], 
			nthreads=__PROCESS_NUMBER__,
		),
	)

if __name__ == '__main__': build(getExtensionList())