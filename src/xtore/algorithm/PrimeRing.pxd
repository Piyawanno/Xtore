from xtore.BaseType cimport i32, i64
from xtore.algorithm.StorageUnit cimport StorageUnit

cdef class PrimeRing:
	cdef dict primeRingConfig
	cdef list primeNumbers
	cdef i32 replicaNumber
	cdef dict storageUnits
	cdef i32 layerNumber
	cdef dict hashTable

	cdef loadData(self, dict config)
	cdef StorageUnit getStorageUnit(self, i64 hashKey)


