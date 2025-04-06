from xtore.instance.RecordNode cimport RecordNode
from xtore.common.Buffer cimport Buffer, getBuffer, setBuffer, getString, setString, initBuffer, releaseBuffer
from xtore.BaseType cimport i16, i64, f128
from xtore.common.StreamIOHandler cimport StreamIOHandler
from xtore.base.CythonHomomorphic cimport CythonHomomorphic
from cpython.bytes cimport PyBytes_FromStringAndSize
from libc.stdlib cimport malloc, free
import sys

cdef i32 DATASET_ENTRY_KEY_SIZE = 8
cdef bint IS_VENV = sys.prefix != sys.base_prefix

cdef class DataSet(RecordNode):
	
	def __repr__(self):
		return f'<Data Address={self.address} index={self.index}>'

	cdef i64 hash(self):
		return <i64> self.address

	cdef bint isEqual(self, RecordNode other):
		cdef DataSet otherDataSet = <DataSet> other
		return self.address == otherDataSet.address

	cdef readKey(self, i16 version, Buffer *stream):
		self.address = (<i64*> getBuffer(stream, 8))[0]

	cdef readValue(self, i16 version, Buffer *stream):
		self.index = (<i64 *> getBuffer(stream, 4))[0]

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
	
	# cdef i32 compare(self, RecordNode other):
	# 	cdef DataSet otherDataSet = <DataSet> other
	# 	if self.address == otherDataSet.address: return 0
	# 	elif self.address > otherDataSet.address: return 1
	# 	else: return -1

	cdef i32 compare(self, RecordNode other):
		cdef DataSet otherDataSet = <DataSet> other
		cdef str path = f'{self.getResourcePath()}/test_data.bin'
		cdef StreamIOHandler io = StreamIOHandler(path)
		cdef Buffer selfBuffer, otherBuffer, selfPositionBuffer, otherPositionBuffer
		cdef char *buffer_memory
		cdef int ringDim = 1024
		cdef int slots = 2
		cdef int multiplicativeDepth = 17
		cdef int scalingModSize = 50
		cdef int firstModSize = 60
		cdef CythonHomomorphic homomorphic = CythonHomomorphic()
		homomorphic.initializeCKKS(multiplicativeDepth, scalingModSize, firstModSize, ringDim, slots)  
		homomorphic.setupSchemeSwitching(slots, 25)
		cdef i32 selfPosition, otherPosition
		cdef i64 selfAddress = self.address
		cdef i64 otherAddress = otherDataSet.address
		cdef i32 selfIndex = self.index
		cdef i32 otherIndex = otherDataSet.index
		print(f'"otherAddress": {otherAddress}')
		print(f'"otherIndex": {otherIndex}')
		print(f'"selfAddress": {selfAddress}')
		print(f'"selfIndex": {selfIndex}')

		io.open()
		try:
			io.seek(selfAddress - 16)
			buffer_memory = <char*>malloc(sizeof(i64))
			initBuffer(&selfPositionBuffer, buffer_memory, sizeof(i64))
			io.read(&selfPositionBuffer, sizeof(i64))
			selfPosition = (<i64*> selfPositionBuffer.buffer)[0]
			print(f'selfPosition: {selfPosition}')
			
			io.seek(selfPosition)
			dataSize = 349619

			buffer_memory = <char*>malloc(dataSize)
			initBuffer(&selfBuffer, buffer_memory, dataSize)
			io.read(&selfBuffer, dataSize)

			io.seek(otherAddress - 16)
			buffer_memory = <char*>malloc(dataSize)
			initBuffer(&otherPositionBuffer, buffer_memory, sizeof(i64))
			io.read(&otherPositionBuffer, sizeof(i64))
			otherPosition = (<i64*> otherPositionBuffer.buffer)[0]
			print(f'otherPosition: {otherPosition}')
			
			io.seek(otherPosition)
			buffer_memory = <char*>malloc(dataSize)
			initBuffer(&otherBuffer, buffer_memory, dataSize)
			io.read(&otherBuffer, dataSize)
		finally:
			io.close()

		serializedData1 = PyBytes_FromStringAndSize(selfBuffer.buffer, dataSize)
		ciphertext1 = homomorphic.deserializeFromStream(serializedData1)

		serializedData2 = PyBytes_FromStringAndSize(otherBuffer.buffer, dataSize)
		ciphertext2 = homomorphic.deserializeFromStream(serializedData2)

		maskedCipher1 = homomorphic.extractSlot(slots, selfIndex, ciphertext1)
		maskedCipher2 = homomorphic.extractSlot(slots, otherIndex, ciphertext2)

		result = homomorphic.compare(1, maskedCipher1, maskedCipher2)

		if result[0] > 0:
			return 0
		else:
			return 1

	cdef f128 getRangeValue(self):
		return <f128> self.index

	cdef str getResourcePath(self):
		if IS_VENV: return f'{sys.prefix}/var/xtore'
		else: return '/var/xtore'