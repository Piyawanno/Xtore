# from xtore.service.StorageClient cimport StorageClient
from xtore.service.PrimeRingClient cimport PrimeRingClient
from xtore.common.Buffer cimport Buffer, initBuffer, releaseBuffer, setBuffer
from xtore.protocol.RecordNodeProtocol cimport RecordNodeProtocol, DatabaseOperation, InstanceType
from xtore.test.People cimport People
from xtore.BaseType cimport i32, i64

from libc.stdlib cimport malloc
from cpython cimport PyBytes_FromStringAndSize
from argparse import RawTextHelpFormatter

import os, sys, argparse, json, csv, uuid

cdef str __help__ = ""
cdef bint IS_VENV = sys.prefix != sys.base_prefix
cdef i32 BUFFER_SIZE = 1 << 16

cdef object METHOD = {
	"SET": DatabaseOperation.SET,
	"GET": DatabaseOperation.GET
}

cdef object INSTANT_TYPE = {
	"HASH": InstanceType.HASH,
	"RT": InstanceType.RT,
	"BST": InstanceType.BST
}

def run():
	cdef GetPrimeRingPeopleCLI cli = GetPrimeRingPeopleCLI()
	cli.run(sys.argv[1:])

cdef class GetPrimeRingPeopleCLI :
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
		self.option = self.parser.parse_args(argv)

	cdef getConfig(self) :
		cdef str configPath = os.path.join(sys.prefix, "etc", "xtore", "XtoreNetwork.json")
		cdef object fd
		with open(configPath, "rt") as fd :
			self.config = json.loads(fd.read())
			fd.close()

	cdef list[People] TSVToPeopleRecordList(self, str filename) :
		cdef object fd
		cdef list[People] peopleList = []
		cdef People peopleRecord
		with open(filename, "rt") as fd :
			reader = csv.reader(fd, delimiter='\t')
			data = list(reader)
			for row in data[1:]:
				peopleRecord = People()
				peopleRecord.ID = uuid.uuid4()
				peopleRecord.income = <i64> int(row[0])
				peopleRecord.name = row[1]
				peopleRecord.surname = row[2]
				peopleList.append(peopleRecord)
			fd.close()
		return peopleList

	cdef list TSVToPeopleList(self, str filename) :
		cdef object fd
		with open(filename, "rt") as fd :
			reader = csv.reader(fd, delimiter='\t')
			data = list(reader)
			fd.close()
		return data

	cdef list TSVToIDList(self, str filename) :
		cdef object fd
		with open(filename, "rt") as fd :
			reader = csv.reader(fd)
			data = list(reader)
			fd.close()
		return data

	cdef encodePeople(self, list peopleList) :
		cdef RecordNodeProtocol protocol = RecordNodeProtocol()
		print(f"method: {self.option.method}")
		print(f"method: {METHOD[self.option.method]}")
		protocol.writeHeader(
			operation=METHOD[self.option.method],
			instantType=InstanceType.BST, 
			tableName="People", 
			version=1
		)
		protocol.encode(&self.stream, peopleList)
		# print(f"Encoded People: {self.stream}")
		return PyBytes_FromStringAndSize(self.stream.buffer, self.stream.position)

	cdef list[People] decodePeople(self, Buffer *stream) :
		cdef RecordNodeProtocol protocol = RecordNodeProtocol()
		protocol.registerClass("People", People)
		protocol.getHeader(stream)
		print(f"Header: {protocol}")
		return protocol.decode(stream)

	cdef showPeople(self, list peopleList) :
		for people in peopleList:
			print(people)

	cdef handleGet(self, bytes message) :
		cdef list[People] peopleList
		# print(f"Recieved Buffer: {message}")
		setBuffer(&self.received, <char *> message, len(message))
		self.received.position -= len(message)
		# print(f"Decoded People: {self.received}")
		peopleList = self.decodePeople(&self.received)
		self.showPeople(peopleList)

	cdef handleResponse(self, bytes message) :
		# print(f"Recieved Buffer: {message}")
		setBuffer(&self.received, <char *> message, len(message))
		# print(f"Message: {self.received}")

	cdef run(self, list argv) :
		print('Running...')
		self.getParser(argv)
		if METHOD[self.option.method] == DatabaseOperation.GET:
			if not self.option.filename:
				print("Filename is required for GET method.")
				return
			dataList = self.TSVToIDList(self.option.filename)
		elif METHOD[self.option.method] == DatabaseOperation.SET:
			if not self.option.filename:
				print("Filename is required for SET method.")
				return
			dataList = self.TSVToPeopleList(self.option.filename)
		elif METHOD[self.option.method] == DatabaseOperation.GETALL:
			pass
		else:
			print("Invalid method.")
			return

		self.stream.position = 0
		self.getConfig()
		if self.config["algorithm"] == 0: # Consistent Hashing
			# self.client = ConsistentHashingClient(self.config["nodeList"])
			pass
		elif self.config["algorithm"] == 1: # Prime Ring
			self.client = PrimeRingClient(self.config["nodeList"], self.config["primeRing"])
		self.client.send(
			method=METHOD[self.option.method],
			instantType=InstanceType.BST,
			data=dataList
		)
		if self.option.method == "GET":
			response = self.client.received
			self.handleGet(response)
		else:
			response = self.client.received
			self.handleResponse(response)


# what i want this file to do
# 1. read the tsv file
# 2. send the data to client immediately
	# SET: send the data
	# GET: send the key (not hash) to the server
	# GETALL: not send anything instead of command
# 3. receive the data from the server
