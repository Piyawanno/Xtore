from xtore.service.ServerService cimport ServerService
from xtore.test.People cimport People
from xtore.common.Buffer cimport Buffer, initBuffer, releaseBuffer
from xtore.BaseType cimport i32, u64
from xtore.protocol.ReplicaProtocol import ReplicaProtocol

from libc.stdlib cimport malloc
from libc.string cimport memcpy
from cpython cimport PyBytes_FromStringAndSize
from argparse import RawTextHelpFormatter
import os, sys, argparse, json, traceback, random, time

cdef str __help__ = ""
cdef bint IS_VENV = sys.prefix != sys.base_prefix
cdef i32 BUFFER_SIZE = 1 << 16

def run():
	cdef ReplicaStoreCLI service = ReplicaStoreCLI()
	service.run(sys.argv[1:])

cdef class ReplicaStoreCLI :
	cdef dict config
	cdef str resourcePath
	cdef object parser
	cdef object option
	cdef ServerService service
	cdef Buffer stream

	def __init__(self):
		initBuffer(&self.stream, <char *> malloc(BUFFER_SIZE), BUFFER_SIZE)
	
	def __dealloc__(self):
		releaseBuffer(&self.stream)

	cdef run(self, list argv) :
		self.getParser(argv)
		self.getResourcePath()
		self.getConfig()
		self.service = ServerService(self.config["replica"][0])
		self.service.run(ReplicaProtocol)

	cdef getParser(self, list argv) :
		self.parser = argparse.ArgumentParser(description=__help__, formatter_class=RawTextHelpFormatter)
		self.option = self.parser.parse_args(argv)
	
	cdef getResourcePath(self) :
		self.resourcePath = f"{sys.prefix}/var/xtore" if IS_VENV else "/var/xtore"

	cdef getConfig(self) :
		cdef str configPath = os.path.join(sys.prefix, "etc", "xtore", "XtoreNetwork.json")
		cdef object fd
		with open(configPath, "rt") as fd :
			self.config = json.loads(fd.read())
			fd.close()