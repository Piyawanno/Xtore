from xtore.BaseType cimport i32
from xtore.base.CythonHomomorphic cimport CythonHomomorphic, Ciphertext

from libc.stdlib cimport malloc, free
from libc.string cimport memcpy
from libcpp.vector cimport vector
from argparse import RawTextHelpFormatter
from faker import Faker

import os, sys, argparse, traceback, random, time
import numpy as np

cdef str __help__ = "Test Script for Homomorphic"
cdef bint IS_VENV = sys.prefix != sys.base_prefix
def run():
	cli = HomomorphicCLI()       
	cli.run(sys.argv[1:])

ctypedef struct TextIntegerArray:
	i32 textLength
	i32 arrayLength
	i32 *array

cdef class Data:
	cdef list birthDate
	cdef list balance
	cdef list index
	cdef Ciphertext birthCipher
	cdef Ciphertext balanceCipher

cdef class SetPosition:
	cdef list index
	cdef Ciphertext birthCipher

cdef class HomomorphicCLI:
	cdef object parser
	cdef object option
	cdef object config

	def __init__(self):
		self.config = self.getConfig() 

	def getParser(self, list argv):
		self.parser = argparse.ArgumentParser(description=__help__, formatter_class=RawTextHelpFormatter)
		self.parser.add_argument("test", help="Name of test", choices=[
			'BST',
			'Homomorphic',
			'Wrapper',
			'Concept',
			'BinarySearch',
			'LinkPages',
			'Rotation',
		])
		self.parser.add_argument("-n", "--count", help="Number of record to test.", required=False, type=int)
		self.option = self.parser.parse_args(argv)

	cdef run(self, list argv):
		self.getParser(argv)  
		self.checkPath()  
		if self.option.test == 'BST': self.testHomomorphicBSTStorage()
		elif self.option.test == 'Homomorphic': self.testHomomorphic()
		elif self.option.test == 'Wrapper': self.testHomomorphic()
		elif self.option.test == 'Concept': self.testDataConcept()
		elif self.option.test == 'BinarySearch': self.testBinarySearch()
		elif self.option.test == 'LinkPages': self.testLinkPages()
		elif self.option.test == 'Rotation': self.testRotation()

	cdef setCryptoContext(self, int ringDim, int slots):
		cdef int batchSize = slots 
		cdef int multiplicativeDepth = 17
		cdef int scalingModSize = 50
		cdef int firstModSize = 60
		cdef CythonHomomorphic homomorphic = CythonHomomorphic()

		homomorphic.initializeCKKS(multiplicativeDepth, scalingModSize, firstModSize, ringDim, batchSize)  
		homomorphic.setupSchemeSwitching(slots, 25)

		return homomorphic

	cdef testHomomorphicBSTStorage(self):
		cdef int ringDim = 1024
		cdef int slots = 4
		cdef CythonHomomorphic homomorphic = self.setCryptoContext(ringDim, slots)

		cdef int count = 2
		cdef list datasets = []
		cdef Data newData
		cdef Data bd
		cdef list mergedBirthList = []
		cdef list mergedBirthBSTList = []
		cdef Data datasetToMask

		start = time.time()
		for i in range(count):
			datasets.append(self.generateData(homomorphic, slots))
			newData = datasets[i]
			mergedBirthList = self.mergedBirth(homomorphic, slots, mergedBirthList, datasets, newData)
		endtime = time.time()

		print(f"insert {count}datasets Time ->", endtime - start)

		print("mergedBirthList slots:",len(mergedBirthList))
		print("mergedBirthList:",mergedBirthList)
		print()

		selectedBirthDate = self.selectRandomBirthDate(datasets)
		print(f"Randomly selected birthDate: {selectedBirthDate}")

		selectedDateCipher = homomorphic.encrypt([selectedBirthDate])
		foundIndex = self.binarySearch(homomorphic, slots, mergedBirthList, datasets, selectedDateCipher)
		print(f"Found mergedList index: {foundIndex}")
		print("Found birthDate index:", mergedBirthList[foundIndex])

		setNum, maskIndex = mergedBirthList[foundIndex]
		datasetToMask = datasets[setNum]
		
		getBalanceCipher = homomorphic.extractSlot(slots, maskIndex, datasetToMask.balanceCipher)
		print("balance:", homomorphic.getRealValue(slots, getBalanceCipher)[0])

		print()
		for i in range(len(datasets)):
			bd = datasets[i]
			print(f"birthDate[{i}]",bd.birthDate)
			print(f"balance[{i}]",bd.balance)
			print()

	cdef mergedBirth(self, CythonHomomorphic homomorphic, int slots, list mergedBirthList, list datasets, Data newData):
		cdef list updatedMergedBirthList = []
		cdef int i = 0
		cdef int j = 0
		cdef int n = len(mergedBirthList)
		cdef Data data
		cdef Ciphertext extractedDataToCompare
		cdef Ciphertext extractedNewData

		cdef int compareCouter = 0

		if n == 0:
			return [(0, newData.index[j]) for j in range(slots)]
		try:
			while i < n and j < slots:
				setNum, originalIndex = mergedBirthList[i]
				data = datasets[setNum]
				# print("i:", i,"si:",setNum, originalIndex,"index:", data.index)
				sortedPosition = data.index.index(originalIndex)
				extractedDataToCompare = homomorphic.extractSlot(slots, sortedPosition, data.birthCipher)
				extractedNewData = homomorphic.extractSlot(slots, j, newData.birthCipher)

				result = homomorphic.compare(1, extractedDataToCompare, extractedNewData)
				compareCouter += 1
				# print(f"Comparing {homomorphic.getRealValue(slots, extractedDataToCompare)[0]} vs {homomorphic.getRealValue(slots, extractedNewData)[0]} -> {result[0]}")

				if result[0] == 1.0:
					updatedMergedBirthList.append(mergedBirthList[i])
					i += 1
				else:
					updatedMergedBirthList.append((len(datasets)-1, newData.index[j]))
					j += 1

			while i < n:
				updatedMergedBirthList.append(mergedBirthList[i])
				i += 1

			while j < slots:
				updatedMergedBirthList.append((len(datasets)-1, newData.index[j]))
				j += 1

		except Exception as e:
			print(f"Error during merging: {str(e)}")
			raise

		# print(f"Comparing {compareCouter} times")

		return updatedMergedBirthList

	cdef selectRandomBirthDate(self, list datasets):
		cdef Data selectedData = random.choice(datasets)
		cdef list selectedBirthDate = selectedData.birthDate
		cdef int randomIndex = random.randint(0, len(selectedBirthDate) - 1)
		return selectedBirthDate[randomIndex]

	cdef binarySearch(self, CythonHomomorphic homomorphic, int slots, list mergedBirth, list datasets, Ciphertext selectedDate):
		cdef int left = 0
		cdef int right = len(mergedBirth) - 1
		cdef int mid
		cdef int setNum
		cdef int originalIndex
		cdef Data data
		cdef Ciphertext extractedDataToCompare

		while left <= right:
			mid = (left + right) // 2
			setNum, originalIndex = mergedBirth[mid]
			data = datasets[setNum]
			sortedPosition = data.index.index(originalIndex)
			extractedDataToCompare = homomorphic.extractSlot(slots, sortedPosition, data.birthCipher)

			result = homomorphic.compare(1, extractedDataToCompare, selectedDate)

			if result[0] == 1.0:
				left = mid + 1
			else:
				right = mid - 1

		return left

	cdef testRotation(self):
		cdef int ringDim = 1024
		cdef int slots = 16
		cdef CythonHomomorphic homomorphic = self.setCryptoContext(ringDim, slots)
		homomorphic.generateRotateKey(slots)

		Data1 = self.generateData(homomorphic, slots)
		birthCipher = homomorphic.encrypt(Data1.birthDate)

		print(Data1.birthDate)

		index = 13

		rotatedCipher = homomorphic.rotateCipher(index, birthCipher)
		rotadedValue = homomorphic.getRealValue(slots, rotatedCipher)
		print([f"{x:.2f}" for x in rotadedValue])

	cdef testLinkPages(self):
		cdef int ringDim = 1024
		cdef int slots = 8
		cdef CythonHomomorphic homomorphic = self.setCryptoContext(ringDim, slots)

		startSetupTime = time.time()

		Data1 = self.generateData(homomorphic, slots)
		Data2 = self.generateData(homomorphic, slots)

		endSetupTime = time.time()        
		print("Setup time ->", endSetupTime - startSetupTime)

		startCompareTime = time.time()

		mergedBirth = self.mergedTwoBirth(homomorphic, slots, Data1, Data2)
		
		endCompareTime = time.time()        
		print("Compare time ->", endCompareTime - startCompareTime)
	
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

		maskValue = homomorphic.getRealValue(slots, maskBalance)
		print(maskValue)

	cdef testBinarySearch(self):
		cdef int ringDim = 1024
		cdef int slots = 16
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
		# print(balance)

		startValue = random.choice([value for value in birthDate if value < sortedBirthDate[slots - 2]])
		stopValues = random.choice([value for value in birthDate if value > startValue and value < sortedBirthDate[slots - 1]]) 
		
		print(startValue)
		
		dateToStart = homomorphic.encrypt([startValue])
		dateToStop = homomorphic.encrypt([stopValues])

		endSetupTime = time.time()        
		print("Setup time ->", endSetupTime - startSetupTime)

		startSearchTime = time.time()
		foundIndex = self.binarySearchCipher(homomorphic, slots, birthCipher, dateToStart)
		endSearchTime = time.time()
		print("Search time ->", endSearchTime - startSearchTime)

		print(foundIndex)
		
		maskList = [1.0 if i == birthDateIndex[foundIndex] else 0.0 for i in range(slots)]
		maskList[birthDateIndex[foundIndex]] = 1.0
		mask = homomorphic.encrypt(maskList)
		maskBalance = homomorphic.maskCiphertext(slots, balanceCipher, mask)
		maskValue = homomorphic.getRealValue(slots, maskBalance)
		print(round(maskValue[birthDateIndex[foundIndex]], 2))


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

	cdef Data generateData(self, CythonHomomorphic homomorphic, int slots):
		cdef vector[double] balance = self.randomData(slots, "float")
		balanceCipher = homomorphic.encrypt(balance)

		cdef birthDate = self.randomData(slots, "int")
		birthDateSorter = sorted(enumerate(birthDate), key=lambda x: x[1])
		birthDateIndex, sortedBirthDate = zip(*birthDateSorter)  
		birthDateIndex = list(birthDateIndex)
		sortedBirthDate = list(sortedBirthDate)

		cdef Ciphertext birthCipher = homomorphic.encrypt(sortedBirthDate)

		cdef Data data = Data()
		data.balance = balance
		data.birthDate = birthDate
		data.index = birthDateIndex
		data.birthCipher = birthCipher
		data.balanceCipher = balanceCipher

		return data

	def randomData(self, int slots, str dataType):
		if dataType == "int":
			return np.random.randint(100, 999, slots).tolist()
		elif dataType == "float":
			return [round(x, 2) for x in np.random.uniform(1.0, 1000.0, slots).tolist()]
			
	cdef binarySearchCipher(self, CythonHomomorphic homomorphic, int slots, Ciphertext birthCipher, Ciphertext selectedDate):
		cdef int left = 0
		cdef int right = slots - 1
		cdef list maskList = [0.0] * slots

		while left <= right:
			mid = (left + right) // 2
			rotatedCipher = homomorphic.rotateCipher(mid, birthCipher)

			rotatedValue = homomorphic.getRealValue(slots,rotatedCipher)
			result = homomorphic.compare(1, rotatedCipher, selectedDate)

			if result[0] == 1.0:
				left = mid + 1
			else:
				right = mid - 1

			maskList[mid] = 0.0  

		return left 
		
	cdef mergedTwoBirth(self, CythonHomomorphic homomorphic, int slots, Data Data1, Data Data2):
		cdef list mergedOrderBirth = []
		cdef int i = 0
		cdef int j = 0

		while i < slots and j < slots:
			cipher1 = homomorphic.extractSlot(slots, i, Data1.birthCipher)
			cipher2 = homomorphic.extractSlot(slots, j, Data2.birthCipher)	

			result = homomorphic.compare(1, cipher1, cipher2)

			if result[0] == 1.0:
				mergedOrderBirth.append((0,Data1.index[i])) 
				i += 1
			else:
				mergedOrderBirth.append((1,Data2.index[j])) 
				j += 1
		
		while i < slots:
			mergedOrderBirth.append((0,Data1.index[i]))
			i += 1

		while j < slots:
			mergedOrderBirth.append((1,Data2.index[j])) 
			j += 1

		return mergedOrderBirth

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
