from xtore.BaseType cimport i32
from xtore.common.StreamIOHandler cimport StreamIOHandler
from xtore.instance.BasicStorage cimport BasicStorage
from xtore.instance.BasicIterator cimport BasicIterator
from xtore.instance.ScopeTreeStorage cimport ScopeTreeStorage
from xtore.instance.ScopeSearch cimport ScopeSearch
from xtore.instance.ScopeSearchResult cimport ScopeSearchResult
from xtore.test.People cimport People

import os, sys, argparse, traceback, random, time
import numpy as np
from libc.stdlib cimport malloc, free
from libc.string cimport memcpy
from faker import Faker
from argparse import RawTextHelpFormatter

from xtore.instance.HomomorphicBSTStorage import HomomorphicBSTStorage
from xtore.test.PeopleHomomorphic cimport PeopleHomomorphic
from xtore.base.CythonHomomorphic cimport CythonHomomorphic, Ciphertext
from libcpp.vector cimport vector

cdef str __help__ = "Test Script for Xtore"
cdef bint IS_VENV = sys.prefix != sys.base_prefix
def run():
	cli = HomomorphicCLI()       
	cli.run(sys.argv[1:])

ctypedef struct TextIntegerArray:
	i32 textLength
	i32 arrayLength
	i32 *array

