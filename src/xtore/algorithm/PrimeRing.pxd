from xtore.common.Buffer cimport Buffer
from xtore.BaseType cimport u16, i32, i64
from xtore.algorithm.PrimeNode cimport PrimeNode
from xtore.algorithm.StorageUnit cimport StorageUnit

cdef class PrimeRing:
	cdef list primeRingConfig
	cdef list primeNumbers
	cdef i32 replicaNumber
	cdef list[StorageUnit] storageUnits
	cdef i32 layerNumber
	cdef dict hashTable

	cdef loadData(self, list config)
	cdef StorageUnit getStorageUnit(self, i64 hashKey)


