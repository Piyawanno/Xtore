#pragma once

#include "DataType.hpp"
#include "Python.h"

#include <stdlib.h>
#include <string.h>

namespace Xtore{
	enum{
		BUFFER_BLOCK = 16384,
		BUFFER_MODULUS = 16383,
		BUFFER_SHIFT = 14
	};

	typedef struct Buffer{
		u64 position;
		u64 capacity;
		bool hasOwnBuffer;

		char *buffer;

		int hasChunked;
		void *chunked;
		void *checkCapacity;
	} Buffer;

	typedef void (* CapacityChecker) (Buffer *stream, u64 length);

	inline void initBuffer(Buffer *stream, char *buffer, u64 capacity){
		stream->buffer = buffer;
		stream->capacity = capacity;
		stream->hasOwnBuffer = false;
		stream->position = 0;
		stream->hasChunked = false;
		stream->chunked = NULL;
		stream->checkCapacity = NULL;
	}

	inline void releaseBuffer(Buffer *stream) {
		if(stream->capacity > 0 && stream->buffer != NULL) {
			free(stream->buffer);
			stream->capacity = 0;
			stream->buffer = NULL;
		}
	}

	inline void checkCapacity(Buffer *stream, u64 length){
		u64 capacity = stream->position + length;
		if(capacity > stream->capacity){
			if(!stream->hasChunked){
				if((capacity & BUFFER_MODULUS) != 0){
					capacity = ((capacity >> BUFFER_SHIFT) + 1) << BUFFER_SHIFT;
				}
				auto buffer = (char*) malloc(capacity);
				if(stream->capacity > 0){
					memcpy(buffer, stream->buffer, stream->capacity);
					free(stream->buffer);
				}
				stream->capacity = capacity;
				stream->buffer = buffer;
			}else{
				auto check = (CapacityChecker) stream->checkCapacity;
				check(stream, length);
			}
		}
	}

	inline void resizeBuffer(Buffer *stream, char *buffer, u64 capacity) {
		if(capacity > stream->capacity) {
			memcpy(buffer, stream->buffer, stream->position);
			releaseBuffer(stream);
			stream->buffer = buffer;
			stream->capacity = capacity;
		}
	}

	inline void checkBufferSize(Buffer *stream, u64 chunkSize) {
		if(stream->position >= stream->capacity) {
			int capacity = stream->capacity + chunkSize;
			char *buffer = (char *) malloc(capacity);
			resizeBuffer(stream, buffer, capacity);
		}
	}

	inline void setBuffer(Buffer *stream, char *buffer, u64 length){
		if(!stream->hasOwnBuffer) checkCapacity(stream, length);
		memcpy(stream->buffer+stream->position, buffer, length);
		stream->position += length;
	}
	
	inline char *getBuffer(Buffer *stream, u64 length){
		char *buffer = stream->buffer + stream->position;
		stream->position += length;
		return buffer;
	}
}