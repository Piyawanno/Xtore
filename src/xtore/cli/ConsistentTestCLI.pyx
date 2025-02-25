from xtore.algorithm.ConsistentHashing cimport ConsistentHashing
from argparse import RawTextHelpFormatter

import os, sys, argparse, traceback, random, time

cdef str __help__ = "Test Script for Xtore"
cdef bint IS_VENV = sys.prefix != sys.base_prefix


def run():
	cli = ConsisTestCLI()
	cli.run(sys.argv[1:])

cdef class ConsisTestCLI:
	cdef object parser
	cdef object option
	cdef ConsistentHashing ringTest


	
	def getParser(self, list argv):
		self.parser = argparse.ArgumentParser(description=__help__, formatter_class=RawTextHelpFormatter)
		self.option = self.parser.parse_args(argv)

	cdef run(self, list argv):
		self.getParser(argv)
		self.ringTest = ConsistentHashing()
		print(self.ringTest.numReplica)

