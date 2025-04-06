from xtore.BaseType cimport i32, i64
from xtore.common.StreamIOHandler cimport StreamIOHandler
from xtore.common.Buffer cimport Buffer, initBuffer, getBuffer, setBuffer, releaseBuffer
from xtore.common.ChunkedBuffer cimport ChunkedBuffer
from xtore.instance.BasicStorage cimport BasicStorage
from xtore.instance.BasicIterator cimport BasicIterator
from xtore.test.DataSetHomomorphic cimport DataSetHomomorphic
from xtore.test.DataSet cimport DataSet

from libc.stdlib cimport malloc, free
from libc.string cimport memcpy
from libcpp.vector cimport vector
from argparse import RawTextHelpFormatter

from xtore.instance.HomomorphicBSTStorage import HomomorphicBSTStorage
from xtore.base.CythonHomomorphic cimport CythonHomomorphic, Ciphertext, Plaintext
from libcpp.vector cimport vector
from cpython.bytes cimport PyBytes_FromStringAndSize

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
			'Concept',
			'BinarySearch',
		])
		self.parser.add_argument("-n", "--count", help="Number of record to test.", required=False, type=int)
		self.option = self.parser.parse_args(argv)

	cdef run(self, list argv):
		self.getParser(argv)  
		self.checkPath()  
		if self.option.test == 'BST': self.testDataSetBSTStorage()
		elif self.option.test == 'Concept': self.testDataConcept()
		elif self.option.test == 'BinarySearch': self.testBinarySearch()

	cdef i64 StreamIO(self):
		cdef str path = f'{self.getResourcePath()}/test_data.bin'
		cdef int ringDim = 1024
		cdef int slots = 2
		cdef CythonHomomorphic homomorphic = self.setCryptoContext(ringDim, slots)
		cdef EncryptedData data = self.generateData(homomorphic, slots)

		print("Writing encrypted data...")
		cdef i64 dataAddress = self.writeEncryptedDataWithStream(path, data, homomorphic)

		return dataAddress

		# print("Reading encrypted data...")
		# cdef Ciphertext readBirthCipher = self.readEncryptedDataWithStream(path, homomorphic)
		# cdef Plaintext plaintext = homomorphic.decrypt(readBirthCipher)

	cdef i64 writeEncryptedDataWithStream(self, str path, EncryptedData data, CythonHomomorphic homomorphic):
		cdef StreamIOHandler io = StreamIOHandler(path)
		cdef i64 address
		cdef Buffer writeBuffer
		cdef bytes serializedData
		cdef list positionList = []

		io.open()
		try:
			position1 = io.getTail()
			print(f"start ddress: {position1}")
			positionList.append(position1)
			serializedData = homomorphic.serializeToStream(data.idCipher)
			initBuffer(&writeBuffer, <char*> serializedData, len(serializedData))
			writeBuffer.position = len(serializedData)
			io.write(&writeBuffer)

			position2 = io.getTail()
			positionList.append(position2)
			serializedData = homomorphic.serializeToStream(data.birthCipher)
			initBuffer(&writeBuffer, <char*> serializedData, len(serializedData))
			writeBuffer.position = len(serializedData)
			io.write(&writeBuffer)

			position3 = io.getTail()
			positionList.append(position3)
			serializedData = homomorphic.serializeToStream(data.balanceCipher)
			initBuffer(&writeBuffer, <char*> serializedData, len(serializedData))
			writeBuffer.position = len(serializedData)
			io.write(&writeBuffer)

			for position in reversed(positionList):
				address = position
				print(f"address: {address}")
				initBuffer(&writeBuffer, <char*>&address, sizeof(i64))
				writeBuffer.position = sizeof(i64)
				io.write(&writeBuffer)

			dataAddress = io.getTail()
			print(f"end address: {dataAddress}")

			return dataAddress

		finally:
			io.close()
	
	cdef Ciphertext readEncryptedDataWithStream(self, str path, CythonHomomorphic homomorphic):
		cdef StreamIOHandler io = StreamIOHandler(path)
		cdef i32 offset
		cdef Buffer readBuffer
		cdef Ciphertext ciphertext
		cdef bytes serializedData
		cdef size_t data_size
		cdef char* buffer_memory
		
		io.open()
		try:
			file_size = io.getTail()
			buffer_memory = <char*>malloc(sizeof(i32))
			if buffer_memory == NULL:
				raise MemoryError("Failed to allocate memory for offset")

			initBuffer(&readBuffer, buffer_memory, sizeof(i32))
			io.seek(file_size - sizeof(i32))
			io.read(&readBuffer, sizeof(i32))
			offset = (<i32*> readBuffer.buffer)[0]
			print(f"Read offset: {offset}, file size: {file_size}")

			data_size = file_size - offset - sizeof(i32)

			io.seek(offset)

			buffer_memory = <char*>malloc(data_size)
			if buffer_memory == NULL:
				raise MemoryError("Failed to allocate memory for buffer")

			initBuffer(&readBuffer, buffer_memory, data_size)
			io.read(&readBuffer, data_size)
			
			serializedData = PyBytes_FromStringAndSize(readBuffer.buffer, data_size)
			ciphertext = homomorphic.deserializeFromStream(serializedData)
			
			return ciphertext
			
		finally:
			releaseBuffer(&readBuffer)
			io.close()
		
	cdef testDataSetBSTStorage(self):
		cdef str resourcePath = self.getResourcePath()
		cdef str path = f'{resourcePath}/DataSet.BST.bin'
		cdef StreamIOHandler io = StreamIOHandler(path)
		cdef DataSetHomomorphic storage = DataSetHomomorphic(io)
		cdef bint isNew = not os.path.isfile(path)
		cdef i64 address = self.StreamIO()
		io.open()
		try:
			if isNew: storage.create()
			else: storage.readHeader(0)
			dataList = self.writeDataSet(storage, address)
			storedList = self.readPeople(storage, dataList)
			print(storedList)
			# self.comparePeople(peopleList, storedList)
			storage.writeHeader()
		except:
			print(traceback.format_exc())
		io.close()
	
	cdef list writeDataSet(self, BasicStorage storage, i32 address):
		cdef list dataList = []
		cdef DataSet dataSet
		cdef int i
		cdef int n = self.option.count
		cdef double start = time.time()
		for i in range(n):
			dataSet = DataSet()
			dataSet.position = -1
			dataSet.index = i
			dataSet.address = address
			dataList.append(dataSet)
		cdef double elapsed = time.time() - start
		print(f'>>> Data of {n} are generated in {elapsed:.3}s')
		start = time.time()
		for dataSet in dataList:
			storage.set(dataSet)
		elapsed = time.time() - start
		print(f'>>> Data of {n} are stored in {elapsed:.3}s ({(n/elapsed)} r/s)')
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
		print(f'>>> People Data of {n} are read in {elapsed:.3}s ({(n/elapsed)} r/s)')
		return storedList

	cdef EncryptedData generateData(self, CythonHomomorphic homomorphic, int slots):
		cdef list id = self.randomData(slots, "int")
		cdef list name = self.randomData(slots, "int")
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
