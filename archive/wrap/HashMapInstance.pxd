from xpeed.base.common.DataType cimport DataType, u32, u64, f64
from xpeed.base.store.Storage cimport Storage
from xpeed.base.store.StorageItem cimport StorageItem
from xpeed.base.store.IOBuffer cimport IOBuffer
from xpeed.base.store.LineTracer cimport LineTracer
from xpeed.base.instance.Record cimport Record
from xpeed.base.instance.Instance cimport Instance
from xpeed.base.instance.MapInstance cimport MapInstance
from xpeed.base.instance.Transaction cimport Transaction
from xpeed.base.instance.Iterator cimport Iterator
from xpeed.base.instance.hash.HashBinaryEntry cimport HashBinaryEntry

from libcpp cimport bool

cdef extern from "xpeed/instance/hash/HashMapInstance.hpp" namespace "Xpeed" :
	cdef cppclass HashMapInstance (MapInstance) :
		HashMapInstance(const char *name, u32 nameLength, Storage *storage)

		u32 getStartRecord(Record *record) except +

		Record *readRecordKey(Record *record, u64 position) except +

		f64 getLastWrite() except +

		HashBinaryEntry *readEntry(HashBinaryEntry *entry, u64 position, bool isCopy) except +
		HashBinaryEntry *readEntryKey(HashBinaryEntry *entry, u64 position) except +
		void writeEntry(IOBuffer *buffer, HashBinaryEntry *entry) except +
		void setTracer(LineTracer *tracer)
		StorageItem *getPositionStorage()