#include "ChunkedBuffer.hpp"

using namespace Xtore;

const u32 CHUNK_SHIFT = 14;
const u32 CHUNK = 1 << CHUNK_SHIFT;
const u32 CHUNK_MODULUS = CHUNK - 1;

ChunkedBuffer::ChunkedBuffer(u32 chunkSize, bool hasOwnPair){
	this->chunkSize = chunkSize;
	this->totalLength = 0;
	this->totalCapacity = 0;
	this->buffer = NULL;
	this->number = 0;
	this->capacity = 0;
	this->listNumber = 0;
	this->listCapacity = 0;
	this->hasPair = false;
	this->streamList = NULL;
	this->checkChunkedCapacity();
	this->current = &this->streamList[0][0];
	char *buffer = (char *) malloc(chunkSize);
	initBuffer(this->current, buffer, chunkSize);
	this->current->capacity = chunkSize;
	this->current->position = 0;
	this->hasOwnPair = hasOwnPair;

	if(hasOwnPair){
		this->pair = (Buffer *) malloc(sizeof(Buffer));
		this->hasPair = true;
		this->pair->hasChunked = true;
		this->pair->chunked = (void *) this;
		this->pair->checkCapacity = (void *) checkCapacityFromChunked;
		this->pair->capacity = this->current->capacity;
		this->pair->buffer = this->current->buffer;
		this->pair->position = 0;
		this->pair->hasOwnBuffer = false;
	}
}

ChunkedBuffer::~ChunkedBuffer(){
	for(u32 i=0; i<this->listNumber;i++){
		for(u32 j=0; j<CHUNK; j++){
			auto stream = &this->streamList[i][j];
			if(stream->capacity > 0) free(stream->buffer);
		}
		free(this->streamList[i]);
	}
	free(this->streamList);
	if(this->totalCapacity > 0) free(this->buffer);
	if(this->hasOwnPair) free(this->pair);
}

void ChunkedBuffer::checkChunkedCapacity(){
	u32 number = 0;
	if(this->number >= this->capacity){
		if(this->listNumber >= this->listCapacity){
			number = this->listCapacity + CHUNK;
			auto streamList = (Buffer **) malloc(sizeof(Buffer*)*number);
			if(this->streamList != NULL){
				memcpy(streamList, this->streamList, this->listCapacity*sizeof(Buffer*));
				free(this->streamList);
			}
			this->streamList = streamList;
			this->listCapacity = number;
		}
		auto capacity = this->capacity + CHUNK;
		this->streamList[this->listNumber] = (Buffer *) malloc(sizeof(Buffer)*CHUNK);
		for(u32 i=0; i<CHUNK; i++){
			auto stream = &this->streamList[this->listNumber][i];
			initBuffer(stream, NULL, 0);
		}
		this->capacity = capacity;
		this->listNumber += 1;
	}
}

void ChunkedBuffer::getNextBuffer(u32 requiredLength){
	this->totalLength += this->current->position;
	this->checkChunkedCapacity();
	u32 capacity = this->chunkSize;
	if(requiredLength > capacity){
		for(u32 i=CHUNK_SHIFT;i<32;i++){
			capacity = 1 << i;
			if(capacity > requiredLength) break;
		}
	}
	u32 e = this->number >> CHUNK_SHIFT;
	u32 c = this->number & CHUNK_MODULUS;
	this->current = &this->streamList[e][c];
	if(capacity == 0){
		this->error = ChunkedBufferError::ZERO_BYTE_CAPACITY;
		return;
	}
	if(this->current->capacity == 0){
		initBuffer(this->current, (char *) malloc(capacity), capacity);
	}else if(this->current->capacity < capacity){
		free(this->current->buffer);
		initBuffer(this->current, (char *) malloc(capacity), capacity);
	}
	this->number += 1;
	this->current->capacity = capacity;
	this->current->position = 0;
}

u32 ChunkedBuffer::getChunkSize(){
	return CHUNK;
}

void ChunkedBuffer::setPair(Buffer *pair){
	if(this->hasOwnPair){
	}else{
		this->pair = pair;
		this->hasPair = true;
	}
}

void ChunkedBuffer::reset(){
	this->number = 1;
	this->totalLength = 0;
	this->current = &this->streamList[0][0];
	this->current->position = 0;
}

void ChunkedBuffer::resetBuffer(Buffer *stream){
	this->reset();
	stream->buffer  = this->current->buffer;
	stream->capacity = this->current->capacity;
	stream->position = 0;
}

Buffer *ChunkedBuffer::getBuffer(u32 requiredLength){
	if(this->current->position + requiredLength > this->current->capacity){
		this->getNextBuffer(requiredLength);
	}
	return this->current;
}

void ChunkedBuffer::checkBufferCapacity(Buffer *stream, u32 requiredLength){
	u32 length = stream->position + requiredLength;
	if(length > stream->capacity){
		if(stream->position > stream->capacity) this->error = OVER_CAPACITY;
		this->current->position = stream->position;
		this->getNextBuffer(requiredLength);
		stream->buffer = this->current->buffer;
		stream->capacity = this->current->capacity;
		stream->position = 0;
	}
}

char *ChunkedBuffer::finalize(){
	if(this->hasPair){
		this->totalLength += this->pair->position;
		this->current->position = this->pair->position;
	}else{
		this->totalLength += this->current->position;
	}
	if(this->number == 1) return this->current->buffer;
	if(this->totalLength > this->totalCapacity){
		if(this->totalCapacity > 0) free(this->buffer);
		this->buffer = (char *) malloc(this->totalLength);
		this->totalCapacity = this->totalLength;
	}
	u32 k = 0;
	u32 position = 0;
	for(u32 i=0; i<this->listNumber; i++){
		for(u32 j=0; j<CHUNK; j++){
			auto stream = &this->streamList[i][j];
			if(stream->position > stream->capacity){
				this->error = OVER_CAPACITY;
			}
			if(stream->position > 0){
				memcpy(this->buffer+position, stream->buffer, stream->position);
				position += stream->position;
				if(position > this->totalCapacity){
				}
			}
			k += 1;
			if(k >= this->number) break;
		}
	}
	return this->buffer;
}