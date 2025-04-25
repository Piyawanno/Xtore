from xtore.instance.RecordNode cimport RecordNode
from xtore.common.Buffer cimport Buffer, getBuffer, setBuffer, initBuffer, releaseBuffer
from xtore.BaseType cimport i16, i64, f128
from xtore.common.StreamIOHandler cimport StreamIOHandler
from xtore.base.CythonHomomorphic cimport Ciphertext
from cpython.bytes cimport PyBytes_FromStringAndSize
from libc.stdlib cimport malloc
import sys

cdef i32 DATASET_ENTRY_KEY_SIZE = 8
cdef bint IS_VENV = sys.prefix != sys.base_prefix
cdef i64 DATA_SIZE = 349619

cdef class DataSet(RecordNode):
	def __repr__(self):
		return f'<Data Address={self.address} index={self.index}>'

	cdef i64 hash(self):
		return <i64> self.address

	cdef bint isEqual(self, RecordNode other):
		cdef DataSet otherDataSet = <DataSet> other
		return self.address == otherDataSet.address and self.index == otherDataSet.index

	cdef readKey(self, i16 version, Buffer *stream):
		self.address = (<i64*> getBuffer(stream, 8))[0]

	cdef readValue(self, i16 version, Buffer *stream):
		self.index = (<i64 *> getBuffer(stream, 8))[0]

	cdef write(self, Buffer *stream):
		setBuffer(stream, <char *> &self.address, 8)
		cdef i32 start = stream.position
		stream.position += 4
		setBuffer(stream, <char *> &self.index, 8)
		cdef i32 end = stream.position
		cdef i32 valueSize = end - start
		stream.position = start
		setBuffer(stream, <char *> &valueSize, 4)
		stream.position = end

	cdef i32 compare(self, RecordNode other):
		cdef DataSet otherDataSet = <DataSet> other
		cdef str path = f'{self.getResourcePath()}/testData.bin'
		cdef StreamIOHandler io = StreamIOHandler(path)
		cdef Buffer selfBuffer, otherBuffer, selfOffsetBuffer, otherOffsetBuffer
		cdef char *buffer_memory
		cdef i64 selfPosition, otherPosition, selfOffset, otherOffset		
		cdef bytes serializedData1, serializedData2
		cdef Ciphertext ciphertext1, ciphertext2
		cdef Ciphertext maskedCipher1, maskedCipher2
		cdef int slots = self.homomorphic.getNumberOfSlots()
		
		io.open()        
		try:
			io.seek(self.address - 16)
			buffer_memory = <char*>malloc(sizeof(i64))
			initBuffer(&selfOffsetBuffer, buffer_memory, sizeof(i64))
			io.read(&selfOffsetBuffer, sizeof(i64))
			selfOffset = (<i64*> selfOffsetBuffer.buffer)[0]
			
			selfPosition = self.address - selfOffset
			io.seek(selfPosition)
			buffer_memory = <char*>malloc(DATA_SIZE)
			initBuffer(&selfBuffer, buffer_memory, DATA_SIZE)
			io.read(&selfBuffer, DATA_SIZE)

			io.seek(otherDataSet.address - 16)
			buffer_memory = <char*>malloc(sizeof(i64))
			initBuffer(&otherOffsetBuffer, buffer_memory, sizeof(i64))
			io.read(&otherOffsetBuffer, sizeof(i64))
			otherOffset = (<i64*> otherOffsetBuffer.buffer)[0]

			otherPosition = otherDataSet.address - otherOffset
			io.seek(otherPosition)
			buffer_memory = <char*>malloc(DATA_SIZE)
			initBuffer(&otherBuffer, buffer_memory, DATA_SIZE)
			io.read(&otherBuffer, DATA_SIZE)

			serializedData1 = PyBytes_FromStringAndSize(selfBuffer.buffer, DATA_SIZE)
			serializedData2 = PyBytes_FromStringAndSize(otherBuffer.buffer, DATA_SIZE)
		finally:
			releaseBuffer(&selfBuffer)
			releaseBuffer(&otherBuffer)
			releaseBuffer(&selfOffsetBuffer)
			releaseBuffer(&otherOffsetBuffer)
			io.close()

		ciphertext1 = self.homomorphic.deserializeFromStream(serializedData1)
		ciphertext2 = self.homomorphic.deserializeFromStream(serializedData2)
		
		maskedCipher1 = self.homomorphic.extractSlot(slots, self.index, ciphertext1)
		maskedCipher2 = self.homomorphic.extractSlot(slots, otherDataSet.index, ciphertext2)

		decryptedText1 = self.homomorphic.getRealValue(slots, maskedCipher1)
		decryptedText2 = self.homomorphic.getRealValue(slots, maskedCipher2)

		result = self.homomorphic.compare(1, maskedCipher1, maskedCipher2)

		if result[0] > 0:
			return 1
		else:
			return 0

	cdef i32 compareIntToRecord(self, RecordNode dataSet, int num):
		cdef DataSet referenceNode = <DataSet> dataSet
		cdef str path = f'{self.getResourcePath()}/testData.bin'
		cdef StreamIOHandler io = StreamIOHandler(path)
		cdef Buffer referenceBuffer, referenceOffsetBuffer, selfOffsetBuffer, selfBuffer
		cdef char *buffer_memory
		cdef i64 referencePosition,  referenceOffset		
		cdef bytes serializedData1, serializedData
		cdef Ciphertext ciphertext1, ciphertext2
		cdef Ciphertext maskedCipher1, maskedCipher2
		cdef int slots = referenceNode.homomorphic.getNumberOfSlots()

		io.open()
		try:
			io.seek(self.address - 16)
			buffer_memory = <char*>malloc(sizeof(i64))
			initBuffer(&selfOffsetBuffer, buffer_memory, sizeof(i64))
			io.read(&selfOffsetBuffer, sizeof(i64))
			selfOffset = (<i64*> selfOffsetBuffer.buffer)[0]
			
			selfPosition = self.address - selfOffset
			io.seek(selfPosition)
			buffer_memory = <char*>malloc(DATA_SIZE)
			initBuffer(&selfBuffer, buffer_memory, DATA_SIZE)
			io.read(&selfBuffer, DATA_SIZE)

			serializedData = PyBytes_FromStringAndSize(selfBuffer.buffer, DATA_SIZE)

		finally:
			releaseBuffer(&selfBuffer)
			releaseBuffer(&selfOffsetBuffer)
			io.close()

		ciphertext1 = referenceNode.homomorphic.encrypt([num])
		ciphertext2 = referenceNode.homomorphic.deserializeFromStream(serializedData)
		maskedCipher2 = referenceNode.homomorphic.extractSlot(slots, self.index, ciphertext2)

		result = referenceNode.homomorphic.compare(1, ciphertext1, maskedCipher2)

		# decryptedText1 = referenceNode.homomorphic.getRealValue(slots, ciphertext1)
		# decryptedText2 = referenceNode.homomorphic.getRealValue(slots, maskedCipher2)
		# print(f'"decryptedText1": {int(decryptedText1[0])}', f'"decryptedText2": {int(decryptedText2[0])}', f'"result": {result[0]}')

		releaseBuffer(&selfBuffer)
		releaseBuffer(&selfOffsetBuffer)

		if result[0] > 0:
			return 1
		else:
			return 0

	cdef f128 getRangeValue(self):
		return <f128> self.address

	cdef str getResourcePath(self):
		if IS_VENV: return f'{sys.prefix}/var/xtore'
		else: return '/var/xtore'