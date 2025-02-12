from xtore.test.PeopleHashStorage cimport PeopleHashStorage
from xtore.test.PeopleBSTStorage cimport PeopleBSTStorage
from xtore.test.PeopleRTStorage cimport PeopleRTStorage
from xtore.test.People cimport People
from xtore.common.StreamIOHandler cimport StreamIOHandler
from xtore.instance.HashIterator cimport HashIterator
from xtore.instance.BasicStorage cimport BasicStorage
from xtore.instance.BasicIterator cimport BasicIterator
from xtore.instance.ScopeTreeStorage cimport ScopeTreeStorage
from xtore.instance.ScopeSearch cimport ScopeSearch
from xtore.instance.ScopeSearchResult cimport ScopeSearchResult
from xtore.test.PeopleHomomorphic cimport PeopleHomomorphic


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
			'People.Hash',
			'People.BST',
			'People.RT'
		])
		self.parser.add_argument("-n", "--count", help="Number of record to test.", required=True, type=int)
		self.option = self.parser.parse_args(argv)

	cdef run(self, list argv):
		self.getParser(argv)
		self.checkPath()
		if self.option.test == 'People.Hash': self.testPeopleHashStorage()
		elif self.option.test == 'People.BST': self.testPeopleBSTStorage()
		elif self.option.test == 'People.RT': self.testPeopleRTStorage()

	cdef testPeopleRTStorage(self):
		cdef str resourcePath = self.getResourcePath()
		cdef str path = f'{resourcePath}/People.RT.bin'
		cdef StreamIOHandler io = StreamIOHandler(path)
		cdef PeopleRTStorage storage = PeopleRTStorage(io)
		cdef bint isNew = not os.path.isfile(path)
		io.open()
		try:
			if isNew: storage.create()
			else: storage.readHeader(0)
			peopleList = self.writePeople(storage)
			storedList = self.readPeople(storage, peopleList)
			self.comparePeople(peopleList, storedList)
			self.iteratePeople(storage)
			storage.writeHeader()
			self.searchPeople(storage, peopleList)
		except:
			print(traceback.format_exc())
		io.close()

	cdef testPeopleBSTStorage(self):
		cdef str resourcePath = self.getResourcePath()
		cdef str path = f'{resourcePath}/People.BST.bin'
		cdef StreamIOHandler io = StreamIOHandler(path)
		cdef PeopleBSTStorage storage = PeopleBSTStorage(io)
		cdef bint isNew = not os.path.isfile(path)
		io.open()
		try:
			if isNew: storage.create()
			else: storage.readHeader(0)
			peopleList = self.writePeople(storage)
			storedList = self.readPeople(storage, peopleList)
			self.comparePeople(peopleList, storedList)
			storage.writeHeader()
		except:
			print(traceback.format_exc())
		io.close()

	cdef testPeopleHashStorage(self):
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
			peopleList = self.writePeople(storage)
			storedList = self.readPeople(storage, peopleList)
			self.comparePeople(peopleList, storedList)
			self.iteratePeople(storage)
			storage.writeHeader()
		except:
			print(traceback.format_exc())
		io.close()
	
	cdef list writePeople(self, BasicStorage storage):
		cdef list peopleList = []
		cdef People people
		cdef int i
		cdef int n = self.option.count
		cdef object fake = Faker()
		cdef double start = time.time()
		for i in range(n):
			people = People()
			people.position = -1
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
	
	cdef list readPeople(self, BasicStorage storage, list peopleList):
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
	
	cdef comparePeople(self, list referenceList, list comparingList):
		cdef People reference, comparing
		cdef double start = time.time()
		for reference, comparing in zip(referenceList, comparingList):
			try:
				assert(reference.ID == comparing.ID)
				assert(reference.income == comparing.income)
				assert(reference.name == comparing.name)
				assert(reference.surname == comparing.surname)
			except Exception as error:
				print(reference, comparing)
				raise error
		cdef double elapsed = time.time() - start
		cdef int n = len(referenceList)
		print(f'>>> People Data of {n} are checked in {elapsed:.3}s')
	
	cdef iteratePeople(self, BasicStorage storage):
		cdef BasicIterator iterator
		cdef People entry = People()
		cdef People comparing
		cdef int n = 0
		cdef double start = time.time()
		cdef double elapsed
		iterator = storage.createIterator()
		iterator.start()
		while iterator.getNext(entry):
			n += 1
		elapsed = time.time() - start
		print(f'>>> People Data of {n} are iterated in {elapsed:.3}s ({(n/elapsed)} r/s)')
	
	cdef searchPeople(self, ScopeTreeStorage storage, list[People] peopleList):
		cdef People reference = People()
		reference.ID = random.randint(1_000_000_000_000, 9_999_999_999_999)
		cdef ScopeSearch search = ScopeSearch(storage)
		cdef ScopeSearchResult result = search.getGreater(reference)
		cdef People people = People()
		while result.getNext(people):
			assert people.ID > reference.ID
		
		result = search.getLess(reference)
		while result.getNext(people):
			assert people.ID < reference.ID

		reference = random.choice(peopleList)
		result = search.getGreaterEqual(reference)
		while result.getNext(people):
			assert people.ID >= reference.ID
		
		result = search.getLessEqual(reference)
		while result.getNext(people):
			assert people.ID <= reference.ID
		
		cdef People other = random.choice(peopleList)
		cdef People start = reference if reference.ID < other.ID else other
		cdef People end = reference if reference.ID >= other.ID else other
		result = search.getRange(start, end, False, False)
		while result.getNext(people):
			try:
				assert people.ID > start.ID and people.ID < end.ID
			except:
				print(people.ID, start.ID, end.ID, people.ID > start.ID, people.ID < end.ID)
				break

		result = search.getRange(start, end, True, False)
		while result.getNext(people):
			assert people.ID >= start.ID and people.ID < end.ID

		result = search.getRange(start, end, False, True)
		while result.getNext(people):
			assert people.ID > start.ID and people.ID <= end.ID

		result = search.getRange(start, end, True, True)
		while result.getNext(people):
			assert people.ID >= start.ID and people.ID <= end.ID
			

	cdef checkPath(self):
		cdef str resourcePath = self.getResourcePath()
		if not os.path.isdir(resourcePath): os.makedirs(resourcePath)

	cdef str getResourcePath(self):
		if IS_VENV: return f'{sys.prefix}/var/xtore'
		else: return '/var/xtore'

	@staticmethod
	def getConfig():
		return {}