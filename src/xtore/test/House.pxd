from xtore.instance.RecordNode cimport RecordNode
from xtore.common.Buffer cimport Buffer
from xtore.BaseType cimport i16, i32, i64, u64, f128

cdef i32 PET_ENTRY_KEY_SIZE
cdef class House (RecordNode):
	cdef u64 IDhouse 
	cdef str nameOwner
	cdef str surnameOwner
	cdef str countryOfhouse
	cdef i64 price
	cdef str telephoneHouse
