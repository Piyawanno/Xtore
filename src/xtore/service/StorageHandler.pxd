from xtore.BaseType cimport i32, i64
from xtore.common.Buffer cimport Buffer
from xtore.instance.BasicStorage cimport BasicStorage
from xtore.instance.RecordNode cimport RecordNode
from xtore.test.People cimport People
from xtore.instance.BinarySearchTreeStorage cimport BinarySearchTreeStorage

cdef class StorageHandler:
	cdef dict config
	cdef Buffer buffer
	cdef i32 isFulled
	cdef i64 maxCapacity
	cdef i64 currentUsage

	cdef assignID(self, People record)
	cdef BasicStorage openHashStorage(self, str fileName)
	cdef BasicStorage openBSTStorage(self, str fileName)
	cdef writeData(self, BasicStorage storage, list[RecordNode] dataList)
	cdef i32 writeToStorage(self, list[RecordNode] dataList, BasicStorage storage)
	cdef readHashStorage(self, str storageName)
	cdef list[RecordNode] readAllBSTStorage(self, BinarySearchTreeStorage storage)
	cdef list[RecordNode] readData(self, BasicStorage storage, list[RecordNode] queries)
	cdef readAllData(self, BasicStorage storage)
	cdef checkPath(self)
	cdef str getResourcePath(self)
	cdef i64 getFileSize(self, str path)