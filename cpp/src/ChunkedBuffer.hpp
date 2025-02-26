#pragma once

#include "DataType.hpp"
#include "Buffer.hpp"
#include "Python.h"

#include <stdlib.h>
#include <string.h>

namespace Xtore{
	enum ChunkedBufferError{
		NO_ERROR = 0,
		ZERO_BYTE_CAPACITY = 10,
		OVER_CAPACITY = 11,
	};
	
	class ChunkedBuffer{
		public:
			ChunkedBuffer(u32 chunkSize, bool hasOwnPair=false);
			~ChunkedBuffer();

			void checkChunkedCapacity();
			void getNextBuffer(u32 requiredLength);
			u32 getChunkSize();
			void setPair(Buffer *pair);
			void reset();
			void resetBuffer(Buffer *stream);
			Buffer *getBuffer(u32 requiredLength);
			void checkBufferCapacity(Buffer *stream, u32 requiredLength);
			char *finalize();
		
		public:
			Buffer **streamList;
			Buffer *current;

			bool hasPair;
			bool hasOwnPair;
			Buffer *pair;

			u32 chunkSize;
			u32 totalLength;
			u32 totalCapacity;
			char *buffer;

			u32 number;
			u32 capacity;
			u32 listNumber;
			u32 listCapacity;
			ChunkedBufferError error;

	};

	inline void checkCapacityFromChunked(Buffer *stream, u64 length){
		auto chunked = (ChunkedBuffer*) stream->chunked;
		chunked->checkBufferCapacity(stream, length);
	}

	inline ChunkedBuffer *enableChunked(Buffer *stream, u32 chunkedSize){
		auto chunked = new ChunkedBuffer(chunkedSize);
		chunked->setPair(stream);
		stream->hasChunked = true;
		stream->chunked = (void *) chunked;
		stream->checkCapacity = (void *) checkCapacityFromChunked;
		stream->capacity = chunked->current->capacity;
		stream->buffer = chunked->current->buffer;
		stream->position = 0;
		stream->hasOwnBuffer = false;
		return chunked;
	}
}