cdef class HomomorphicCLI:
	cdef object parser
	cdef object option
	cdef object config

	def __init__(self):
		self.config = self.getConfig() 

	def getParser(self, list argv):
		self.parser = argparse.ArgumentParser(description=__help__, formatter_class=RawTextHelpFormatter)
		self.parser.add_argument("test", help="Name of test", choices=[
			'People.HE',
			'Homomorphic',
			'Wrapper',
			'Concept',
			'Binary',
		])
		self.parser.add_argument("-n", "--count", help="Number of record to test.", required=False, type=int)
		self.option = self.parser.parse_args(argv)

	cdef run(self, list argv):
		self.getParser(argv)  
		self.checkPath()  
		if self.option.test == 'People.HE': self.testPeopleHomomorphic()
		elif self.option.test == 'Homomorphic': self.testHomomorphic()
		elif self.option.test == 'Wrapper': self.testHomomorphic()
		elif self.option.test == 'Concept': self.testDataConcept()
		elif self.option.test == 'Binary': self.testBinarySearch()

	cdef testHomomorphic(self):
		cdef int ringDim = 8192
		cdef int slots = 1
		cdef int batchSize = slots 
		cdef int multiplicativeDepth = 17
		cdef int scalingModSize = 50
		cdef int firstModSize = 60
		cdef CythonHomomorphic homomorphic = CythonHomomorphic()

		homomorphic.initializeCKKS(multiplicativeDepth, scalingModSize, firstModSize, ringDim, batchSize)  
		homomorphic.setupSchemeSwitching(slots, 25)
		cipherText1 =  homomorphic.encrypt([1])
		cipherText2 =  homomorphic.encrypt([2])
		result = homomorphic.compare(slots, cipherText1, cipherText2)
		print(result)

		decryptedText = homomorphic.decrypt(cipherText1)

	cdef testDataConcept(self):
		cdef int ringDim = 1024
		cdef int slots = ringDim // 2
		cdef CythonHomomorphic homomorphic = self.setCryptoContext(ringDim, slots)

		startSetupTime = time.time()

		cdef vector[double] balance = [round(x, 2) for x in np.random.uniform(1.0, 1000.0, slots).tolist()]
		balanceCipher = homomorphic.encrypt(balance)

		birthDate = np.random.randint(100, 999, slots).tolist()
		birthDateSorter = sorted(enumerate(birthDate), key=lambda x: x[1])
		sortedIndex = [i for i, _ in birthDateSorter]
		sortedBirthDate = [value for _, value in birthDateSorter]
		birthCipher = homomorphic.encrypt(sortedBirthDate)

		startValue = random.choice(birthDate)
		print(startValue)
		stopValues = random.choice([value for value in birthDate if value > startValue])
		print(stopValues)
		dateToStart = [startValue] * slots
		dateToStop = [stopValues] * slots
		startDate = homomorphic.encrypt(dateToStart)
		endDate = homomorphic.encrypt(dateToStop)

		endSetupTime = time.time()        
		print("Setup time ->", endSetupTime - startSetupTime)

		startCompareTime = time.time()
		startResult = homomorphic.compare(slots, startDate, birthCipher)
		endResult = homomorphic.compare(slots, endDate, birthCipher)
		endCompareTime = time.time()
		print("Compare time ->", endCompareTime - startCompareTime)

		startIndices = next(i for i in range(slots) if startResult[i] == 1)
		endIndices = next(i for i in range(slots) if endResult[i] == 1)
		print("startIndices:", startIndices)
		print("endIndices:", endIndices)

		maskList = [1 if startIndices <= i <= endIndices else 0 for i in range(slots)]
		mask = homomorphic.encrypt(maskList)

		startTime = time.time()
		getBalance = homomorphic.maskCiphertext(slots, balanceCipher, mask)
		endTime = time.time()
		print("Mask time ->", endTime - startTime)

	cdef testBinarySearch(self):
		cdef int ringDim = 1024
		cdef int slots = ringDim // 2
		cdef CythonHomomorphic homomorphic = self.setCryptoContext(ringDim, slots)

		startSetupTime = time.time()

		cdef vector[double] balance = [round(x, 2) for x in np.random.uniform(1.0, 1000.0, slots).tolist()]
		balanceCipher = homomorphic.encrypt(balance)

		birthDate = np.random.randint(100, 999, slots).tolist()
		birthDateSorter = sorted(enumerate(birthDate), key=lambda x: x[1])
		birthDateIndex = [i for i, _ in birthDateSorter]
		sortedBirthDate = [value for _, value in birthDateSorter]
		birthCipher = homomorphic.encrypt(sortedBirthDate)

		startValue = random.choice(birthDate)
		dateToStart = [startValue]
		startDate = homomorphic.encrypt(dateToStart)

		endSetupTime = time.time()        
		print("Setup time ->", endSetupTime - startSetupTime)

		startSearchTime = time.time()
		left = 0
		right = slots - 1
		maskList = [0.0] * slots
		while left <= right:
			mid = (left + right) // 2
			maskList[mid] = 1.0

			mask = homomorphic.encrypt(maskList)
			maskedCipher = homomorphic.maskCiphertext(slots, birthCipher, mask)
			sumBirthCipher = homomorphic.sumCiphertext(slots, maskedCipher)

			result = homomorphic.compare(1, sumBirthCipher, startDate)

			if result[0] == 1.0:
				left = mid + 1
			else:
				right = mid - 1
			
			maskList[mid] = 0.0

		endSearchTime = time.time()        
		print("Search time ->", endSearchTime - startSearchTime)

		maskList2 = [1.0 if i==birthDateIndex[left] else 0.0 for i in range(slots)]
		mask2 = homomorphic.encrypt(maskList2)
		getBalance = homomorphic.maskCiphertext(slots, balanceCipher, mask2)

	cdef setCryptoContext(self, int ringDim, int slots):
		cdef int batchSize = slots 
		cdef int multiplicativeDepth = 17
		cdef int scalingModSize = 50
		cdef int firstModSize = 60
		cdef CythonHomomorphic homomorphic = CythonHomomorphic()

		homomorphic.initializeCKKS(multiplicativeDepth, scalingModSize, firstModSize, ringDim, batchSize)  
		homomorphic.setupSchemeSwitching(slots, 25)

		return homomorphic
		
	cdef testPeopleHomomorphic(self):
		cdef str resourcePath = self.getResourcePath()
		cdef str path = f'{resourcePath}/People.HE.bin'
		cdef StreamIOHandler io = StreamIOHandler(path)
		cdef PeopleHomomorphic storage = PeopleHomomorphic(io)
		cdef bint isNew = not os.path.isfile(path)
		cdef int n = self.option.count
		io.open()
		try:
			if isNew: storage.create()
			else: storage.readHeader(0)
			# peopleList = self.writePeople(storage)
			# storedList = self.readPeople(storage, peopleList)
			# self.comparePeople(peopleList, storedList)
			# storage.writeHeader()

		except:
			print(traceback.format_exc())
		io.close()

	cdef TextIntegerArray* toI32Array(self, str text):
		cdef bytes encoded = text.encode()
		cdef char *buffer = <char *> encoded
		cdef i32 length = len(encoded)
		cdef i32 arraySize = ((length >> 2) + 1) << 2
		cdef TextIntegerArray *array = <TextIntegerArray *> malloc(sizeof(TextIntegerArray))

		array.textLength = length
		array.arrayLength = (length >> 3) + 1
		array.array = <i32 *> malloc(arraySize)

		cdef i32 position = 0
		for i in range(array.arrayLength - 1):
			memcpy(<void *> (&array.array[i]), <void *> (buffer + position), 4)
			position += 4
		memcpy(array.array + (array.arrayLength - 1), buffer + position, length - position)
		return array

	cdef freeTextIntegerArray(self, TextIntegerArray* array):
		if array:
			if array.array:
				free(array.array) 
			free(array)

	cdef checkPath(self):
		cdef str resourcePath = self.getResourcePath()
		if not os.path.isdir(resourcePath): os.makedirs(resourcePath)

	cdef str getResourcePath(self):
		if IS_VENV: return f'{sys.prefix}/var/xtore'
		else: return '/var/xtore'

	@staticmethod
	def getConfig():
		return {}