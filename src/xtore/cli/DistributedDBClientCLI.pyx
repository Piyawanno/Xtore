from xtore.service.ConsistentHashingClient cimport ConsistentHashingClient
from xtore.service.PrimeRingClient cimport PrimeRingClient
from xtore.common.Buffer cimport Buffer, initBuffer, releaseBuffer, setBuffer
from xtore.protocol.RecordNodeProtocol cimport DatabaseOperation, InstanceType
from xtore.test.People cimport People
from xtore.BaseType cimport i32, i64

from libc.stdlib cimport malloc
from argparse import RawTextHelpFormatter

import os, sys, argparse, json, csv, uuid

cdef str __help__ = ""
cdef bint IS_VENV = sys.prefix != sys.base_prefix
cdef i32 BUFFER_SIZE = 1 << 16

cdef object METHOD = {
	"SET": DatabaseOperation.SET,
	"GET": DatabaseOperation.GET,
	"GETALL": DatabaseOperation.GETALL
}

cdef object INSTANT_TYPE = {
	"HASH": InstanceType.HASH,
	"RT": InstanceType.RT,
	"BST": InstanceType.BST
}

def run():
	cdef DistributedDBClientCLI cli = DistributedDBClientCLI()
	cli.run(sys.argv[1:])

cdef class DistributedDBClientCLI :
	cdef object config
	cdef object parser
	cdef object option
	cdef PrimeRingClient client
	cdef Buffer stream
	cdef Buffer received

	def __init__(self):
		initBuffer(&self.stream, <char *> malloc(BUFFER_SIZE), BUFFER_SIZE)
		initBuffer(&self.received, <char *> malloc(BUFFER_SIZE), BUFFER_SIZE)

	def __dealloc__(self):
		releaseBuffer(&self.stream)
		releaseBuffer(&self.received)

	cdef getParser(self, list argv) :
		self.parser = argparse.ArgumentParser(description=__help__, formatter_class=RawTextHelpFormatter)
		self.parser.add_argument("-f", "--filename", help="TSV file to send.", required=False, type=str)
		self.parser.add_argument("-m", "--method", help="Method to use.", required=False, type=str, choices=METHOD.keys(), default="SET")
		self.parser.add_argument("-a", "--algorithm", help="Select Distributed Algorithm.", required=False, type=str, choices=METHOD.keys(), default="SET")
		self.option = self.parser.parse_args(argv)

	cdef getConfig(self) :
		cdef str configPath = os.path.join(sys.prefix, "etc", "xtore", "XtoreNetwork.json")
		cdef object fd
		with open(configPath, "rt") as fd :
			self.config = json.loads(fd.read())
			fd.close()

	cdef list TSVToDataList(self, str filename) :
		cdef object fd
		with open(filename, "rt") as fd :
			reader = csv.reader(fd, delimiter='\t')
			data = list(reader)
			fd.close()
		return data

	cdef run(self, list argv) :
		print('Running...')
		self.getParser(argv)
		cdef list dataList = []
		if METHOD[self.option.method] == DatabaseOperation.GET or METHOD[self.option.method] == DatabaseOperation.SET:
			if not self.option.filename:
				print("Data file is required for GET/SET method.")
				return
			dataList = self.TSVToDataList(self.option.filename)
		elif METHOD[self.option.method] == DatabaseOperation.GETALL:
			pass
		else:
			print("Invalid method.")
			return

		self.stream.position = 0
		self.getConfig()
		if self.config["algorithm"] == 0: # Consistent Hashing
			self.client = ConsistentHashingClient(self.config["nodeList"], self.config["consistentHashing"])
			pass
		elif self.config["algorithm"] == 1: # Prime Ring
			self.client = PrimeRingClient(self.config["nodeList"], self.config["primeRing"])
		self.client.send(
			method=METHOD[self.option.method],
			instantType=InstanceType.BST,
			tableName="People",
			data=dataList
		)
