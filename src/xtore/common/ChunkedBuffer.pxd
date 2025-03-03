from xtore.common.Buffer cimport Buffer
from xtore.BaseType cimport u32, u64

cdef extern from "xtorecpp/ChunkedBuffer.hpp" namespace "Xtore":
	ctypedef enum ChunkedBufferError:
		NO_ERROR
		ZERO_BYTE_CAPACITY
		OVER_CAPACITY

	cdef cppclass ChunkedBuffer:
		ChunkedBuffer(u32 chunkSize, bint hasOwnPair)

		Buffer **streamList
		Buffer *current

		bint hasPair
		bint hasOwnPair
		Buffer *pair

		u32 chunkSize
		u32 totalLength
		u32 totalCapacity
		char *buffer

		u32 number
		u32 capacity
		u32 listNumber
		u32 listCapacity
		ChunkedBufferError error

		u32 getChunkSize() except +
		void setPair(Buffer *pair)
		void reset()
		void resetBuffer(Buffer *stream)
		Buffer *getBuffer(u32 requiredLength)
		void checkBufferCapacity(Buffer *stream, u32 requiredLength) except +
		char *finalize()
		bytes finalizeBytes() except +
