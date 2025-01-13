from argparse import RawTextHelpFormatter

import os, sys, argparse

cdef str __help__ = """
"""

def run():
	cdef StorageServiceCLI service = StorageServiceCLI()
	service.run(sys.argv[1:])

cdef class StorageServiceCLI:
	cdef object parser
	cdef object option
	cdef object config

	def __init__(self):
		pass

	def getParser(self, list argv):
		self.parser = argparse.ArgumentParser(description=__help__, formatter_class=RawTextHelpFormatter)
		self.option = self.parser.parse_args(argv)

	cdef run(self, list argv):
		self.getParser(argv)

