from xtore.BaseType cimport i32
from xtore.algorithm.ConsistentHashing cimport ConsistentHashing
from xtore.instance.RecordNode cimport hashDJB
from xtore.algorithm.ConsistentNode cimport ConsistentNode

from libc.stdlib cimport malloc
from libc.string cimport memcpy
from cpython cimport PyBytes_FromStringAndSize
from argparse import RawTextHelpFormatter
import os, sys, argparse, json

cdef str __help__ = ""
cdef bint IS_VENV = sys.prefix != sys.base_prefix
cdef i32 BUFFER_SIZE = 1 << 16

def run():
	cli = ConsistentCLI()
	cli.run(sys.argv[1:])

cdef class ConsistentCLI:
	cdef object parser
	cdef object option
	cdef dict config

	def getParser(self, list argv):
		self.parser = argparse.ArgumentParser(description=__help__, formatter_class=RawTextHelpFormatter)
		self.parser.add_argument("-s", "--method", help="Select Method", required=True, choices=['Get', 'Set'])
		self.parser.add_argument("-k", "--key", help="Type Key", required=True)
		self.option = self.parser.parse_args(argv)

	cdef run(self, list argv):
		self.getParser(argv)
		self.getConfig()
		cdef ConsistentHashing ring
		ring = ConsistentHashing()
		ring.loadData(self.config["nodeDictConsistent"])
		self.setConfig()
		hashKey = hashDJB(self.option.key.encode(), 5)
		ring.getNodeList(hashKey)
	
	cdef getConfig(self):
		cdef str configPath = os.path.join(sys.prefix, "etc", "xtore", "XtoreNetwork.json")
		cdef object fd
		with open(configPath, "rt") as fd :
			self.config = json.loads(fd.read())

	cdef setConfig(self):
		cdef str configPath = os.path.join(sys.prefix, "etc", "xtore", "XtoreNetwork.json")
		cdef object fd
		with open(configPath, "w") as fd :
			json.dump(self.config, fd, indent=4)
