from xtore.BaseType cimport i32, i64
from xtore.common.StreamIOHandler cimport StreamIOHandler
from xtore.common.Buffer cimport Buffer, initBuffer, releaseBuffer
from xtore.common.ChunkedBuffer cimport ChunkedBuffer
from xtore.instance.BasicStorage cimport BasicStorage
from xtore.test.DataSetHomomorphic cimport DataSetHomomorphic
from xtore.test.DataSet cimport DataSet

from libc.stdlib cimport malloc, free
from libc.string cimport memcpy
from libcpp.vector cimport vector
from argparse import RawTextHelpFormatter

from xtore.instance.HomomorphicBSTStorage cimport HomomorphicBSTStorage
from xtore.base.CythonHomomorphic cimport CythonHomomorphic, Ciphertext
from libcpp.vector cimport vector
from cpython.bytes cimport PyBytes_FromStringAndSize
import numpy as np
import sys, time, os, traceback, random, argparse

cdef str __help__ = "Test Script for Homomorphic"
cdef bint IS_VENV = sys.prefix != sys.base_prefix
def run():
	cli = HomomorphicCLI()       
	cli.run(sys.argv[1:])

cdef class Data:
	cdef list id
	cdef list name
	cdef list birthDate
	cdef list address
	cdef list balance

