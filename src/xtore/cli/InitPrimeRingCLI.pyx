from xtore.BaseType cimport i32
from xtore.service.PrimeRing cimport PrimeRing

from libc.stdlib cimport malloc
from libc.string cimport memcpy
from cpython cimport PyBytes_FromStringAndSize
from argparse import RawTextHelpFormatter
import os, sys, argparse, json

cdef str __help__ = ""
cdef bint IS_VENV = sys.prefix != sys.base_prefix
cdef i32 BUFFER_SIZE = 1 << 16

def run():
	cdef InitPrimeRingCLI service = InitPrimeRingCLI()
	service.run(sys.argv[1:])

cdef class InitPrimeRingCLI:
	cdef object parser
	cdef object option

	cdef getParser(self, list argv):
		self.parser = argparse.ArgumentParser(description=__help__, formatter_class=RawTextHelpFormatter)
		self.option = self.parser.parse_args(argv)
	
	cdef run(self, list argv):
		self.getParser(argv)
		ring = PrimeRing()
		ring.initialize()
