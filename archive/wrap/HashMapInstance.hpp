#pragma once

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#include "common/DataType.hpp"
#include "common/Comparator.hpp"
#include "common/Util.hpp"
#include "common/Hash.hpp"
#include "common/HashMap.hpp"

#include "store/IO.hpp"
#include "store/IOBuffer.hpp"
#include "store/Storage.hpp"
#include "store/StorageItem.hpp"
#include "store/LineTracer.hpp"
#include "store/HeaderCache.hpp"

#include "instance/Record.hpp"
#include "instance/RecordHandler.hpp"
#include "instance/ValueRecordHandler.hpp"
#include "instance/RecordType.hpp"
#include "instance/Instance.hpp"
#include "instance/MapInstance.hpp"
#include "instance/Iterator.hpp"
#include "instance/Transaction.hpp"

#include "instance/hash/HashTransaction.hpp"
#include "instance/hash/HashIterator.hpp"
#include "instance/hash/HashGroupedIterator.hpp"
#include "instance/hash/HashBinaryEntry.hpp"
#include "instance/hash/HashMapInstanceOperation.hpp"

#include "common/T22ID.hpp"

namespace Xpeed{
	struct HashInstanceHeader;

	/// NOTE : Return true, for additional space is required.
	typedef bool (*HashRecordUpdater) (HashMapInstance * self, Record *current, Record *update);
	typedef void (*HashMapInstanceCommitCaller) (HashMapInstance *self, HashTransaction *transaction);
	
	class HashMapInstance : public MapInstance{
		friend struct HashInstanceHeader;
		friend class HashTransaction;
		friend class HashIterator;
		friend class HashGroupedIterator;

		public :
			HashMapInstance(const char *name, u32 nameLength, Storage *storage);
			~HashMapInstance();

			void set(Transaction *transaction);
			bool get(Transaction *transaction);
			bool remove(Transaction *transaction);
			u32 getStartRecord(Record *record);

			void open();
			void close();
			u32 getSize();
			void commitSet(Transaction *transaction);
			void commitRemove(Transaction *transaction);
			
			void setDataType(DataType keyType, DataType valueType);
			void setValueDataType(DataType valueType);
			Transaction *createTransaction();
			Iterator *createIterator();
			Iterator *createGroupedIterator();
			Iterator *getGrouped(Transaction *transaction);
			void setValueStorage(Storage *valueStorage);
			bool getValueStorageStatus();

			void show();
			void enableDebug();

			Record *readRecordKey(Record *record, u64 position);
			void writeRecordData(IOBuffer *buffer, Record *record);

			void setKeyCapacity(u32 capacity);
			void setValueCapacity(u32 capacity);
			u32 getKeyCapacity();
			u32 getValueCapacity();

			void setKeySize(u32 size);
			void setValueSize(u32 size);
			u32 getKeySize();
			u32 getValueSize();
			f64 getLastWrite();

			void enableMVCC();
			void disableMVCC();

			HashBinaryEntry *readEntry(HashBinaryEntry *entry, u64 position, bool isCopy);
			HashBinaryEntry *readEntryKey(HashBinaryEntry *entry, u64 position);
			void writeEntry(IOBuffer *buffer, HashBinaryEntry *entry);

			void commitAppendBucket(HashTransaction *transaction);
			void commitAppendLeafBucket(HashTransaction *transaction);
			void commitAppendLeft(HashTransaction *transaction);
			void commitAppendRight(HashTransaction *transaction);
			void commitAppendValue(HashTransaction *transaction);
			void commitReplace(HashTransaction *transaction);

			void enableReadOnly();
			void disableReadOnly();
			void checkPageCache();
			void setTracer(LineTracer *tracer);

			StorageItem *getPositionStorage();

			u32 getHeaderSize();
			void getHeaderBuffer(char *buffer);
			void setHeaderFromBuffer(char *buffer);
		
		public :
			Comparator compare;
			Comparator isEqual;
			Comparator isLess;
			Comparator isLessEqual;
			Comparator isGreater;
			Comparator isGreaterEqual;
		
		protected :
			void processPostWrite();

		private :
			void serializeHeader(IOBuffer *buffer);
			void unserializeHeader(IOBuffer *buffer);
			bool checkBucketStorage(u32 layer, u64 bucketNumber);
			void initBucketStorage();
			void writeBucket(u64 position, u64 hashed, u64 recordPosition);
			void writeHeader();
			void writeHeaderCache();
			void readHeader();
			void readHeaderCache();
			void checkHeaderCache();
			void findNextStart();

			Record *search(HashTransaction *transaction, bool *isFound, bool isEmptySkip);
			Record *searchBucket(HashTransaction *transaction, bool *isFound, bool isEmptySkip);
			Record *searchBinary(HashTransaction *transaction, bool *isFound, bool isEmptySkip);

			void getStorageTail();
			void checkStorageTail();

		private :
			bool isDebug;
			bool isOpened;
			StorageItem *bucketStorageItem;

			HeaderCache *headerCache;
			
			HashFunction hash;
			IOBuffer headerBuffer;

			bool isDynamicRecord;

			u32 bucketLayer;
			u64 bucketSize;
			u64 headerCachePosition;
			u64 lastRecordTail;

			u32 startCount;
			u64 startPosition;
			u64 hashed;

			HashMapInstanceCommitCaller committer[HASH_OPERATION_NUMBER];
			bool isTracer;
			LineTracer *tracer;
			u16 reference;
			u32 parity;

			u64 storageTail;
			u64 valueStorageTail;
			u64 bucketStorageTail;
			u64 positionStoageTail;
	};
}