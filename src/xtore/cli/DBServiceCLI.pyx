from xtore.common.ServerHandler cimport ServerHandler
from xtore.common.StreamIOHandler cimport StreamIOHandler
from xtore.instance.BasicStorage cimport BasicStorage
from xtore.instance.HashIterator cimport HashIterator
from xtore.common.Buffer cimport Buffer, initBuffer, releaseBuffer
from xtore.BaseType cimport i32, u64

from xtore.test.PeopleHashStorage cimport PeopleHashStorage
from xtore.test.People cimport People
from xtore.test.Package cimport Package

from libc.stdlib cimport malloc
from libc.string cimport memcpy
from cpython cimport PyBytes_FromStringAndSize
import os, sys, argparse, json, traceback, random, time

from faker import Faker
from argparse import RawTextHelpFormatter

import os, sys, argparse, traceback, random, time

cdef str __help__ = "Test Script for Xtore"
cdef bint IS_VENV = sys.prefix != sys.base_prefix
cdef i32 BUFFER_SIZE = 1 << 16

def run():
	cli = DBServiceCLI()
	cli.run(sys.argv[1:])

cdef class DBServiceCLI:
	cdef object parser
	cdef object option
	cdef ServerHandler handler
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
		self.handler = ServerHandler(self.getConfig())
		self.handler.run(self.handlePackage)

	async def handlePackage(self, reader:object, writer:object) -> None :
		message:bytes = await reader.read(1024)
		cdef i32 length = len(message)
		initBuffer(&self.stream, <char *> malloc(length), length)
		memcpy(self.stream.buffer, <char *> message, length)
		cdef Package package = Package()
		package.readKey(0, &self.stream)
		self.stream.position += 4
		package.readValue(0, &self.stream)
		print(package)
		if package.method == 'Set': self.setPersonHashStorage(package)
		else: self.getPeople(package)
		writer.write(message)
		await writer.drain()
		writer.close()
		await writer.wait_closed()

	cdef setPersonHashStorage(self, Package package):
		cdef str resourcePath = self.getResourcePath()
		cdef str path = f'{resourcePath}/People.Hash.bin'
		cdef StreamIOHandler io = StreamIOHandler(path)
		cdef PeopleHashStorage storage = PeopleHashStorage(io)
		cdef bint isNew = not os.path.isfile(path)
		io.open()
		try:
			storage.enableIterable()
			if isNew: storage.create()
			else: storage.readHeader(0)
			peopleList = self.writePeople(storage, package)
			storage.writeHeader()
			if isNew: self.iteratePeople(storage, peopleList)
		except:
			print(traceback.format_exc())
		io.close()

	cdef getPeople(self, Package Package):
		print('to be continue...')
		pass

	cdef list writePeople(self, BasicStorage storage, Package package):
		cdef list peopleList = []
		cdef People people = People()
		cdef int i
		people.position = -1
		people.ID = random.randint(1_000_000_000_000, 9_999_999_999_999)
		people.name = package.name
		people.surname = package.surname
		peopleList.append(people)
		for people in peopleList:
			storage.set(people)
			print('set success!')
		return peopleList
	
	cdef list readPeople(self, BasicStorage storage, list peopleList):
		cdef list storedList = []
		cdef People stored
		for people in peopleList:
			stored = storage.get(people, None)
			storedList.append(stored)
		return storedList

	cdef iteratePeople(self, PeopleHashStorage storage, list referenceList):
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
			print(f'>>> People Data of {n} are iterated in {elapsed:.3}s ({(n/elapsed)} r/s)')

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
			print(f'>>> People Data of {n} are checked in {elapsed:.3}s')

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