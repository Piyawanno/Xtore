from xtore.service.Server cimport Server
from xtore.common.StreamIOHandler cimport StreamIOHandler
from xtore.common.Buffer cimport Buffer, initBuffer, releaseBuffer
from xtore.instance.BasicStorage cimport BasicStorage
from xtore.instance.HashIterator cimport HashIterator
from xtore.instance.RecordNode cimport RecordNode
from xtore.instance.HashStorage cimport HashStorage
from xtore.BaseType cimport i32, u64

from xtore.test.Data cimport Data
from xtore.test.PeopleHashStorage cimport PeopleHashStorage
from xtore.test.People cimport People
from xtore.common.Packet cimport Packet

from libc.stdlib cimport malloc
from libc.string cimport memcpy
from cpython cimport PyBytes_FromStringAndSize
import os, sys, argparse, json, traceback, random, time, importlib

from faker import Faker
from argparse import RawTextHelpFormatter

import os, sys, argparse, traceback, random, time

cdef str __help__ = "Test Script for Xtore"
cdef bint IS_VENV = sys.prefix != sys.base_prefix
cdef i32 BUFFER_SIZE = 1 << 16

def run():
	cli = DBServiceCLI()
	cli.run(sys.argv[1:])

cdef initPeople(str name,str surname):
	cdef People people = People()
	people.ID = random.randint(1_000_000_000_000, 9_999_999_999_999)
	people.name = name
	people.surname = surname
	return people

cdef initStorage(StreamIOHandler io):
	cdef PeopleHashStorage storage = PeopleHashStorage(io)
	return storage

cdef dict CLASS_INIT = {
	"People": initPeople,
	"PeopleHashStorage": initStorage
}

cdef class DBServiceCLI:
	cdef object parser
	cdef object option
	cdef Server service
	cdef Buffer stream

	def __init__(self):
		pass
	
	def getParser(self, list argv):
		self.parser = argparse.ArgumentParser(description=__help__, formatter_class=RawTextHelpFormatter)
		self.parser.add_argument("-u", "--host", help="Server host.", required=False, type=str, default='127.0.0.1')
		self.parser.add_argument("-p", "--port", help="Server port.", required=True, type=int)
		self.option = self.parser.parse_args(argv)

	cdef run(self, list argv):
		self.getParser(argv)
		self.checkPath()
		self.startServer()

	cdef startServer(self):
		self.service = Server(self.getConfig())
		self.service.run(self.handlePacket)

	async def handlePacket(self, reader:object, writer:object) -> None :
		message:bytes = await reader.read(1024)
		cdef i32 length = len(message)
		initBuffer(&self.stream, <char *> malloc(length), length)
		memcpy(self.stream.buffer, <char *> message, length)
		cdef Packet packet = Packet()
		packet.readKey(&self.stream)
		self.stream.position += 4
		packet.readValue(&self.stream)
		print(packet)
		cdef object header = packet.getHeader()
		if header["method"] == 'Set':
			self.setHashStorage(packet.data)
			writer.write(message)
		elif header["method"] == 'Get':
			queryResult:str = repr(self.getByID(packet.data))
			returnMessage:bytes = queryResult.encode('utf-8')
			writer.write(returnMessage)
		else: 
			print('Unknown Method')
		await writer.drain()
		writer.close()
		await writer.wait_closed()

	cdef handleData(self, str data):
		cdef dict data_dict = json.loads(data)
		cdef str table_name = data_dict.pop('table_name', None)
		cdef str storage_method = data_dict.pop('storage_method', None)

		cdef object table = CLASS_INIT.get(table_name)(**data_dict)
		return {
			"table" : table,
			"table_type" : type(table),
			"storage_method" : CLASS_INIT.get(storage_method)
		}

	cdef setHashStorage(self, str data):
		cdef object tableInfo = self.handleData(data)
		cdef type Table = tableInfo["table_type"]
		cdef object table = tableInfo["table"]
		cdef str resourcePath = self.getResourcePath()
		cdef str path = f'{resourcePath}/{table.__class__.__name__}.Hash.bin'
		cdef StreamIOHandler io = StreamIOHandler(path)
		cdef PeopleHashStorage storage = tableInfo["storage_method"](io)
		cdef bint isNew = not os.path.isfile(path)
		io.open()
		try:
			storage.enableIterable()
			if isNew: storage.create()
			else: storage.readHeader(0)
			dataList = self.writeData(storage, table)
			storage.writeHeader()
			if isNew: self.iterateData(storage, dataList)
		except:
			print(traceback.format_exc())
		io.close()

	cdef getPeopleDataByID(self, BasicStorage storage, u64 ID):
		cdef People queryPeople = People()
		queryPeople.ID = ID
		cdef People result
		result = storage.get(queryPeople, None)
		print(f">> Query Result: {result}")
		return result

	cdef getData(self, str data):
		cdef Data record = Data()
		cdef dict raw = json.loads(data)
		try:
			del raw['table_name'], raw['storage_method']
		except KeyError:
			pass
		record.ID = random.randint(1_000_000_000_000, 9_999_999_999_999)
		record.fields = raw
		return record

	cdef getByID(self, str rawID):
		cdef u64 castID = <u64> int(rawID)
		cdef str resourcePath = self.getResourcePath()
		cdef str path = f'{resourcePath}/People.Hash.bin'
		cdef StreamIOHandler io = StreamIOHandler(path)
		cdef PeopleHashStorage storage = PeopleHashStorage(io)
		cdef bint isNew = not os.path.isfile(path)
		if isNew: return '<Table not found>'
		cdef People queryResult
		io.open()
		try:
			storage.readHeader(0)
			queryResult = self.getPeopleDataByID(storage, castID)
		except:
			print(traceback.format_exc())
		io.close
		return queryResult

	cdef list writeData(self, BasicStorage storage, object data):
		cdef list dataList = []
		cdef int i
		dataList.append(data)
		for data in dataList:
			storage.set(data)
			print(f'>> Recorded: {data}')
		return dataList
	
	cdef list readData(self, BasicStorage storage, list dataList):
		cdef list storedList = []
		cdef object stored
		for data in dataList:
			stored = storage.get(data, None)
			storedList.append(stored)
		return storedList

	cdef iterateData(self, PeopleHashStorage storage, list referenceList):
		cdef HashIterator iterator
		cdef People entry = People()
		cdef People comparing
		cdef int i
		cdef int n = len(referenceList)
		cdef double start = time.time()
		cdef double elapsed
		if storage.isIterable:
			iterator = HashIterator(storage)
			iterator.start()
			while iterator.getNext(entry):
				continue
			elapsed = time.time() - start
			print(f'>>> Table Data of {n} are iterated in {elapsed:.3}s ({(n/elapsed)} r/s)')

			i = 0
			iterator.start()
			while iterator.getNext(entry):
				comparing = referenceList[i]
				try:
					assert(entry.ID == comparing.ID)
					assert(entry.name == comparing.name)
					assert(entry.surname == comparing.surname)
				except Exception as error:
					print(entry, comparing)
					raise error
				i += 1
			elapsed = time.time() - start
			print(f'>>> Table Data of {n} are checked in {elapsed:.3}s')

	cdef checkPath(self):
		cdef str resourcePath = self.getResourcePath()
		if not os.path.isdir(resourcePath): os.makedirs(resourcePath)

	cdef str getResourcePath(self):
		if IS_VENV: return (f'{sys.prefix}/var/xtore').encode('utf-8').decode('utf-8')
		else: return '/var/xtore'

	cdef getConfig(self):
		return {
			"host" : self.option.host,
			"port" : self.option.port
		}