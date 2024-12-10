from xtore.BaseType cimport DataType
from xtore.BaseType cimport i8, i16, i32, i64, u8, u16, u32, u64, f32, f64, f128

ctypedef i8 (*Comparator) (void *reference, void *comparing)

cdef inline i8 compareI8(void *reference, void *comparing):
	cdef r = (<i8*> reference)[0]
	cdef c = (<i8*> comparing)[0]
	if r == c: return 0
	elif r > c: return 1
	else: return -1

cdef inline i8 compareI16(void *reference, void *comparing):
	cdef r = (<i16*> reference)[0]
	cdef c = (<i16*> comparing)[0]
	if r == c: return 0
	elif r > c: return 1
	else: return -1

cdef inline i8 compareI32(void *reference, void *comparing):
	cdef r = (<i32*> reference)[0]
	cdef c = (<i32*> comparing)[0]
	if r == c: return 0
	elif r > c: return 1
	else: return -1

cdef inline i8 compareI64(void *reference, void *comparing):
	cdef r = (<i64*> reference)[0]
	cdef c = (<i64*> comparing)[0]
	if r == c: return 0
	elif r > c: return 1
	else: return -1

cdef inline i8 compareU8(void *reference, void *comparing):
	cdef r = (<u8*> reference)[0]
	cdef c = (<u8*> comparing)[0]
	if r == c: return 0
	elif r > c: return 1
	else: return -1

cdef inline i8 compareU16(void *reference, void *comparing):
	cdef r = (<u16*> reference)[0]
	cdef c = (<u16*> comparing)[0]
	if r == c: return 0
	elif r > c: return 1
	else: return -1

cdef inline i8 compareU32(void *reference, void *comparing):
	cdef r = (<u32*> reference)[0]
	cdef c = (<u32*> comparing)[0]
	if r == c: return 0
	elif r > c: return 1
	else: return -1

cdef inline i8 compareU64(void *reference, void *comparing):
	cdef r = (<u64*> reference)[0]
	cdef c = (<u64*> comparing)[0]
	if r == c: return 0
	elif r > c: return 1
	else: return -1

cdef inline i8 compareF32(void *reference, void *comparing):
	cdef r = (<f32*> reference)[0]
	cdef c = (<f32*> comparing)[0]
	if r == c: return 0
	elif r > c: return 1
	else: return -1

cdef inline i8 compareF64(void *reference, void *comparing):
	cdef r = (<f64*> reference)[0]
	cdef c = (<f64*> comparing)[0]
	if r == c: return 0
	elif r > c: return 1
	else: return -1

cdef inline i8 compareF128(void *reference, void *comparing):
	cdef r = (<f128*> reference)[0]
	cdef c = (<f128*> comparing)[0]
	if r == c: return 0
	elif r > c: return 1
	else: return -1

cdef inline Comparator getComparator(DataType type):
	if   type == DataType.I8 :  return compareI8
	elif type == DataType.I16:  return compareI16
	elif type == DataType.I32:  return compareI32
	elif type == DataType.I64:  return compareI64
	elif type == DataType.U8 :  return compareU8
	elif type == DataType.U16:  return compareU16
	elif type == DataType.U32:  return compareU32
	elif type == DataType.U64:  return compareU64
	elif type == DataType.F32:  return compareF32
	elif type == DataType.F64:  return compareF64
	elif type == DataType.F128: return compareF128
