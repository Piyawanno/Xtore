from xtore.test.PeopleStorage cimport PeopleStorage
from xtore.test.People cimport People
from xtore.common.StreamIOHandler cimport StreamIOHandler
from xtore.instance.HashIterator cimport HashIterator

from faker import Faker
from argparse import RawTextHelpFormatter

import os, sys, argparse, traceback, random, time

cdef str __help__ = "Test Script for Xtore"
cdef bint IS_VENV = sys.prefix != sys.base_prefix

def run():
	cli = StorageTestCLI(StorageTestCLI.getConfig())
	cli.run(sys.argv[1:])
cdef class StorageTestCLI:
	cdef object parser
	cdef object option
	cdef object config

	def __init__(self, config):
		self.config = config
	
	def getParser(self, list argv):
		self.parser = argparse.ArgumentParser(description=__help__, formatter_class=RawTextHelpFormatter)
		self.parser.add_argument("test", help="Name of test", choices=[
			'People',
		])
		self.parser.add_argument("-n", "--count", help="Number of record to test.", required=True, type=int)
		self.option = self.parser.parse_args(argv)

	cdef run(self, list argv):
		self.getParser(argv)
		self.checkPath()
		if self.option.test == 'People': self.testPeopleStorage()
	
	cdef testPeopleStorage(self):
		cdef str resourcePath = self.getResourcePath()
		cdef str path = f'{resourcePath}/People.bin'
		cdef StreamIOHandler io = StreamIOHandler(path)
		cdef PeopleStorage storage = PeopleStorage(io)
		cdef bint isNew = not os.path.isfile(path)
		io.open()
		try:
			storage.enableIterable()
			if isNew: storage.create()
			else: storage.readHeader(0)
			peopleList = self.writePeople(storage)
			storedList = self.readPeople(storage, peopleList)
			self.comparePeople(peopleList, storedList)
			if isNew: self.iteratePeople(storage, peopleList)
			storage.writeHeader()
		except:
			print(traceback.format_exc())
		io.close()
	
	cdef list writePeople(self, PeopleStorage storage):
		cdef list peopleList = []
		cdef People people
		cdef int i
		cdef int n = self.option.count
		cdef object fake = Faker()
		cdef double start = time.time()
		for i in range(n):
			people = People()
			people.ID = random.randint(1_000_000_000_000, 9_999_999_999_999)
			people.name = fake.first_name()
			people.surname = fake.last_name()
			peopleList.append(people)
		cdef double elapsed = time.time() - start
		print(f'>>> People Data of {n} are generated in {elapsed:.3}s')
		start = time.time()
		for people in peopleList:
			storage.set(people)
		elapsed = time.time() - start
		print(f'>>> People Data of {n} are stored in {elapsed:.3}s ({(n/elapsed)} r/s)')
		return peopleList
	
	cdef list readPeople(self, PeopleStorage storage, list peopleList):
		cdef list storedList = []
		cdef People stored
		cdef double start = time.time()
		for people in peopleList:
			stored = storage.get(people, None)
			storedList.append(stored)
		cdef double elapsed = time.time() - start
		cdef int n = len(peopleList)
		print(f'>>> People Data of {n} are read in {elapsed:.3}s ({(n/elapsed)} r/s)')
		return storedList
	
	cdef comparePeople(self, list referenceList, list compareeList):
		cdef People reference, comparee
		cdef double start = time.time()
		for reference, comparee in zip(referenceList, compareeList):
			try:
				assert(reference.ID == comparee.ID)
				assert(reference.name == comparee.name)
				assert(reference.surname == comparee.surname)
			except Exception as error:
				print(reference, comparee)
				raise error
		cdef double elapsed = time.time() - start
		cdef int n = len(referenceList)
		print(f'>>> People Data of {n} are checked in {elapsed:.3}s')
	
	cdef iteratePeople(self, PeopleStorage storage, list referenceList):
		cdef HashIterator iterator
		cdef People entry = People()
		cdef People comparee
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
				comparee = referenceList[i]
				try:
					assert(entry.ID == comparee.ID)
					assert(entry.name == comparee.name)
					assert(entry.surname == comparee.surname)
				except Exception as error:
					print(entry, comparee)
					raise error
				i += 1
			elapsed = time.time() - start
			print(f'>>> People Data of {n} are checked in {elapsed:.3}s')

	cdef checkPath(self):
		cdef str resourcePath = self.getResourcePath()
		if not os.path.isdir(resourcePath): os.makedirs(resourcePath)

	cdef str getResourcePath(self):
		if IS_VENV: return f'{sys.prefix}/var/xtore'
		else: return '/var/xtore'

	@staticmethod
	def getConfig():
		return {}