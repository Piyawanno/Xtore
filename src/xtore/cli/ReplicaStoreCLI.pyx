from xtore.service.Server cimport Server
from xtore.test.People cimport People
from xtore.BaseType cimport i32, u64
from xtore.protocol.ReplicaProtocol import ReplicaProtocol

from argparse import RawTextHelpFormatter
import os, sys, argparse, json, traceback, random, time

cdef str __help__ = "Run Replica from Configuration"
cdef bint IS_VENV = sys.prefix != sys.base_prefix

def run():
	cdef ReplicaStoreCLI service = ReplicaStoreCLI()
	service.run(sys.argv[1:])

cdef class ReplicaStoreCLI :
	cdef dict config
	cdef str resourcePath
	cdef object parser
	cdef object option
	cdef Server service

	cdef run(self, list argv) :
		self.getConfig()
		self.getParser(argv)
		self.getResourcePath()
		cdef bint started = False
		cdef dict replica = self.getReplica()
		if len(replica) :
			self.service = Server(replica)
			self.service.run(ReplicaProtocol)

	cdef getParser(self, list argv) :
		self.parser = argparse.ArgumentParser(usage=__help__, formatter_class=RawTextHelpFormatter)
		self.parser.add_argument("-a", "--algorithm", help="Algorithm from configuration", required=True, type=str, choices=[
			"PrimeRing",
		])
		self.parser.add_argument("-l", "--layer", help="(PrimeRing) Storage layer from configuration", required=True, type=int)
		self.parser.add_argument("-r", "--ringId", help="(PrimeRing) Ring ID from configuration", required=True, type=int)
		self.parser.add_argument("-id", "--replicaId", help="Replica ID from configuration", required=True, type=int)
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

	cdef getReplica(self) :
		cdef dict result = {}
		cdef dict ring
		cdef dict child
		if self.option.algorithm.lower() == "primering" :
			for ring in self.config.get("primeRing", []) :
				if self.option.layer == ring.get("layer") :
					for child in ring.get("childStorageUnit", []) :
						if self.option.ringId == child.get("ringId") :
							try :
								result = child["storageUnit"]["replica"][self.option.replicaId]
							except :
								pass
							break
		return result