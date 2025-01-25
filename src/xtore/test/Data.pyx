from xtore.instance.RecordNode cimport RecordNode
from xtore.common.Buffer cimport Buffer, getBuffer, setBuffer, getString, setString
from xtore.BaseType cimport i16, i32, i64, u64, f128

cdef i32 DATA_ENTRY_KEY_SIZE = 8
cdef class Data (RecordNode):
	def __repr__(self):
		return f'<ID={self.ID} fields={self.fields}>'

	def __cinit__(self):
		self.fields = {}

	cdef i64 hash(self):
		return <i64> self.ID

	cdef bint isEqual(self, RecordNode other):
		cdef Data otherData = <Data> other
		return self.ID == otherData.ID

	cdef readKey(self, i16 version, Buffer *stream):
		self.ID = (<i64*> getBuffer(stream, 8))[0]

	cdef readValue(self, i16 version, Buffer *stream):
		cdef int i
		cdef str fieldName
		cdef object value
		for i in range(len(self.fields)):
			fieldName = getString(stream)
			if stream.position + 8 <= stream.capacity:
				value = (<i64 *> getBuffer(stream, 8))[0]
			else:
				value = getString(stream)
			self.fields[fieldName] = value

	cdef write(self, Buffer *stream):
		setBuffer(stream, <char *> &self.ID, 8)
		cdef i32 start = stream.position
		stream.position += 4
		cdef i64 temp
		for fieldName, value in self.fields.items():
			print(f"Key: {fieldName}, Type: {type(fieldName)}")
			print(f"Value: {value}, Type: {type(value)}")
			setString(stream, fieldName)
			if isinstance(value, int):
				temp = value
				setBuffer(stream, <char *> &temp, 8)
				print('write integer success')
			elif isinstance(value, str):
				setString(stream, value)
				print('write string success')
		cdef i32 end = stream.position
		cdef i32 valueSize = end - start
		stream.position = start
		setBuffer(stream, <char *> &valueSize, 4)
		stream.position = end

	cdef i32 compare(self, RecordNode other):
		cdef Data otherData = <Data> other
		if self.ID == otherData.ID: return 0
		elif self.ID > otherData.ID: return 1
		else: return -1

	cdef f128 getRangeValue(self):
		return <f128> self.ID
