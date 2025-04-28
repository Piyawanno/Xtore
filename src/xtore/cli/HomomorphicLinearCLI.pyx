from xtore.BaseType cimport i32, i64
from xtore.common.StreamIOHandler cimport StreamIOHandler
from xtore.common.Buffer cimport Buffer, initBuffer, releaseBuffer
from xtore.instance.BasicStorage cimport BasicStorage
from xtore.test.DataSetLinear cimport DataSetLinear
from xtore.test.DataSet cimport DataSet

from libc.stdlib cimport malloc, free
from libc.string cimport memcpy
from libcpp.vector cimport vector
from argparse import RawTextHelpFormatter

from xtore.instance.HomomorphicStorage cimport HomomorphicStorage
from xtore.base.CythonHomomorphic cimport CythonHomomorphic, Ciphertext
from libcpp.vector cimport vector
from cpython.bytes cimport PyBytes_FromStringAndSize
import numpy as np
import sys, time, os, traceback, random, argparse

cdef str __help__ = "Test Script for Homomorphic"
cdef bint IS_VENV = sys.prefix != sys.base_prefix
def run():
    cli = HomomorphicLinearCLI()       
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

cdef class SetPosition:
    cdef list index
    cdef Ciphertext birthCipher

cdef class HomomorphicLinearCLI:
    cdef object parser
    cdef object option
    cdef object config

    def __init__(self):
        self.config = self.getConfig() 

    def getParser(self, list argv):
        self.parser = argparse.ArgumentParser(description=__help__, formatter_class=RawTextHelpFormatter)
        self.parser.add_argument("test", help="Name of test", choices=[
            'Storage',
        ])
        self.parser.add_argument("-n", "--count", help="Number of record to test.", required=False, type=int)
        self.option = self.parser.parse_args(argv)

    cdef run(self, list argv):
        self.getParser(argv)  
        self.checkPath()  
        if self.option.test == 'Storage': self.testDataSetStorage()

    cdef testDataSetStorage(self):
        cdef str path = f'{self.getResourcePath()}/test_data.bin'
        cdef StreamIOHandler io = StreamIOHandler(path)
        cdef int ringDim = 1024
        cdef int slots = 16
        cdef CythonHomomorphic homomorphic = self.setCryptoContext(ringDim, slots, path)
        cdef EncryptedData data = self.generateData(homomorphic, slots)
        cdef i64 dataAddress = self.writeEncryptedDataWithStream(path, data, homomorphic)
        cdef double start = 100.0
        cdef double end = 300.0
        cdef Buffer offsetBuffer, dataBuffer
        cdef i64 offset, position	
        cdef char *buffer_memory
        cdef i64 DATA_SIZE = 349619
        cdef bytes serializedData
        cdef Ciphertext ciphertext
        cdef int index = 0
        cdef Ciphertext startCipher = homomorphic.encrypt([start])
        cdef Ciphertext endCipher = homomorphic.encrypt([end])
        cdef list dataList = []

        print("Searching data...")
        cdef double startTime = time.time()
        for index in range(slots):
            io.open()
            try:
                io.seek(dataAddress - 16)
                buffer_memory = <char*>malloc(sizeof(i64))
                initBuffer(&offsetBuffer, buffer_memory, sizeof(i64))
                io.read(&offsetBuffer, sizeof(i64))
                offset = (<i64*> offsetBuffer.buffer)[0]

                position = dataAddress - offset
                io.seek(position)
                buffer_memory = <char*>malloc(DATA_SIZE)
                initBuffer(&dataBuffer, buffer_memory, DATA_SIZE)
                io.read(&dataBuffer, DATA_SIZE)

                serializedData = PyBytes_FromStringAndSize(dataBuffer.buffer, DATA_SIZE)
            finally:
                releaseBuffer(&dataBuffer)
                io.close()
            
            ciphertext = homomorphic.deserializeFromStream(serializedData)
            maskedCipher = homomorphic.extractSlot(slots, index, ciphertext)
            # decryptedText = homomorphic.getRealValue(slots, maskedCipher)

            resultStart = homomorphic.compare(1, maskedCipher, startCipher)
            resultEnd = homomorphic.compare(1, maskedCipher, endCipher)

            if resultStart[0] == 0 and resultEnd[0] == 1:
                # dataList.append(maskedCipher)
                continue
            else:
                continue

        cdef double elapsed = time.time() - startTime
        print(f'>>> get data in range {elapsed:.3}s')

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

    cdef CythonHomomorphic setCryptoContext(self, int ringDim, int slots, str path):
        cdef int batchSize = slots 
        cdef int multiplicativeDepth = 17
        cdef int scalingModSize = 50
        cdef int firstModSize = 60
        cdef CythonHomomorphic homomorphic = CythonHomomorphic()

        cdef str context_path = path if path else f'{self.getResourcePath()}/context.bin'

        homomorphic.initializeCKKS(multiplicativeDepth, scalingModSize, firstModSize, ringDim, batchSize, context_path)  

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
