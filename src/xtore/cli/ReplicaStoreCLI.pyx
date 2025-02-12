from xtore.service.Server cimport Server
from xtore.test.People cimport People
from xtore.BaseType cimport i32, u64
from xtore.protocol.ReplicaProtocol import ReplicaProtocol

from argparse import RawTextHelpFormatter
import os, sys, argparse, json, traceback, random, time

cdef str __help__ = "\n\nFollowing Replica from Configuration :"
cdef bint IS_VENV = sys.prefix != sys.base_prefix

def run():
	cdef ReplicaStoreCLI service = ReplicaStoreCLI()
	service.run(sys.argv[1:])

cdef class ReplicaStoreCLI :
	cdef dict config
	cdef str moreHelp
	cdef str resourcePath
	cdef object parser
	cdef object option
	cdef Server service

	cdef run(self, list argv) :
		self.getConfig()
		self.getParser(argv)
		self.getResourcePath()
		cdef dict config
		cdef bint started = False
		for config in self.config.get("replica", []) :
			if self.option.id == config["id"] :
				self.service = Server(config)
				self.service.run(ReplicaProtocol)
		print(self.moreHelp)

	cdef getParser(self, list argv) :
		self.moreHelp = __help__
		for replica in self.config.get("replica", []) :
			self.moreHelp += f"\n{replica['id']} : {replica['host']}@{replica['port']}"
		self.moreHelp += "\n\n----------"
		self.parser = argparse.ArgumentParser(usage=self.moreHelp, formatter_class=RawTextHelpFormatter)
		self.parser.add_argument("id", help="Replication ID", type=int)
		self.option = self.parser.parse_args(argv)
	
	cdef getResourcePath(self) :
		if IS_VENV: self.resourcePath = os.path.join(sys.prefix, "var", "xtore")
		else: self.resourcePath = os.path.join('/', "var", "xtore")
		if not os.path.isdir(self.resourcePath): os.makedirs(self.resourcePath)

	cdef getConfig(self) :
		cdef str configPath = os.path.join(sys.prefix, "etc", "xtore", "XtoreNetwork.json")
		cdef object fd
		with open(configPath, "rt") as fd :
			self.config = json.loads(fd.read())
			fd.close()