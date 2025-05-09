from xtore.BaseType cimport i32, i64
from xtore.algorithm.StorageUnit cimport StorageUnit
from xtore.algorithm.PrimeNode cimport PrimeNode

cdef class PrimeRing:
	cdef dict primeRingConfig
	cdef list primeNumbers
	cdef i32 replicaNumber
	cdef dict storageUnits
	cdef i32 layerNumber

	cdef loadData(self, dict config)
	cdef list[StorageUnit] getStorageUnit(self, i64 hashKey)
	cdef list[PrimeNode] getAllNodes(self)


