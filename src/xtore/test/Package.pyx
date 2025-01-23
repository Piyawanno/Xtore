from xtore.instance.RecordNode cimport RecordNode
from xtore.common.Buffer cimport Buffer, getBuffer, setBuffer, getString, setString
from xtore.BaseType cimport i16, i64, u64, f128

cdef i32 PEOPLE_ENTRY_KEY_SIZE = 8

cdef class Package (RecordNode):
	def __repr__(self):
		return f'Method={self.method} <Package ID={self.ID} value={self.data}>'

	cdef i64 hash(self):
		return <i64> self.ID

	cdef bint isEqual(self, RecordNode other):
		cdef Package otherPackage = <Package> other
		return self.ID == otherPackage.ID

	cdef readKey(self, i16 version, Buffer *stream):
		self.ID = (<i64*> getBuffer(stream, 8))[0]

	cdef readValue(self, i16 version, Buffer *stream):
		self.method = getString(stream)
		self.data = getString(stream)

	cdef write(self, Buffer *stream):
		setBuffer(stream, <char *> &self.ID, 8)
		cdef i32 start = stream.position
		stream.position += 4
		setString(stream, self.method)
		setString(stream, self.data)
		cdef i32 end = stream.position
		cdef i32 valueSize = end - start
		stream.position = start
		setBuffer(stream, <char *> &valueSize, 4)
		stream.position = end
	
	cdef i32 compare(self, RecordNode other):
		cdef Package otherPackage = <Package> other
		if self.ID == otherPackage.ID: return 0
		elif self.ID > otherPackage.ID: return 1
		else: return -1
	
	cdef f128 getRangeValue(self):
		return <f128> self.ID
