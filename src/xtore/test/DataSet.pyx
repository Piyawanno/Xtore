from xtore.instance.RecordNode cimport RecordNode
from xtore.common.Buffer cimport Buffer, getBuffer, setBuffer, initBuffer, releaseBuffer
from xtore.BaseType cimport i16, i64, f128
from xtore.common.StreamIOHandler cimport StreamIOHandler
from xtore.base.CythonHomomorphic cimport CythonHomomorphic, Ciphertext
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

	cdef i32 compare(self, RecordNode other):
		cdef DataSet otherDataSet = <DataSet> other
		cdef CythonHomomorphic homomorphic = CythonHomomorphic() 
		cdef str path = f'{self.getResourcePath()}/test_data.bin'
		cdef StreamIOHandler io = StreamIOHandler(path)
		
		cdef Buffer selfBuffer, otherBuffer, selfOffsetBuffer, otherOffsetBuffer
		cdef char *buffer_memory
		cdef i64 dataSize = 349619
		cdef i64 selfPosition, otherPosition, selfOffset, otherOffset
		cdef i64 selfAddress = self.address
		cdef i64 otherAddress = otherDataSet.address
		cdef i32 selfIndex = self.index
		cdef i32 otherIndex = otherDataSet.index
		
		cdef bytes serializedData1, serializedData2
		cdef Ciphertext ciphertext1, ciphertext2
		cdef Ciphertext maskedCipher1, maskedCipher2
		
		print(f'"selfAddress": {selfAddress}', f'"selfIndex": {selfIndex}')
		print(f'"otherAddress": {otherAddress}, "otherIndex": {otherIndex}')

		try:
			io.open()        
			try:
				io.seek(selfAddress - 16)
				buffer_memory = <char*>malloc(sizeof(i64))
				initBuffer(&selfOffsetBuffer, buffer_memory, sizeof(i64))
				io.read(&selfOffsetBuffer, sizeof(i64))
				selfOffset = (<i64*> selfOffsetBuffer.buffer)[0]
				
				selfPosition = selfAddress - selfOffset
				io.seek(selfPosition)
				buffer_memory = <char*>malloc(dataSize)
				initBuffer(&selfBuffer, buffer_memory, dataSize)
				io.read(&selfBuffer, dataSize)

				io.seek(otherAddress - 16)
				buffer_memory = <char*>malloc(sizeof(i64))
				initBuffer(&otherOffsetBuffer, buffer_memory, sizeof(i64))
				io.read(&otherOffsetBuffer, sizeof(i64))
				otherOffset = (<i64*> otherOffsetBuffer.buffer)[0]

				otherPosition = otherAddress - otherOffset
				io.seek(otherPosition)
				buffer_memory = <char*>malloc(dataSize)
				initBuffer(&otherBuffer, buffer_memory, dataSize)
				io.read(&otherBuffer, dataSize)
			finally:
				io.close()
			
			serializedData1 = PyBytes_FromStringAndSize(selfBuffer.buffer, dataSize)
			serializedData2 = PyBytes_FromStringAndSize(otherBuffer.buffer, dataSize)

			ciphertext1 = homomorphic.deserializeFromStream(serializedData1)
			ciphertext2 = homomorphic.deserializeFromStream(serializedData2)
			
			maskedCipher1 = self.homomorphic.extractSlot(8, selfIndex, ciphertext1)
			maskedCipher2 = self.homomorphic.extractSlot(8, otherIndex, ciphertext2)

			result = self.homomorphic.compare(1, maskedCipher1, maskedCipher2)

			if result[0] > 0:
				return 1
			else:
				return 0
		finally:
			if selfBuffer.buffer != NULL:
				releaseBuffer(&selfBuffer)
			if otherBuffer.buffer != NULL:
				releaseBuffer(&otherBuffer)
			if selfOffsetBuffer.buffer != NULL:
				releaseBuffer(&selfOffsetBuffer)
			if otherOffsetBuffer.buffer != NULL:
				releaseBuffer(&otherOffsetBuffer)
				
			io.close()

	cdef f128 getRangeValue(self):
		return <f128> self.address

	cdef str getResourcePath(self):
		if IS_VENV: return f'{sys.prefix}/var/xtore'
		else: return '/var/xtore'