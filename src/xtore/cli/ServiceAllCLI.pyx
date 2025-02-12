from xtore.service.Server cimport Server
from xtore.common.StreamIOHandler cimport StreamIOHandler
from xtore.common.Buffer cimport Buffer, initBuffer, releaseBuffer
from xtore.instance.BasicStorage cimport BasicStorage
from xtore.instance.HashIterator cimport HashIterator
from xtore.instance.RecordNode cimport RecordNode
from xtore.instance.HashStorage cimport HashStorage
from xtore.BaseType cimport i32, u64

from xtore.test.PeopleHashStorage cimport PeopleHashStorage
from xtore.test.DataHashStorage cimport DataHashStorage
from xtore.test.People cimport People
from xtore.test.Data cimport Data
from xtore.test.Package cimport Package
from xtore.test.Data cimport Data

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
	cli = ServiceAllCLI()
	cli.run(sys.argv[1:])

cdef initPeople(str name,str surname):
	cdef People people = People()
	people.ID = random.randint(1_000_000_000_000, 9_999_999_999_999)
	people.name = name
	people.surname = surname
	return people

def initData(**fields):
	cdef Data data = Data()
	data.ID = random.randint(1_000_000_000_000, 9_999_999_999_999)
	data.fields.update(fields)
	return data

cdef initStorage(StreamIOHandler io):
	cdef PeopleHashStorage storage = PeopleHashStorage(io)
	return storage

cdef initDataStorage(StreamIOHandler io):
	cdef DataHashStorage storage = DataHashStorage(io)
	return storage

cdef dict CLASS_INIT = {
	"People": initPeople,
	"Data": initData,
	"PeopleHashStorage": initStorage,
	"DataHashStorage": initDataStorage
}

cdef class ServiceAllCLI:
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
		self.service.run(self.handlePackage)

	async def handlePackage(self, reader:object, writer:object) -> None :
		message:bytes = await reader.read(1024)
		cdef i32 length = len(message)
		initBuffer(&self.stream, <char *> malloc(length), length)
		memcpy(self.stream.buffer, <char *> message, length)
		cdef Package package = Package()
		package.readKey(0, &self.stream)
		print("key: ",package)
		self.stream.position += 4
		package.readValue(0, &self.stream)
		print(package)
		if package.method == 'Set':
			self.setHashStorage(package.data)
		elif package.method == 'Get':
			self.getData(package.data)
		else: 
			print('Unknown Method')
		writer.write(message)
		await writer.drain()
		writer.close()
		await writer.wait_closed()

	cdef handleData(self, str data):
		cdef dict data_dict = json.loads(data)
		print(data_dict)
		cdef str table_name = data_dict.pop('table_name', None)
		cdef str storage_method = data_dict.pop('storage_method', None)
		print(data_dict)
		cdef object table = CLASS_INIT.get("Data")(**data_dict)
		print(table)
		
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
		cdef HashStorage storage = tableInfo["storage_method"](io)
		cdef bint isNew = not os.path.isfile(path)
		io.open()
		try:
			storage.enableIterable()
			if isNew: storage.create()
			else: storage.readHeader(0)
			dataList = self.writeData(storage, table)
			storage.writeHeader()
			if isNew: self.iterateData(storage, dataList, Table)
		except:
			print(traceback.format_exc())
		io.close()

	cdef getData(self, Package Package):
		print('to be continue...')
		pass

	cdef list writeData(self, BasicStorage storage, object data):
		cdef list dataList = []
		cdef int i
		dataList.append(data)
		for data in dataList:
			storage.set(data)
			print('set success!')
		return dataList
	
	cdef list readData(self, BasicStorage storage, list dataList):
		cdef list storedList = []
		cdef object stored
		for data in dataList:
			stored = storage.get(data, None)
			storedList.append(stored)
		return storedList

	cdef iterateData(self, object storage, list referenceList, type Table):
		cdef HashIterator iterator
		cdef type entry = Table()
		cdef object comparing
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