cdef class EncryptedData:
	cdef Ciphertext idCipher
	cdef Ciphertext nameCipher
	cdef Ciphertext birthCipher
	cdef Ciphertext addressCipher
	cdef Ciphertext balanceCipher

	cdef list getCipherAttributes(self):
		return ['idCipher', 'nameCipher', 'birthCipher', 'addressCipher', 'balanceCipher']

	cdef Ciphertext getCipher(self, str attrName):
		if attrName == 'idCipher':
			return self.idCipher
		elif attrName == 'nameCipher':
			return self.nameCipher
		elif attrName == 'birthCipher':
			return self.birthCipher
		elif attrName == 'addressCipher':
			return self.addressCipher
		elif attrName == 'balanceCipher':
			return self.balanceCipher
		else:
			raise ValueError(f"Unknown cipher attribute: {attrName}")

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
		])
		self.parser.add_argument("-n", "--count", help="Number of record to test.", required=False, type=int)
		self.option = self.parser.parse_args(argv)

	cdef run(self, list argv):
		self.getParser(argv)  
		self.checkPath()  
		if self.option.test == 'BST': self.testDataSetBSTStorage()
		
	cdef i64 StreamIO(self):
		cdef str path = f'{self.getResourcePath()}/test_data.bin'
		cdef int ringDim = 1024
		cdef int slots = 8
		cdef CythonHomomorphic homomorphic = self.setCryptoContext(ringDim, slots, path)
		cdef EncryptedData data = self.generateData(homomorphic, slots)

		print("Writing encrypted data...")
		cdef i64 dataAddress = self.writeEncryptedDataWithStream(path, data, homomorphic)

		return dataAddress

	cdef i64 writeEncryptedDataWithStream(self, str path, EncryptedData data, CythonHomomorphic homomorphic):
		cdef StreamIOHandler io = StreamIOHandler(path)
		cdef i64 offset
		cdef Buffer writeBuffer
		cdef bytes serializedData
		cdef list positionList = []
		cdef list attributeNames = data.getCipherAttributes()
		cdef int numAttributes = len(attributeNames)
		cdef Ciphertext cipher

		io.open()
		try:
			for attrName in attributeNames:
				position = io.getTail()
				positionList.append(position)
				cipher = data.getCipher(attrName)
				serializedData = homomorphic.serializeToStream(cipher)
				initBuffer(&writeBuffer, <char*> serializedData, len(serializedData))
				writeBuffer.position = len(serializedData)
				io.write(&writeBuffer)

			fileSize = io.getTail() + numAttributes * sizeof(i64)

			for position in reversed(positionList):
				offset = fileSize - position
				initBuffer(&writeBuffer, <char*>&offset, sizeof(i64))
				writeBuffer.position = sizeof(i64)
				io.write(&writeBuffer)

			dataAddress = io.getTail()
			return dataAddress

		finally:
			io.close()

	cdef testDataSetBSTStorage(self):
		cdef str BSTPath = f'{self.getResourcePath()}/DataSet.BST.bin'
		cdef str dataPath = f'{self.getResourcePath()}/testData.bin'
		cdef str contextPath = f'{self.getResourcePath()}/context.bin'
		cdef StreamIOHandler io = StreamIOHandler(BSTPath)
		cdef DataSetHomomorphic storage = DataSetHomomorphic(io)
		cdef bint isNew = not os.path.isfile(BSTPath)
		cdef i32 ringDim = 1024
		cdef i32 slots = 8
		cdef CythonHomomorphic homomorphic = self.setCryptoContext(ringDim, slots, contextPath)
		cdef EncryptedData data = self.generateData(homomorphic, slots)

		cdef int low = 200
		cdef int high = 700
		cdef int threshold = 500
		
		print("Writing encrypted data...")
		cdef i64 address = self.writeEncryptedDataWithStream(dataPath, data, homomorphic)

		io.open()
		try:
			if isNew: storage.create()
			else: storage.readHeader(0)
			dataList = self.writeDataSet(storage, address, homomorphic, slots)
			# print("dataList", dataList)
			print()

			# storedList = self.readPeople(storage, dataList)
			# print("storedList", storedList)
			# print()
	
			resultList = self.readRangeData(storage, dataList, homomorphic, low, high)
			print("resultList", resultList)
			print()

			greaterList = self.readGreater(storage, dataList, homomorphic, threshold)
			print("greaterList", greaterList)
			print()

			lesserList = self.readLesser(storage, dataList, homomorphic, threshold)
			print("lesserList", lesserList)
			print()

			storage.writeHeader()
			
		except:
			print(traceback.format_exc())
		io.close()
	
	cdef list writeDataSet(self, BasicStorage storage, i32 address, CythonHomomorphic homomorphic, i32 slots):
		cdef list dataList = []
		cdef DataSet dataSet
		cdef int i
		cdef double start = time.time()
		for i in range(slots):
			dataSet = DataSet()
			dataSet.position = -1
			dataSet.index = i
			dataSet.address = address
			dataSet.homomorphic = homomorphic
			dataList.append(dataSet)
		cdef double elapsed = time.time() - start
		print(f'>>> Data of {slots} are generated in {elapsed:.3}s')
		start = time.time()
		for dataSet in dataList:
			storage.set(dataSet)
		elapsed = time.time() - start
		print(f'>>> Data of {slots} are stored in {elapsed:.3}s ({(slots/elapsed)} r/s)')
		return dataList

	cdef list readPeople(self, BasicStorage storage, list dataList):
		cdef list storedList = []
		cdef DataSet stored
		cdef double start = time.time()
		for dataSet in dataList:
			stored = storage.get(dataSet, None)
			storedList.append(stored)
		cdef double elapsed = time.time() - start
		cdef int n = len(dataList)
		print(f'>>> Data of {n} are read in {elapsed:.3}s ({(n/elapsed)} r/s)')
		return storedList

	cdef readRangeData(self, HomomorphicBSTStorage storage, list dataList, CythonHomomorphic homomorphic, int low, int high):
		# cdef DataSet dataSet
		# dataSet = DataSet()
		# dataSet.position = 8
		# dataSet.index = 0
		# dataSet.address = 1748135
		# dataSet.homomorphic = homomorphic

		dataSet = dataList[0]

		cdef double start = time.time()
		resultList = storage.getRangeData(dataSet, low, high)
		cdef double elapsed = time.time() - start

		cdef int n = len(resultList)
		print(f'>>> Data {n} records are read (from {low} to {high}) in {elapsed:.3}s ({(n/elapsed)} r/s)')
		return resultList

	cdef readGreater(self, HomomorphicBSTStorage storage, list dataList, CythonHomomorphic homomorphic, int threshold):
		dataSet = dataList[0]

		cdef double start = time.time()
		resultList = storage.getGreater(dataSet, threshold)
		cdef double elapsed = time.time() - start

		cdef int n = len(resultList)
		print(f'>>> Data {n} records (that > {threshold})  are read in {elapsed:.3}s ({(n/elapsed)} r/s)')
		return resultList

	cdef readLesser(self, HomomorphicBSTStorage storage, list dataList, CythonHomomorphic homomorphic, int threshold):
		dataSet = dataList[0]

		cdef double start = time.time()
		resultList = storage.getLesser(dataSet, threshold)
		cdef double elapsed = time.time() - start

		cdef int n = len(resultList)
		print(f'>>> {n} records (that < {threshold}) are read in {elapsed:.3}s ({(n/elapsed)} r/s)')
		return resultList

	cdef EncryptedData generateData(self, CythonHomomorphic homomorphic, int slots):
		cdef list id = self.randomData(slots, "int")
		# cdef list name = self.randomData(slots, "int")
		# cdef list name = [724, 131, 854, 295, 225, 727, 421, 285, 100, 400, 200, 123, 456, 600, 298, 975]
		# cdef list name = [724, 131, 854, 295, 225, 727, 421, 285]
		cdef list name = [ 100, 400, 210, 123, 556, 600, 298, 975]
		print("name:", name)

		cdef list birthDate = self.randomData(slots, "int")
		cdef list address = self.randomData(slots, "int")
		cdef vector[double] balance = self.randomData(slots, "float")

		cdef Ciphertext idCipher = homomorphic.encrypt(id)
		cdef Ciphertext nameCipher = homomorphic.encrypt(name)
		cdef Ciphertext birthCipher = homomorphic.encrypt(birthDate)
		cdef Ciphertext addressCipher = homomorphic.encrypt(address)
		cdef Ciphertext balanceCipher = homomorphic.encrypt(balance)

		cdef Data data = Data()
		data.id = id
		data.name = name
		data.address = address
		data.balance = balance
		data.birthDate = birthDate

		cdef EncryptedData encryptedData = EncryptedData()
		encryptedData.idCipher = idCipher
		encryptedData.nameCipher = nameCipher
		encryptedData.addressCipher = addressCipher
		encryptedData.birthCipher = birthCipher
		encryptedData.balanceCipher = balanceCipher

		return encryptedData

	def randomData(self, int slots, str dataType):
		if dataType == "int":
			return np.random.randint(100, 999, slots).tolist()
		elif dataType == "float":
			return [round(x, 2) for x in np.random.uniform(1.0, 1000.0, slots).tolist()]

	cdef CythonHomomorphic setCryptoContext(self, int ringDim, int slots, str path):
		cdef int batchSize = slots 
		cdef int multiplicativeDepth = 17
		cdef int scalingModSize = 50
		cdef int firstModSize = 60
		cdef CythonHomomorphic homomorphic = CythonHomomorphic()
		cdef str context_path = path if path else f'{self.getResourcePath()}/context.bin'

		homomorphic.initializeCKKS(multiplicativeDepth, scalingModSize, firstModSize, ringDim, batchSize, context_path)  

		return homomorphic

	cdef checkPath(self):
		cdef str resourcePath = self.getResourcePath()
		if not os.path.isdir(resourcePath): os.makedirs(resourcePath)

	cdef str getResourcePath(self):
		if IS_VENV: return f'{sys.prefix}/var/xtore'
		else: return '/var/xtore'

	@staticmethod
	def getConfig():
		return {}
