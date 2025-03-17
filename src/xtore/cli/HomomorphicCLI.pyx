from xtore.BaseType cimport i32
from xtore.common.StreamIOHandler cimport StreamIOHandler
from xtore.instance.BasicStorage cimport BasicStorage
from xtore.instance.BasicIterator cimport BasicIterator
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

cdef class DataSet:
	cdef list birthDate
	cdef list balance
	cdef list index
	cdef Ciphertext birthCipher
	cdef Ciphertext balanceCipher

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
			'BinarySearch',
			'LinkPages',
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
		elif self.option.test == 'BinarySearch': self.testBinarySearch()
		elif self.option.test == 'LinkPages': self.testLinkPages()

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

	cdef testLinkPages(self):
		cdef int ringDim = 1024
		cdef int slots = 8
		cdef CythonHomomorphic homomorphic = self.setCryptoContext(ringDim, slots)

		startSetupTime = time.time()

		dataset1 = self.generateDataSet(homomorphic, slots)
		dataset2 = self.generateDataSet(homomorphic, slots)

		endSetupTime = time.time()        
		print("Setup time ->", endSetupTime - startSetupTime)

		mergedBirth = self.mergedBirth(homomorphic, slots, dataset1, dataset2)
		
		endSetupTime = time.time()        
		print("Compare time ->", endSetupTime - startSetupTime)
	
	cdef mergedBirth(self, CythonHomomorphic homomorphic, int slots, DataSet dataset1, DataSet dataset2):
		cdef list mergedOrderBirth = []
		cdef int i = 0
		cdef int j = 0

		while i < slots and j < slots:
			cipher1 = self.maskSum(homomorphic, slots, i, dataset1.birthCipher)
			cipher2 = self.maskSum(homomorphic, slots, j, dataset2.birthCipher)

			result = homomorphic.compare(1, cipher1, cipher2)

			if result[0] == 1.0:
				mergedOrderBirth.append((0,dataset1.index[i])) 
				i += 1
			else:
				mergedOrderBirth.append((1,dataset2.index[j])) 
				j += 1
		
		while i < slots:
			mergedOrderBirth.append((0,dataset1.index[i]))
			i += 1

		while j < slots:
			mergedOrderBirth.append((1,dataset2.index[j])) 
			j += 1

		return mergedOrderBirth



	cdef DataSet generateDataSet(self, CythonHomomorphic homomorphic, int slots):
		cdef vector[double] balance = self.randomData(slots, "float")
		balanceCipher = homomorphic.encrypt(balance)

		cdef birthDate = self.randomData(slots, "int")
		birthDateSorter = sorted(enumerate(birthDate), key=lambda x: x[1])
		birthDateIndex, sortedBirthDate = zip(*birthDateSorter)  
		birthDateIndex = list(birthDateIndex)
		sortedBirthDate = list(sortedBirthDate)

		cdef Ciphertext birthCipher = homomorphic.encrypt(sortedBirthDate)

		cdef DataSet dataset = DataSet()
		dataset.balance = balance
		dataset.birthDate = birthDate
		dataset.index = birthDateIndex
		dataset.birthCipher = birthCipher
		dataset.balanceCipher = balanceCipher

		return dataset

	def randomData(self, int slots, str dataType):
		if dataType == "int":
			return np.random.randint(100, 999, slots).tolist()
		elif dataType == "float":
			return [round(x, 2) for x in np.random.uniform(1.0, 1000.0, slots).tolist()]

	cdef testDataConcept(self):
		cdef int ringDim = 1024
		cdef int slots = 8
		cdef CythonHomomorphic homomorphic = self.setCryptoContext(ringDim, slots)

		startSetupTime = time.time()

		cdef vector[double] balance = [round(x, 2) for x in np.random.uniform(1.0, 1000.0, slots).tolist()]
		birthDate = np.random.randint(100, 999, slots).tolist()

		birthDateSorter = sorted(enumerate(birthDate), key=lambda x: x[1])
		sortedIndex = [i for i, _ in birthDateSorter]
		sortedBirthDate = [value for _, value in birthDateSorter]

		balanceCipher = homomorphic.encrypt(balance)
		birthCipher = homomorphic.encrypt(sortedBirthDate)
		print(birthDate)
		print(balance)
		print(sortedIndex)

		startValue = random.choice([value for value in birthDate if value != sortedBirthDate[slots - 3]])
		print(startValue)
		stopValues = random.choice([value for value in birthDate if value > startValue and value != sortedBirthDate[slots - 1]])
		print(stopValues)

		dateToStart = homomorphic.encrypt([startValue] * slots)
		dateToStop = homomorphic.encrypt([stopValues] * slots)

		endSetupTime = time.time()        
		print("Setup time ->", endSetupTime - startSetupTime)

		startCompareTime = time.time()
		startCompareResult = homomorphic.compare(slots, dateToStart, birthCipher)
		endCompareResult = homomorphic.compare(slots, dateToStop, birthCipher)
		endCompareTime = time.time()
		print("Compare time ->", endCompareTime - startCompareTime)

		startIndices = next(i for i in range(slots) if startCompareResult[i] == 1)
		endIndices = next(i for i in range(slots) if endCompareResult[i] == 1)
		print("startIndices:", startIndices)
		print("endIndices:", endIndices)

		maskList = [1 if startIndices <= i <= endIndices else 0 for i in range(slots)]
		mask = homomorphic.encrypt(maskList)

		startTime = time.time()
		maskBalance = homomorphic.maskCiphertext(slots, balanceCipher, mask)
		endTime = time.time()
		print("Mask time ->", endTime - startTime)

		maskValue = homomorphic.getMaskValue(slots, maskBalance)
		print(maskValue)

	cdef testBinarySearch(self):
		cdef int ringDim = 1024
		cdef int slots = 8
		cdef CythonHomomorphic homomorphic = self.setCryptoContext(ringDim, slots)

		startSetupTime = time.time()

		cdef vector[double] balance = [round(x, 2) for x in np.random.uniform(1.0, 1000.0, slots).tolist()]
		balanceCipher = homomorphic.encrypt(balance)

		birthDate = np.random.randint(100, 999, slots).tolist()
		birthDateSorter = sorted(enumerate(birthDate), key=lambda x: x[1])
		birthDateIndex, sortedBirthDate = zip(*birthDateSorter)  
		birthDateIndex, sortedBirthDate = list(birthDateIndex), list(sortedBirthDate)  
		birthCipher = homomorphic.encrypt(sortedBirthDate)
		print(birthDate)
		print(balance)

		startValue = random.choice([value for value in birthDate if value < sortedBirthDate[slots - 2]])
		stopValues = random.choice([value for value in birthDate if value > startValue and value < sortedBirthDate[slots - 1]]) 
		
		print(startValue)
		
		dateToStart = homomorphic.encrypt([startValue])
		dateToStop = homomorphic.encrypt([stopValues])

		endSetupTime = time.time()        
		print("Setup time ->", endSetupTime - startSetupTime)

		startSearchTime = time.time()
		foundIndex = self.binarySearch(homomorphic, slots, birthCipher, dateToStart)
		endSearchTime = time.time()
		print("Search time ->", endSearchTime - startSearchTime)

		print(foundIndex)
		print(birthDateIndex)
		
		maskList = [1.0 if i == birthDateIndex[foundIndex] else 0.0 for i in range(slots)]
		maskList[birthDateIndex[foundIndex]] = 1.0
		mask = homomorphic.encrypt(maskList)
		maskBalance = homomorphic.maskCiphertext(slots, balanceCipher, mask)
		maskValue = homomorphic.getMaskValue(slots, maskBalance)
		print(round(maskValue[birthDateIndex[foundIndex]], 2))

	cdef binarySearch(self, CythonHomomorphic homomorphic, int slots, Ciphertext birthCipher, Ciphertext selectedDate):
		cdef int left = 0
		cdef int right = slots - 1
		cdef list maskList = [0.0] * slots

		while left <= right:
			mid = (left + right) // 2

			sumCiphertext = self.maskSum(homomorphic, slots,  mid,  birthCipher)
			result = homomorphic.compare(1, sumCiphertext, selectedDate)

			if result[0] == 1.0:
				left = mid + 1
			else:
				right = mid - 1

			maskList[mid] = 0.0  

		return left 

	cdef Ciphertext maskSum(self, CythonHomomorphic homomorphic, int slots, int index, Ciphertext ciphertext):
		maskList = [0.0] * slots  
		maskList[index] = 1.0

		mask = homomorphic.encrypt(maskList)
		maskedCipher = homomorphic.maskCiphertext(slots, ciphertext, mask)
		
		return homomorphic.sumCiphertext(slots, maskedCipher)

	cdef setCryptoContext(self, int ringDim, int slots):
		cdef int batchSize = slots 
		cdef int multiplicativeDepth = 17
		cdef int scalingModSize = 50
		cdef int firstModSize = 60
		cdef CythonHomomorphic homomorphic = CythonHomomorphic()

		homomorphic.initializeCKKS(multiplicativeDepth, scalingModSize, firstModSize, ringDim, batchSize)  
		homomorphic.setupSchemeSwitching(slots, 25)

		return homomorphic

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